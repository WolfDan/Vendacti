import GtkBackend
import SwiftCrossUI
import Vendacti

@main
struct BarApp: App {
    @State var count = 0

    var backend = GtkBackend(appIdentifier: "com.vendacti.BarApp")

    var body: some Scene {
        LayerShellGroup("vendacti_window_0") {
            HStack(spacing: 20) {
                Button("-") {
                    count -= 1
                }
                Text("Count: \(count)")
                Button("+") {
                    count += 1
                }
            }
            .padding()
        }
        .monitor(0)
        .anchor([.left, .top, .right])
        .exclusivity(.exclusive)
    }
}
