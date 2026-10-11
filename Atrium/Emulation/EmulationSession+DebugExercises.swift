// SPDX-License-Identifier: GPL-3.0-or-later

#if DEBUG
import AppKit

/// Development aids: with ATRIUM_DEBUG_PLAY or ATRIUM_DEBUG_STATES set
/// (see `DebugEnvironment`), a started game exercises the player's features
/// by itself and the app quits afterwards.
extension EmulationSession {
    /// For a game that started in a libretro core.
    func runDebugExercises() {
        if DebugEnvironment.exercisesPlay {
            // Screenshot, rewind and fast forward, then quit.
            Task {
                try? await Task.sleep(for: .seconds(5)); takeScreenshot()
                try? await Task.sleep(for: .seconds(1)); setRewinding(true)
                try? await Task.sleep(for: .seconds(2)); setRewinding(false)
                try? await Task.sleep(for: .seconds(1)); setFastForward(true)
                try? await Task.sleep(for: .seconds(2)); setFastForward(false)
                try? await Task.sleep(for: .seconds(2)); NSApp.terminate(nil)
            }
        }
        if DebugEnvironment.exercisesStates {
            // Save, load and termination.
            Task {
                try? await Task.sleep(for: .seconds(4)); saveState(slot: 1)
                try? await Task.sleep(for: .seconds(2)); loadState(slot: 1)
                try? await Task.sleep(for: .seconds(2)); NSApp.terminate(nil)
            }
        }
    }

    /// For a game that started in a standalone emulator.
    func runStandaloneDebugExercises() {
        if DebugEnvironment.exercisesPlay {
            // Quit the emulator like the Quit button, then Atrium.
            Task {
                try? await Task.sleep(for: .seconds(20)); await stop(context: nil)
                try? await Task.sleep(for: .seconds(2)); NSApp.terminate(nil)
            }
        }
        if DebugEnvironment.exercisesStates {
            // Once the game shows, save and load through PINE, then quit.
            Task {
                while externalControl == .connecting || (externalControl == .ready && !hasExternalGameStarted) {
                    try? await Task.sleep(for: .milliseconds(500))
                }
                try? await Task.sleep(for: .seconds(4)); saveState(slot: 1)
                try? await Task.sleep(for: .seconds(4)); loadState(slot: 1)
                try? await Task.sleep(for: .seconds(4)); await stop(context: nil)
                try? await Task.sleep(for: .seconds(2)); NSApp.terminate(nil)
            }
        }
    }
}
#endif
