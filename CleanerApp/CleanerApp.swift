import SwiftUI

@main
struct CleanerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(after: .appInfo) {
                Divider()
                Button("Check for Updates...") {}
                    .disabled(true)
            }

            CommandMenu("Scan") {
                Button("Scan All") {
                    NotificationCenter.default.post(name: .init("scan"), object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Clean Selected") {
                    NotificationCenter.default.post(name: .init("clean"), object: nil)
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(true)
            }

            CommandGroup(replacing: .help) {
                Button("Cleaner Help") {}
                    .disabled(true)
            }
        }
    }
}
