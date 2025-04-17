import Gtk
import Gtk4LayerShell
import GtkBackend
import SwiftCrossUI

/// The ``SceneGraphNode`` corresponding to a ``WindowGroup`` scene. Holds
/// the scene's view graph and window handle.
public final class LayerShellGroupNode<Content: View>: SceneGraphNode {
    public typealias NodeScene = LayerShellGroup<Content>

    /// The node's scene.
    private var scene: LayerShellGroup<Content>
    /// The view graph of the window group's root view. Will need to be multiple
    /// view graphs once having multiple copies of a window is supported.
    private var viewGraph: ViewGraph<Content>
    /// The window that the group is getting rendered in. Will need to be multiple
    /// windows once having multiple copies of a window is supported.
    private var window: Any
    /// `false` after the first scene update.
    private var isFirstUpdate = true
    /// The environment most recently provided by this node's parent scene.
    private var parentEnvironment: EnvironmentValues
    /// The container used to center the root view in the window.
    private var containerWidget: AnyWidget

    private var monitors: [OpaquePointer]

    public init<Backend: AppBackend>(
        from scene: LayerShellGroup<Content>,
        backend: Backend,
        environment: EnvironmentValues
    ) {
        self.scene = scene
        let window = backend.createWindow(withDefaultSize: nil)

        if !Gtk4LayerShell.isSupported() {
            fatalError(
                "zwlr_layer_shell_v1 is not supported. Ensure you are running a Wayland compositor that implements the zwlr_layer_shell_v1 protocol"
            )
        }

        if let gtkWindow = window as? Gtk.ApplicationWindow {
            Gtk4LayerShell.initFor(window: gtkWindow)

            let monitors = Gtk4LayerShell.Display.getMonitors()

            self.monitors = monitors

            LayerShellGroupNode<Content>.setup_layer_shell(
                scene: scene, gtkWindow: gtkWindow, monitors: monitors)

            Gtk4LayerShell.setNamespace(window: gtkWindow, nameSpace: scene.namespace)

        } else {
            fatalError("Backend incompatible with zwlr_layer_shell_v1")
        }

        viewGraph = ViewGraph(
            for: scene.body,
            backend: backend,
            environment: environment.with(\.window, window)
        )

        let rootWidget = viewGraph.rootNode.concreteNode(for: Backend.self).widget

        let container = backend.createContainer()

        backend.addChild(rootWidget, to: container)

        self.containerWidget = AnyWidget(container)

        backend.setChild(ofWindow: window, to: container)
        backend.setResizability(ofWindow: window, to: true)

        self.window = window

        parentEnvironment = environment

        backend.setResizeHandler(ofWindow: window) { [weak self] newSize in
            guard let self else {
                return
            }
            _ = self.update(
                self.scene,
                proposedWindowSize: newSize,
                backend: backend,
                environment: parentEnvironment,
                windowSizeIsFinal: true
            )
        }
    }

    public func update<Backend: AppBackend>(
        _ newScene: LayerShellGroup<Content>?,
        backend: Backend,
        environment: EnvironmentValues
    ) {
        guard let window = window as? Backend.Window else {
            fatalError("Scene updated with a backend incompatible with the window it was given")
        }

        _ = update(
            newScene,
            proposedWindowSize: backend.size(ofWindow: window),
            backend: backend,
            environment: environment,
            windowSizeIsFinal: true
        )
    }

    public func update<Backend: AppBackend>(
        _ newScene: LayerShellGroup<Content>?,
        proposedWindowSize: SIMD2<Int>,
        backend: Backend,
        environment: EnvironmentValues,
        windowSizeIsFinal: Bool = true
    ) -> ViewUpdateResult {
        guard let window = window as? Backend.Window else {
            fatalError("Scene updated with a backend incompatible with the window it was given")
        }

        parentEnvironment = environment

        if let newScene = newScene {
            // Don't set default size even if it has changed. We only set that once
            // at window creation since some backends don't have a concept of
            // 'default' size which would mean that setting the default size every time
            // the default size changed would resize the window (which is incorrect
            // behaviour).
            backend.setResizability(ofWindow: window, to: true)

            // TODO check wether or not we need to update variables
            // we don't want to set this when we don't even need to change it
            if let gtkWindow = window as? Gtk.ApplicationWindow {
                LayerShellGroupNode<Content>.setup_layer_shell(
                    scene: scene, gtkWindow: gtkWindow, monitors: self.monitors)

                scene = newScene
            } else {
                fatalError("Backend incompatible with zwlr_layer_shell_v1")
            }
        }

        let environment =
            environment
            .with(\.onResize) { [weak self] _ in
                guard let self = self else { return }
                // TODO: Figure out whether this would still work if we didn't recompute the
                //   scene's body. I have a vague feeling that it wouldn't work in all cases?
                //   But I don't have the time to come up with a counterexample right now.
                _ = self.update(
                    self.scene,
                    proposedWindowSize: backend.size(ofWindow: window),
                    backend: backend,
                    environment: environment,
                    windowSizeIsFinal: true
                )
            }
            .with(\.window, window)

        let dryRunResult: ViewUpdateResult?
        if !windowSizeIsFinal {
            // Perform a dry-run update of the root view to check if the window
            // needs to change size.
            let contentResult = viewGraph.update(
                with: newScene?.body,
                proposedSize: proposedWindowSize,
                environment: environment,
                dryRun: true
            )
            dryRunResult = contentResult

            let newWindowSize = computeNewWindowSize(
                currentProposedSize: proposedWindowSize,
                backend: backend,
                contentSize: contentResult.size,
                environment: environment
            )

            // Restart the window update if the content has caused the window to
            // change size. To avoid infinite recursion, we take the view's word
            // and assume that it will take on the minimum/maximum size it claimed.
            if let newWindowSize {
                return update(
                    scene,
                    proposedWindowSize: newWindowSize,
                    backend: backend,
                    environment: environment,
                    windowSizeIsFinal: false
                )
            }
        } else {
            dryRunResult = nil
        }

        let finalContentResult = viewGraph.update(
            with: newScene?.body,
            proposedSize: proposedWindowSize,
            environment: environment,
            dryRun: false
        )

        // The Gtk 3 backend has some broken sizing code that can't really be
        // fixed due to the design of Gtk 3. Our layout system underestimates
        // the size of the new view due to the button not being in the Gtk 3
        // widget hierarchy yet (which prevents Gtk 3 from computing the
        // natural sizes of the new buttons). One fix seems to be removing
        // view size reuse (currently the second check in ViewGraphNode.update)
        // and I'm not exactly sure why, but that makes things awfully slow.
        // The other fix is to add an alternative path to
        // Gtk3Backend.naturalSize(of:) for buttons that moves non-realized
        // buttons to a secondary window before measuring their natural size,
        // but that's super janky, easy to break if the button in the real
        // window is inheriting styles from its ancestors, and I'm not sure
        // how to hide the window (it's probably terrible for performance too).
        //
        // I still have no clue why this size underestimation (and subsequent
        // mis-sizing of the window) had the symptom of all buttons losing
        // their labels temporarily; Gtk 3 is a temperamental beast.
        //
        // Anyway, Gtk3Backend isn't really intended to be a recommended
        // backend so I think this is a fine solution for now (people should
        // only use Gtk3Backend if they can't use GtkBackend).
        if let dryRunResult, finalContentResult.size != dryRunResult.size {
            print(
                """
                warning: Final window content size didn't match dry-run size. This is a sign that
                         either view size caching is broken or that backend.naturalSize(of:) is 
                         broken (or both).
                      -> dryRunResult.size:       \(dryRunResult.size)
                      -> finalContentResult.size: \(finalContentResult.size)
                """
            )

            // Give the view graph one more chance to sort itself out to fail
            // as gracefully as possible.
            let newWindowSize = computeNewWindowSize(
                currentProposedSize: proposedWindowSize,
                backend: backend,
                contentSize: finalContentResult.size,
                environment: environment
            )

            if let newWindowSize {
                return update(
                    scene,
                    proposedWindowSize: newWindowSize,
                    backend: backend,
                    environment: environment,
                    windowSizeIsFinal: true
                )
            }
        }

        // Set this even if the window isn't programmatically resizable
        // because the window may still be user resizable.
        backend.setPosition(
            ofChildAt: 0,
            in: containerWidget.into(),
            to: SIMD2(
                (proposedWindowSize.x - finalContentResult.size.size.x) / 2,
                (proposedWindowSize.y - finalContentResult.size.size.y) / 2
            )
        )

        let currentWindowSize = backend.size(ofWindow: window)
        if currentWindowSize != proposedWindowSize {
            backend.setSize(ofWindow: window, to: proposedWindowSize)
        }

        if isFirstUpdate {
            backend.show(window: window)
            isFirstUpdate = false
        }

        return finalContentResult
    }

    public func computeNewWindowSize<Backend: AppBackend>(
        currentProposedSize: SIMD2<Int>,
        backend: Backend,
        contentSize: ViewSize,
        environment: EnvironmentValues
    ) -> SIMD2<Int>? {
        if contentSize.idealSize != currentProposedSize {
            return contentSize.idealSize
        } else {
            return nil
        }
    }

    static func setup_layer_shell(
        scene: LayerShellGroup<Content>, gtkWindow: Gtk.ApplicationWindow, monitors: [OpaquePointer]
    ) {
        if let anchor = scene.anchor {
            for anchor_item in anchor {
                Gtk4LayerShell.setAnchor(
                    window: gtkWindow, edge: anchor_item, anchorToEdge: true)
            }
        } else {
            let anchor: [Gtk4LayerShell.Edge] = [.top, .bottom, .left, .right]

            for anchor_item in anchor {
                Gtk4LayerShell.setAnchor(
                    window: gtkWindow, edge: anchor_item, anchorToEdge: true)
            }
        }

        Gtk4LayerShell.setMargin(
            window: gtkWindow, edge: .bottom, marginSize: scene.margin_bottom)
        Gtk4LayerShell.setMargin(
            window: gtkWindow, edge: .left, marginSize: scene.margin_left)
        Gtk4LayerShell.setMargin(
            window: gtkWindow, edge: .right, marginSize: scene.margin_right)
        Gtk4LayerShell.setMargin(
            window: gtkWindow, edge: .top, marginSize: scene.margin_top)

        Gtk4LayerShell.setLayer(window: gtkWindow, layer: scene.layer)

        Gtk4LayerShell.setKeyboardMode(window: gtkWindow, mode: scene.keyboard_mode)

        if scene.exclusivity == .exclusive {
            Gtk4LayerShell.autoExclusiveZoneEnable(window: gtkWindow)
        } else {
            Gtk4LayerShell.setExclusiveZone(
                window: gtkWindow, exclusiveZone: scene.exclusivity.rawValue)
        }

        if let monitor_index = scene.monitor {
            // TODO out of bounds
            let monitor = monitors[monitor_index]

            Gtk4LayerShell.setMonitor(window: gtkWindow, monitor: monitor)
        }

        // TODO popup
    }
}
