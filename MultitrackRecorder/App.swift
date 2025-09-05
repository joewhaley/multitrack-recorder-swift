import SwiftUI
import AppKit

@main
struct MultitrackRecorderApp: App {
    var body: some Scene {
        WindowGroup {
            PortAudioContentView()
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
                    // Only close the app when the main content window closes
                    if let window = notification.object as? NSWindow,
                       window.isMainWindow {
                        NSApplication.shared.terminate(nil)
                    }
                }
        }
        .windowResizability(.contentSize)
    }
}
