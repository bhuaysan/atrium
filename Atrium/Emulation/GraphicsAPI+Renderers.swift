// SPDX-License-Identifier: GPL-3.0-or-later

import AtriumCore

// `GraphicsAPI` is the libretro host's type, so AtriumCore can't map to it.

nonisolated extension HardwareRenderer {
    /// The libretro host's name for the renderer.
    var graphicsAPI: GraphicsAPI {
        switch self {
        case .opengl: .openGL
        case .vulkan: .vulkan
        }
    }
}

nonisolated extension StateRenderer {
    init(_ api: GraphicsAPI) {
        self = switch api {
        case .openGL: .opengl
        case .vulkan: .vulkan
        default: .software
        }
    }
}
