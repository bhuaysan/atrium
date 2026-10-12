# Atrium on Linux: Plan

12 October 2026 · based on commit 614ed53 (main). Status: decisions D1–D7 made (12 October 2026, see *Decisions* at the end); Phase 0 started: `Package.swift` with `AtriumCore` exists (see *Phase 0 progress*).

Atrium is a macOS app through and through: SwiftUI and SwiftData for the library, AppKit in a third of the views, Metal for presentation, an Objective-C libretro host, CGL and MoltenVK for hardware rendering, AVAudioEngine, GameController/IOKit for input. This plan describes how Atrium can also run on Linux without forking it into two products, what stands in the way, and in which order to do it.

## Summary

- **Feasible, but not a port in the narrow sense.** About a third of the Swift code (≈10 k of 32 k lines) builds on Linux almost unchanged. The UI (≈13.5 k lines SwiftUI/AppKit) has to be written again for GTK, and the Objective-C bridge (≈3.9 k lines) has to become C, because Swift on Linux cannot call Objective-C.
- **Recommended architecture:** one repository, a shared Swift package `AtriumCore` (library, metadata, cores, BIOS, saves, backups, input models, shader preset parsing), a shared C libretro host `LibretroHost` with a small platform layer, and two front ends: the existing SwiftUI app on macOS and a new GTK 4 / libadwaita app on Linux.
- **The cores are not the problem:** every core in `SystemCatalog` that the macOS buildbot has is also built for Linux x86_64 and aarch64 (checked 12 October 2026). OpenGL and Vulkan are native on Linux; some macOS workarounds (GLideN64 black frames, MoltenVK) disappear.
- **Biggest risks:** UI effort and keeping two UIs in step, the GPU frame handoff on discrete GPUs, Flatpak sandbox vs. ROM folders and downloaded cores, and ScreenScraper developer credentials in builds that Flathub makes from public sources.
- **Rough effort:** 23–33 weeks for one developer to feature parity minus polish (see *Phases*). Phase 0 happens entirely on macOS and improves the Mac app's structure on its own.

## Inventory

| Area | macOS today | Lines | Portable? |
|---|---|---|---|
| UI | SwiftUI, AppKit (`NSViewRepresentable`, `NSTextView`, `NSEvent`, panels) | ≈13.5 k | No, rewrite |
| Library model | SwiftData (`Game`, `LibrarySchema`, `@Query`), 32 files import it | — | No, new store |
| Library logic | `LibraryScanner`, `LibraryMatcher`, `ROMPatch`, `DiscPlaylist`, `GameVariants`, `FolderStructure` | | Mostly yes |
| Metadata | `ScreenScraperClient`, `MetadataService` (URLSession, SwiftData) | | Client yes, service after store split |
| Cores, BIOS, emulators | `CoreManager`, `BIOSManager`, `EmulatorManager` (CryptoKit, Security, xattr) | | Yes, with small replacements |
| Support | `ZipArchive` (Compression), `Backup` (JSON + plist), `Preferences` (UserDefaults), `Keychain` | | Mostly yes |
| Emulation logic | `EmulationSession` (1.6 k lines), `SaveStates`, `BatterySave`, `InputRouter`, shader model types | | Partly; session needs AppKit split |
| Rendering | `MetalRenderer`, `ShaderSource` (MSL at runtime), `GameMetalView` (MTKView) | ≈1 k | No, new GL presenter |
| Bridge | `URLibretroCore.m`, `UREmulationRunner.m`, `URGLContext.m` (CGL), `URVulkanContext.m` (MoltenVK, `CAMetalLayer`), `URAchievements.m` (NSURLSession), `URShaderChain.m` (librashader Metal) | ≈3.9 k ObjC | No as ObjC; logic yes as C |
| Plain C | `URAudioRing.c`, `URPixelConversion.c`, `URRewindBuffer.c` (Apple LZ4) | ≈500 | Yes (LZ4 replaced) |
| Third party | rcheevos (C), librashader (has GL and Vulkan runtimes), MoltenVK | | rcheevos and librashader yes; MoltenVK not needed |
| Build | XcodeGen, `xcodebuild`, asset catalog, DMG, notarization | | No, SwiftPM + Flatpak |
| Tests | 42 Swift Testing files, `atrium-test-core`, `atrium-smoke` | | Swift Testing runs on Linux; UI-bound tests stay on macOS |

Counted with `import` lines: files that import none of SwiftUI, AppKit, SwiftData, Metal(Kit), IOKit, GameController, CoreHaptics, ImageIO, CoreGraphics, CoreText, UniformTypeIdentifiers, Security, OSLog, CryptoKit, Compression, PDFKit, QuickLookUI, Carbon, CoreServices or QuartzCore add up to ≈10.1 k lines; the rest ≈22 k.

## Target

| Topic | Proposal |
|---|---|
| Distributions | Current GNOME and KDE desktops (Fedora, Ubuntu 24.04+, Arch, SteamOS desktop mode); Wayland first, X11 through Xwayland/GTK |
| Architectures | x86_64 first (most Linux players, Steam Deck); aarch64 second (Asahi Linux on the same Macs, ARM boards) |
| Toolkit | GTK 4 + libadwaita (see H2) |
| Distribution | Flatpak first, AppImage optional (see H14) |
| Feature scope | Everything Atrium does on macOS, in this order: play, library, metadata, saves, achievements, shaders, shader editor, PS2 |
| Data | Own data folder on Linux; Mac backups can be restored on Linux (see H21) |

## Architecture

### Options

| Option | Pro | Contra |
|---|---|---|
| **A. Shared core, native UI per platform** (recommended) | Mac app stays SwiftUI and keeps its design; Linux gets a native GNOME look; logic, catalog and tests shared | Two UIs to maintain |
| B. One cross-platform UI for both (Qt, SwiftCrossUI, Flutter, web view) | One UI | Mac app loses its native feel and the design work of the last weeks; heavy dependency; contradicts the project's direction |
| C. Separate Linux app (other language, own logic) | Freedom on Linux | Duplicates `SystemCatalog`, scanner, scraper, saves, backup logic; drifts apart immediately |

### Layout (option A)

```
Package.swift            SwiftPM: AtriumCore, LibretroHost, CRcheevos, AtriumLinux, atrium-smoke, tests
AtriumCore/              Swift, Foundation only: Systems, Library logic, Metadata, Cores, BIOS,
                         Saves, Backup, Zip, Preferences, input and shader models, PCSX2Config, PINEClient
                         + protocols for what differs: SecretStore, FolderWatcher, ImageCodec, Hashing, Log, Paths
LibretroHost/            C11: core loading, environment, runner, audio ring, pixel conversion, rewind,
                         run-ahead, rcheevos glue; platform/ (darwin, linux) for time, locks, logging,
                         GL context, Vulkan surface, audio output
Atrium/                  macOS app: SwiftUI views, Metal renderer, AppKit/IOKit adapters (uses the package)
AtriumLinux/             Linux app: GTK views, GL presenter, SDL3 input/audio, libsecret, inotify adapters
ThirdParty/              rcheevos (as today), librashader (per-platform fetch), moltenvk (macOS only)
```

The macOS app keeps using XcodeGen and consumes the local package (`packages:` in `project.yml`). The package keeps MainActor default isolation (`.defaultIsolation(MainActor.self)`) so the moved code doesn't change meaning.

### Component mapping

| macOS | Linux |
|---|---|
| SwiftUI, AppKit | GTK 4 + libadwaita; `AdwNavigationSplitView`/`AdwOverlaySplitView` for sidebar and inspector, `GtkGridView`/`GtkColumnView` for grid and table, `AdwPreferencesDialog` for Settings |
| SwiftData | SQLite (system `libsqlite3`) behind a `LibraryRepository`; schema versions via `PRAGMA user_version` |
| Metal, MSL compiled at runtime | OpenGL 3.3 core in a `GtkGLArea`, the built-in filters ported to GLSL (also compiled at runtime) |
| librashader Metal runtime (`libra_mtl_*`) | librashader OpenGL runtime (`libra_gl_*`); Vulkan runtime later if the presenter moves to Vulkan |
| CGL offscreen context | EGL without a window (surfaceless or device platform); desktop GL and, new, GLES 2/3 |
| MoltenVK, `CAMetalLayer` surface | System Vulkan loader (`libvulkan.so.1`), Mesa or NVIDIA driver; headless surface for Dolphin |
| AVAudioEngine | SDL3 audio (PipeWire/PulseAudio/ALSA backends, resampling built in) |
| `mach_absolute_time`, `mach_wait_until` | `clock_gettime(CLOCK_MONOTONIC)`, `clock_nanosleep(TIMER_ABSTIME)` |
| `os_unfair_lock`, `os_log` | `pthread_mutex`/C11 atomics, `Mutex` (Synchronization); stderr/journald |
| GameController, `IOHIDManager`, IOUSBHost XInput, Core Haptics | SDL3 gamepad API (kernel `xpad` driver covers Xbox 360 pads, SDL's controller database covers D-input pads, rumble and player LEDs included) |
| NSURLSession in `URAchievements.m` | rcheevos' `server_call` handed to Swift `URLSession` (FoundationNetworking) |
| Compression (zlib, LZ4) | zlib; liblz4 for the rewind buffer |
| CryptoKit (MD5, SHA-256) | rcheevos' MD5 plus a small SHA-256 in C, on both platforms (decided) |
| Keychain (Security) | libsecret (Secret Service; the Secret portal inside Flatpak) |
| FSEvents, `NSWorkspace` mount notifications | inotify per folder (`GFileMonitor`), `GVolumeMonitor` |
| ImageIO, CoreGraphics, CoreText | `GdkTexture`/gdk-pixbuf in the UI, libpng for headless code, Pango/Cairo for `StillFrame` text |
| UniformTypeIdentifiers | `GtkFileFilter` (MIME types, patterns), extension tables in `AtriumCore` |
| `NSTextView` (TextKit 2) in the shader editor | GtkSourceView 5 (ships GLSL highlighting) |
| PDFKit / Quick Look for manuals | Open with the default app (OpenURI portal); embedded Poppler view later |
| `NSWorkspace` open / reveal | `GtkFileLauncher`, `org.freedesktop.FileManager1.ShowItems` |
| `~/Library/Application Support/Atrium`, Caches | `$XDG_DATA_HOME/atrium`, `$XDG_CACHE_HOME/atrium` (Flatpak maps them to `~/.var/app/…`) |
| Menu bar (`AppCommands`) | Primary menu in the header bar, `GtkShortcutController`; Ctrl instead of ⌘ |
| xcstrings | Converted at build time (see H11) |
| XcodeGen, DMG, notarization | SwiftPM, Flatpak manifest, AppStream metainfo, `.desktop`, hicolor icons |
| ARMSX2 `.app` | PCSX2 AppImage (x86_64), extracted on install (see H15) |

## Hurdles and solutions

Severity: **high** blocks the port or costs weeks; **medium** needs a design decision or a spike; **low** is known work.

### H1 — Swift on Linux cannot call Objective-C (high)

Swift on Linux has no Objective-C interop: `URLibretroCore`, `UREmulationRunner`, `URGLContext`, `URVulkanContext`, `URAchievements` and `URShaderChain` are unusable there, and GNUstep doesn't change that.

**Solution:** turn the bridge into C11 with opaque handles (`ur_core_t *`, `ur_runner_t *`) and a platform layer (`ur_platform_now()`, `ur_platform_sleep_until()`, locks, logging, GL context, Vulkan surface, audio output) with a Darwin and a Linux implementation. Swift wraps the handles in small classes. `NSData`/`NSString` in the API become buffers and UTF-8 strings; `NSError` becomes an error code plus message. Rewriting the bridge in Swift instead would be possible but awkward: libretro callbacks are context-free C functions that need global state, which Swift 6's strict concurrency makes cumbersome, and the hot paths are already C.

This happens **on macOS first** (Phase 0): `EmulationRunnerTests` with `atrium-test-core`, `PixelConversionTests`, `AudioRingTests` and `make smoke` (OpenGL and Vulkan) guard the conversion, and the Mac app then runs on the same host code as Linux. Duplicating the bridge per platform is ruled out: `URCoreEnvironment` is the most subtle code in the project.

### H2 — No SwiftUI on Linux (high, the largest work item)

The UI has to be written again. Candidates for GTK from Swift:

| Candidate | Assessment |
|---|---|
| Adwaita for Swift (declarative GTK/libadwaita wrapper) | Closest to SwiftUI, so views translate structurally; MIT; moved from GitHub (archived) to Codeberg (`aparoksha/adwaita-swift`, active in October 2026, few contributors), so a risk as a core building block |
| Own thin wrapper over the C API (system library targets for `gtk4`, `libadwaita-1`) | No Swift dependency, full control, fits the dependency policy; verbose (signals through `Unmanaged` contexts, reference counting), wrapper code to write |
| SwiftCrossUI | Cross-platform abstraction; less native GNOME look, fewer widgets (grid with thousands of covers, column view) |
| Qt through Swift C++ interop | Experimental interop, large dependency; KDE look on GNOME |

**Solution (D2):** a two-week spike with the hardest screens (cover grid with 5 000 games and lazy artwork, sidebar + inspector, a settings page) in the first two candidates, then decide. Criteria: scrolling performance of the grid, effort per screen, how much of the wrapper we would have to fix or own. Independent of the choice:

- **Observation bridge.** Services are `@Observable`; GTK knows nothing about that. A small helper re-runs `withObservationTracking` and updates widgets on the main loop (Observation itself ships with the Linux toolchain).
- **Design.** The Mac design (gradient system banner, hardware identity inspector) is translated into libadwaita idioms, not copied pixel for pixel; the accent colour maps to libadwaita's accent CSS variables. Design choices need the same OK as on macOS.
- **Parity.** A checklist per feature (see H19) keeps the two UIs in step.

### H3 — MainActor and the GLib main loop (medium)

With MainActor default isolation, almost everything runs on the main actor, whose executor on Linux is libdispatch's main queue. GTK runs its own GLib main loop and never drains that queue, so `Task { @MainActor … }` and `DispatchQueue.main.async` would never run.

**Solution:** a GLib source that watches the main queue's wake-up handle (`_dispatch_get_main_queue_handle_4CF`) and drains it (`_dispatch_main_queue_callback_4CF`), installed before `g_application_run`. GTK callbacks arrive on the main thread and enter Swift via `MainActor.assumeIsolated`. If the toolchain offers custom main executors by then, use that instead. To verify in the first Linux spike.

### H4 — SwiftData is not available (high)

`Game` is a SwiftData model, views use `@Query`, `LibraryStore` (742 lines) merges scan results into the context, `LibrarySchema` has versioned migrations.

**Solution:** split `LibraryStore` into platform-neutral merge logic working on a `LibraryRepository` protocol and value types (`GameRecord` exists already for backups) and a store per platform: SwiftData on macOS (unchanged for users), SQLite on Linux (system library, a thin wrapper of our own, schema version in `PRAGMA user_version`). Moving the Mac app to SQLite too would remove the duplication but means migrating every user's library; not now (D4). Queries the UI needs (filters, collections, sort orders in `LibraryFilter`) become repository calls with SQL behind them on Linux.

### H5 — Presentation without Metal, and the cost of the frame handoff (high)

The Metal presenter (filters, integer scaling, rotation, ambient light with mipmaps, bezels, librashader chains, GPU timing) needs a Linux counterpart. Today every hardware-rendered frame is read back into the CPU frame buffer. On Apple Silicon that is cheap (unified memory); on a PC with a discrete GPU, a synchronous `glReadPixels` of an upscaled frame (e.g. Dolphin at 3×, ≈2.9 k × 2.2 k) crosses PCIe and stalls the pipeline every frame.

**Solution:**
1. **Presenter:** OpenGL 3.3 core in a `GtkGLArea` (GTK creates the context, works on Wayland and X11, no toolkit-level Vulkan widget needed). The built-in filters (`ShaderSource.swift`, ≈200 lines MSL) are ported to GLSL; `PresentationLayout` and the pass structure stay as they are. librashader's GL runtime replaces the Metal one. GPU time via `GL_TIME_ELAPSED` queries.
2. **Handoff, first version:** readback as today, but asynchronous through two pixel buffer objects (read frame N while N−1 is mapped), so the stall goes away at the cost of one frame of latency for hardware cores. Rewind, screenshots, thumbnails and `atrium-smoke` keep working unchanged.
3. **Handoff, later (zero-copy):** the core's GL context shares objects with the presenter's (GDK contexts share with the display's context; or `EGL_MESA_image_dma_buf_export` → import), Vulkan images are exported as dma-buf (`VK_EXT_external_memory_dma_buf`, `VK_EXT_image_drm_format_modifier`) and imported into GL (`EGL_EXT_image_dma_buf_import`). The CPU frame is then only read on demand (screenshot, state thumbnail).

### H6 — OpenGL contexts for cores (medium)

CGL is gone; libretro cores may ask for a compatibility profile, a core profile of any version, or GLES 2/3.

**Solution:** EGL without a window: `EGL_PLATFORM_SURFACELESS_MESA` on Mesa, `EGL_EXT_platform_device` on NVIDIA, a GBM device as fallback; `eglBindAPI(EGL_OPENGL_API | EGL_OPENGL_ES_API)` by the requested context type; `get_proc_address` through `eglGetProcAddress`; the FBO logic of `URGLContext` stays. Consequences for the catalog: Mesa runs GLideN64 correctly, and GL 4.6 is available, so `CoreDefinition.renderer` and option defaults need a per-platform value (e.g. `optionDefaults(for: renderer, platform:)`) instead of the macOS assumptions written into them today.

### H7 — Vulkan without MoltenVK (medium)

Native Vulkan simplifies a lot (no portability enumeration, no `libvulkan.1.dylib` symlink), but `URVulkanContext` assumes MoltenVK: `VK_EXT_metal_surface`, a hidden `CAMetalLayer` for Dolphin, MoltenVK-specific workarounds.

**Solution:** link against the system loader with `dlopen("libvulkan.so.1")` (fails cleanly when no driver is installed → OpenGL fallback with a toast, as today). For cores that need a surface (Dolphin), use `VK_EXT_headless_surface` (Mesa supports it); if a driver lacks it, a hidden 1×1 Wayland/X11 surface. Keep MoltenVK-only code behind the Darwin platform layer. Test with Mesa (RADV, ANV, honeykrisp on Asahi), NVIDIA and lavapipe (CI).

### H8 — Audio and frame pacing (low)

Audio is the master clock; the runner sleeps until the next deadline and nudges the frame time by ±0.5 %. Only the APIs differ.

**Solution:** SDL3 audio stream with a pull callback that reads `URAudioRing` (SDL resamples the core's rate, e.g. 32 040 Hz, to the device rate like AVAudioEngine does). Timing via `clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME)`. A higher thread priority needs rtkit (or the Realtime portal in Flatpak); without it, a nice value is enough in practice. Verify PipeWire's default quantum against the ring's ~64 ms target.

### H9 — Input (medium)

GameController, `HIDGamepadManager` (IOHIDManager), `XInputGamepadManager` (IOUSBHost) and Core Haptics have no Linux counterparts, and saved keyboard bindings use **macOS virtual key codes** (`KeyBinding.keyCode`, `KeyboardMapping`, the `EmulatedKeyboard` table, `HotKey` constants).

**Solution:**
- **Pads:** SDL3 gamepad API (events, rumble, player LEDs, controller database). The kernel's `xpad` driver handles Xbox 360 pads, so `XInputGamepad` isn't needed. `HIDGamepadMapping`'s manual mappings become SDL mapping strings (a later UI; SDL's database covers most pads). `InputRouter`'s profile, port assignment, dead zone and turbo logic stays.
- **Keyboard:** introduce platform-neutral key identifiers (USB HID usage codes or W3C `KeyboardEvent.code` names) in `AtriumCore` and migrate stored bindings on macOS in Phase 0. GTK delivers hardware key codes (evdev + 8), mapped to the same identifiers. Default hotkeys use Ctrl where macOS uses ⌘.
- **Permissions:** pads under `/dev/input` are usually reachable through logind's `uaccess`; DualSense/Switch pads via hidraw need udev rules (the `steam-devices` package). Flatpak needs `--device=all`. Document this in the README.
- **Focus:** ignore pad input while the player window isn't focused (SDL reads devices regardless of focus).

### H10 — Foundation on Linux behaves differently (medium)

Linux uses swift-foundation/swift-corelibs-foundation. Known differences that affect Atrium: `URLSession` lives in `FoundationNetworking` (libcurl) and needs `#if canImport(FoundationNetworking)`; `HTTPDownload` uses `download(from:delegate:)` with a progress delegate, whose async variant may be missing; no `NSImage`/`CGImage`; no `@objc`/KVO; `Bundle.main` and resources are laid out differently; `UserDefaults` persists to a file whose location and atomicity must be checked; `String(localized:)` lookup depends on how resources are bundled.

**Solution:** a one-week spike that builds `AtriumCore` on Linux and runs its tests; whatever fails gets a small adapter in `AtriumCore` (e.g. a delegate-based download with a continuation, a JSON-backed preferences store if `UserDefaults` disappoints). CI keeps it building on both platforms from then on.

### H11 — Localization (low)

`Localizable.xcstrings` is compiled by Xcode only.

**Solution:** a build script converts the catalog (JSON) into `de.lproj/Localizable.strings` (or gettext `.po` if GTK builder files need it) for the Linux bundle; plural variants map to `.stringsdict`. The xcstrings file stays the single source; the rule "add German" stays as it is.

### H12 — Folder watching (low)

FSEvents watches recursively; inotify watches one directory per watch and is limited by `fs.inotify.max_user_watches`.

**Solution:** a `FolderWatcher` protocol; on Linux one inotify watch per directory below the library folders (they are not deep), new directories added as they appear. If the limit is hit, fall back to the existing `RescanScheduler` with periodic rescans and say so in the Scan Report. Mounts via `GVolumeMonitor`.

### H13 — Secrets: keychain and ScreenScraper credentials (medium)

The user's ScreenScraper password and the RetroAchievements token live in the keychain. ScreenScraper's **developer** credentials are compiled in from `.env` (`Secrets.generated.swift`).

**Solution:**
- **User secrets:** libsecret (GNOME Keyring, KWallet; inside Flatpak through the Secret portal). Without a Secret Service: don't store, ask again (no plaintext file).
- **Developer credentials:** Flathub builds from a public manifest on Flathub's infrastructure, so a secret can't be injected there. Options: (a) build the Flatpak in our own CI with the secrets and publish it as a bundle/own repository (scraping works, but not on Flathub); (b) a Flathub build without developer credentials, where scraping is off or users enter their own; (c) a small proxy that holds the credentials (operating cost, rate limits shared by all users). Decided (D5): option (a), our own Flatpak; Flathub later, once scraping has an answer there. The hard rule stands: media URLs with credentials are never logged or stored.

### H14 — Packaging and the Flatpak sandbox (high)

- **Swift runtime:** link with `--static-swift-stdlib` against glibc. The fully static Linux SDK (musl) is **not** an option: Atrium `dlopen`s glibc cores, which a static musl binary can't load.
- **Flatpak SDK:** Flathub has `org.freedesktop.Sdk.Extension.swift6` (Swift 6.4.0 as of October 2026), so the manifest builds from source with it.
- **ROM folders:** the sandbox sees only what it is given. Folders picked through the FileChooser portal arrive as document-portal paths (`/run/user/…/doc/…`), which are stable but not the paths users know, and FSEvents-like watching through them is limited. Pragmatic solution: `--filesystem=home` plus `xdg-run/…` for removable media (common for emulator front ends on Flathub), with portals for anything outside.
- **Downloaded cores:** writing to and executing from `~/.var/app/…/data` is allowed in Flatpak; check Flathub's current policy on apps that download executable code (RetroArch's Flatpak is the precedent).
- **Devices and GPU:** `--device=all` (pads, hidraw), GL/Vulkan drivers come from the runtime's GL extension (including NVIDIA).
- **AppImage** as a second format: simpler for the developer credentials (own CI build), but no sandbox and no automatic updates; the existing `UpdateChecker` would point to it.

### H15 — PlayStation 2 via PCSX2 instead of ARMSX2 (medium)

ARMSX2 has no x86_64 Linux build; PCSX2 itself publishes Linux AppImages and Flatpaks (v2.8.2 at the time of writing) and speaks the same PINE protocol and `PCSX2.ini`.

**Solution and the differences to handle:**
- **Install:** pin a PCSX2 AppImage in `SystemCatalog` (per platform), verify the SHA-256 (there is no Developer ID check on Linux; the exact pin is the trust anchor), then extract it once (`--appimage-extract`): AppImages need FUSE 2, which many distributions and Flatpak sandboxes lack.
- **Data folder:** upstream PCSX2 accepts `-datapath` like ARMSX2 (also `-portable`, `-batch`, `-nogui`; `pcsx2-qt/QtHost.cpp`, checked 12 October 2026), so `ARMSX2Launch`'s arguments carry over.
- **PINE socket:** on Linux PCSX2 puts it into `$XDG_RUNTIME_DIR`. Overriding `XDG_RUNTIME_DIR` per launch (the macOS approach with `TMPDIR`) would cut the child off from Wayland and PipeWire, so use a unique PINE slot per launch instead.
- **Config keys:** `PCSX2Config`/`ARMSX2Controls` write keys that may differ between ARMSX2 and upstream PCSX2 (renderer names, Metal); make them per emulator.
- **Window switching:** `NSRunningApplication.activate()` has no Wayland equivalent; pass an `XDG_ACTIVATION_TOKEN` at launch and hide "Switch to PCSX2" where focusing isn't possible.
- **ExternalSession** (one SIGTERM, SIGKILL after 10 s) works unchanged; PCSX2 on Linux has no known dialog crash, but the pre-flight checks stay.
- **aarch64:** no PCSX2 builds; PS2 stays unavailable on ARM Linux unless ARMSX2 publishes Linux builds (to verify).

### H16 — x86_64 (low)

The project builds for arm64 only. `URPerfGetCPUFeatures` reports NEON unconditionally; other arm64 assumptions may hide in C code and tests.

**Solution:** report CPU features by architecture (`__builtin_cpu_supports` for SSE/AVX on x86_64), build and test on x86_64 in CI. Core downloads come from `buildbot.libretro.com/nightly/linux/<arch>/latest/<core>_libretro.so.zip`; `CoreManager.buildbot`, the file extension and the quarantine step become per platform.

### H17 — Wayland specifics (medium)

- No window activation of other apps (see H15), no window positioning: Atrium relies on neither for its own windows.
- Fractional scaling: integer scaling and `PresentationLayout` must use device pixels (`gdk_surface_get_scale`), not logical ones.
- Display refresh: `GtkGLArea` draws on GDK's frame clock (like `MTKView` at display refresh); 60 Hz content on 120/144 Hz displays repeats frames as on ProMotion.
- Screensaver: inhibit idle while playing (`gtk_application_inhibit`, Inhibit portal).
- Pointer input (`RETRO_DEVICE_POINTER`) is absolute, so no pointer lock is needed.

### H18 — Development and test environment (medium)

The project is developed on a Mac; Linux GPU paths need real hardware.

**Solution:**
- **Headless builds and tests:** Docker/`container` with the official Swift image (arm64 on the Mac, x86_64 in CI).
- **CI:** an `ubuntu-24.04` job: `swift build`, `swift test` (including `EmulationRunnerTests` with the test core), `atrium-smoke` with Mesa llvmpipe (GL) and lavapipe (Vulkan), which need no GPU.
- **GPU testing:** Asahi Linux on the same Mac (aarch64, honeykrisp/asahi drivers) and one x86_64 PC with an AMD or NVIDIA GPU; Steam Deck for the handheld case.
- **Debugging without UI:** port the `ATRIUM_*` environment variables (snapshots via `GtkSnapshot`/`GskRenderer`, autoplay, select game/system); UI checks through AT-SPI and a headless compositor (e.g. `mutter --headless` or `weston --backend=headless`).

### H19 — Maintaining two UIs (high, ongoing)

Each UI feature costs twice from then on.

**Solution:** logic goes into `AtriumCore` first (view models, formatters, validation, sorting, filter state), views stay thin; a parity table in `docs/` lists every feature per platform; PRs that change behaviour touch both or record the gap. Accept that Linux may trail by a release.

### H20 — Dependencies and licences (medium)

The project adds no third-party dependency without discussion. The port needs, as system libraries (not vendored): GTK 4, libadwaita, GtkSourceView 5, SDL3, SQLite, libsecret, liblz4, zlib, libepoxy (or own GL loading), the Vulkan loader; a Linux build of librashader (fetched like on macOS, or the distribution's package); possibly a Swift GTK wrapper (H2). All are GPL-3.0-compatible (LGPL, zlib, BSD, MIT, public domain). Approved in D3 for the Linux build: GTK 4, libadwaita, GtkSourceView 5, SDL3, SQLite, libsecret, liblz4 (recorded in `CLAUDE.md`). Still to approve when they come up: the Swift GTK wrapper (D2), libepoxy. Hashing needs no dependency: rcheevos' MD5 plus an own SHA-256.

### H21 — Moving between Mac and Linux (medium)

Backups (`manifest.json`, `library.json` with `GameRecord`s, `settings.plist`, saves, states, media) are already platform-neutral files, but contain absolute macOS paths (`/Users/…/ROMs/…`), macOS key codes and macOS-only preferences (`AppleAccentColor`).

**Solution:** restore on Linux with path remapping (old library root → new root); `LibraryMatcher` already recognises moved files by checksum or size and date, so games keep their UUID and their saves. Key codes are solved by H9's migration. Battery saves (`.srm`) are portable; save states only between the same core version, and not for every core across architectures (dynarec state); the restore warns about that.

## Phases

| Phase | Content | Acceptance | Estimate |
|---|---|---|---|
| **0 — Prepare (macOS only)** | Create `Package.swift` with `AtriumCore`; move platform-neutral code; protocols for secrets, watching, images, hashing, logging, paths. Bridge to C (`LibretroHost`) with Darwin platform layer; achievements HTTP to Swift. Platform-neutral key identifiers with migration. `LibraryStore` split (H4). | `make test` green, `make smoke` (OpenGL, Vulkan) unchanged, no user-visible change | 4–6 weeks |
| **1 — Linux headless** | `AtriumCore` and `LibretroHost` build on Linux; Linux platform layer (time, locks, EGL, native Vulkan, SDL3 audio); `atrium-smoke` on Linux; Foundation spike (H10); main-loop spike (H3); CI job | Tests green on x86_64 in CI; `smoke.png` from a software core, a GL core and a Vulkan core on lavapipe | 1–2 weeks |
| **2 — Player prototype** | GTK app with one window: `GtkGLArea` presenter with the built-in filters, SDL3 pads, keyboard, fullscreen; start by command line (`atrium --play <rom>`) | SNES/GBA, PSX (HW), N64 (paraLLEl-RDP), GameCube (Dolphin) at full speed on a reference PC and on Asahi | 3–4 weeks |
| **3 — Library** | SQLite store, scanner, watcher, grid/table, sidebar, inspector, scraping, cores and BIOS settings, folder structure, backup restore from macOS | A Mac backup restores on Linux with artwork, play time and saves | 6–8 weeks |
| **4 — Player features** | Pause menu, save states browser, rewind, run-ahead, achievements, cheats, disc change, librashader presets, bezels, ambient light, zero-copy handoff (H5.3) | The play feature tests of macOS pass on Linux; no readback on the hot path for GL cores | 4–6 weeks |
| **5 — Rest** | Shader editor (GtkSourceView), PS2 via PCSX2, extras and manuals, HID mapping UI | Feature parity table complete or gaps documented | 3–4 weeks |
| **6 — Release** | Flatpak manifest, AppStream metainfo, desktop file, icons, CI artefacts, Steam Deck check, README/docs (`SUPPORTED_SYSTEMS.md` per platform), release notes | Installs and runs on Fedora, Ubuntu 24.04 and SteamOS from the Flatpak | 2–3 weeks |

Estimates are for one developer and assume the spikes don't reveal a blocker; Phase 3 depends most on the UI binding choice (D2).

### Phase 0 progress

**Step 1 — package (12 October 2026).** `Package.swift` at the root with the library `AtriumCore` (`AtriumCore/`) and its tests (`AtriumCoreTests/`). The app links it through `packages:` in `project.yml`; the Atrium scheme runs the package's tests with the app's, and `swift test` runs them alone. Swift settings match the app target (main actor default isolation, approachable concurrency, member import visibility).

- Moved, unchanged apart from `public`: `GameSystem`, `SystemCatalog`, `AppPaths`, `LegacyName`, `Keychain`, `Preferences`, `Backup` (with `GameRecord`), `FileMerge`, `DebugEnvironment`, `HTTPDownload`, `ZipArchive`, `FolderStructure`, `ROMPatch`, `CoreManager`, `PS2BIOS`, `PINEClient`, `ShaderImport`, `ShaderSelection`, `SlangPresetFile`, `SlangTokenizer`. `HardwareRenderer.graphicsAPI` stays in the app (`GraphicsAPI` is a bridge type).
- Strings: the package has its own catalog (`AtriumCore/Resources/Localizable.xcstrings`) and looks them up with `bundle: .module`; their entries moved out of the app's catalog (two the app also uses stay in both).
- Tests: `CoreManagerTests` and `ZipRobustnessTests` moved; the shared helpers are `AtriumCoreTests/Fixtures.swift`, which `AtriumTests` compiles too. Mixed test files stay in `AtriumTests` with `@testable import AtriumCore` and move with the code they test.
- Still Apple-only inside the package, for Phase 1 (H10): `Compression` in `ZipArchive`, `Security` in `Keychain`/`LegacyName`, `zlib` imported as the SDK's module.

**What holds back the rest** (found by compiling candidate sets on their own):

| Needs | Files waiting | Unblocked by |
|---|---|---|
| Bridge types (`ShaderPreset`, `ShaderParameter`, `RetroInput`, `PadState`, `GraphicsAPI`, `AchievementClient`) | `ShaderIndex`, `ShaderPresetWriter`, `SlangPreset`, `SlangSource`, `ShaderDrafts`, `ShaderLibrary`, `ShaderWorkspace`, `InputMapping`, `InputProfile`, `HIDGamepadMapping`, `AchievementService` | `LibretroHost` in C (H1) |
| `Game`/`PlayStatus` (SwiftData) | `DiscPlaylist`, `LibraryCollections`, `LibraryFilter`, then `LibraryScanner` (also `LibraryPaths`), `LibraryMatcher`, `GameVariants` (`TitleFormatter`) | `LibraryStore` split (H4) |
| macOS key codes (`ARMSX2Controls`) | `PCSX2Config`, `ARMSX2Launch`; through `PCSX2Config.memoryCardFileName` also `BatterySave`, `ARMSX2States`, `SaveStates` (which also maps `GraphicsAPI`) | Key identifiers (H9); or move the constant and the `GraphicsAPI` mapping first |
| Generated `GeneratedSecrets`, `Keychain` protocol | `Secrets`, `ScreenScraperClient` | Secret store protocol |

## Decisions

Made on 12 October 2026.

| # | Question | Decision |
|---|---|---|
| D1 | Go/no-go and first target | Go. Phase 0 starts now; Linux x86_64 desktop first, Steam Deck and aarch64/Asahi second |
| D2 | GTK binding from Swift | Two-week spike (H2) comparing Adwaita for Swift with an own thin wrapper, then decide |
| D3 | Dependencies (H20) | Approved as Linux-only system libraries: GTK 4, libadwaita, GtkSourceView 5, SDL3, SQLite, libsecret, liblz4 |
| D4 | Mac on the shared C host and SQLite? | The Mac app moves to the shared C host in Phase 0; it keeps SwiftData, Linux gets SQLite |
| D5 | Distribution vs. ScreenScraper credentials (H13) | Own Flatpak built in our CI with the secrets, published as a bundle/own repository; Flathub later |
| D6 | PS2 on Linux | Official PCSX2 AppImage on x86_64, pinned by SHA-256 in `SystemCatalog` and extracted on install; no PS2 on aarch64 for now |
| D7 | Repository | One repository, restructured: `Package.swift` at the root, `AtriumCore/`, `LibretroHost/`, `Atrium/` (macOS), `AtriumLinux/` |
| — | Hashing without CryptoKit | Own C: rcheevos' MD5 plus a small SHA-256, used on both platforms |

## Out of scope

- Windows (the C host and `AtriumCore` would help there later, but WinUI/Win32 is a third UI).
- A controller-driven "big picture" mode for Steam Deck's Game Mode (worth its own plan after the release).
- Zero-copy presentation on macOS (`VK_EXT_metal_objects`, see `docs/VULKAN_PLAN.md`), which Phase 0 doesn't change.
