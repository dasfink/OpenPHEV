import SwiftUI

@main
struct OpenPHEVApp: App {
    init() {
        AlertManager.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
