import SwiftUI

@main
struct CleanerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 960, height: 680)
        .commands {
            CommandGroup(after: .appInfo) {
                Divider()
                Button("Check for Updates...") {
                    NotificationCenter.default.post(name: .init("checkForUpdates"), object: nil)
                }
            }

            CommandMenu("Scan") {
                Button("Smart Scan") {
                    NotificationCenter.default.post(name: .init("smartScan"), object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button("Scan All Categories") {
                    NotificationCenter.default.post(name: .init("scan"), object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Clean Selected") {
                    NotificationCenter.default.post(name: .init("clean"), object: nil)
                }
                .keyboardShortcut(.delete, modifiers: .command)
            }

            CommandGroup(replacing: .help) {
                Button("MacPurge Help") {
                    #if os(macOS)
                    if let url = URL(string: "https://github.com/dakshraman/MacPurge") {
                        NSWorkspace.shared.open(url)
                    }
                    #endif
                }
            }
        }

        #if os(macOS)
        MenuBarExtra("MacPurge", systemImage: "sparkles") {
            MenuBarWidgetView()
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
