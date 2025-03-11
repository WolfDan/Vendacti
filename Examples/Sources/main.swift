import DefaultBackend
import SwiftCrossUI
import Vendacti

#if canImport(SwiftBundlerRuntime)
    import SwiftBundlerRuntime
#endif

@main
@HotReloadable
struct BarApp: App {
    @State var count = 0

    var body: some Scene {
        LayerShellGroup("vendacti_window_0") {
            #hotReloadable {
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
        }
        .monitor(0)
        .anchor([.left, .top, .right])
        .exclusivity(.exclusive)
    }
}
