import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

@main
struct PosyGalleryApp: App {
    init() {
        #if canImport(AppKit)
        // Launched through `swift run`, the process has no bundle and would
        // otherwise stay a background app without a Dock icon or key window.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        #endif
    }

    var body: some Scene {
        WindowGroup("Posy Gallery") {
            TabView {
                GalleryView()
                    .tabItem { Text("Gallery") }
                PlaygroundView()
                    .tabItem { Text("Playground") }
            }
            .frame(minWidth: 960, minHeight: 720)
        }
    }
}
