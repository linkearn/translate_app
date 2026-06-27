import SwiftUI
import AppKit

@main
struct CyberTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup("Cyber·Translate") {
            ContentView()
                .environmentObject(state)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)

        MenuBarExtra("Cyber·Translate", systemImage: "antenna.radiowaves.left.and.right") {
            Button("ウィンドウを表示") {
                NSApp.activate(ignoringOtherApps: true)
                for w in NSApp.windows where w.canBecomeMain { w.makeKeyAndOrderFront(nil) }
            }
            Divider()
            Button("クリップボードを翻訳") {
                if let s = NSPasteboard.general.string(forType: .string) {
                    state.capture(s)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }.keyboardShortcut("v", modifiers: [.command, .shift])
            Divider()
            Button("終了") { NSApp.terminate(nil) }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // keep running in the menu bar for global hotkey capture
    }
}
