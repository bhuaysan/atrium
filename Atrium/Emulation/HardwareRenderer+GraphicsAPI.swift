// SPDX-License-Identifier: GPL-3.0-or-later

import AtriumCore

nonisolated extension HardwareRenderer {
    /// The libretro host's name for the renderer.
    var graphicsAPI: GraphicsAPI {
        switch self {
        case .opengl: .openGL
        case .vulkan: .vulkan
        }
    }
}
