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

            LayerShellGroupNode<Content>.setup_layer_shell(scene: scene, gtkWindow: gtkWindow)

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

        self.window = window
        parentEnvironment = environment
    }

    public func update<Backend: AppBackend>(
        _ newScene: LayerShellGroup<Content>?,
        backend: Backend,
        environment: EnvironmentValues
    ) {
        guard let window = window as? Backend.Window else {
            fatalError("Scene updated with a backend incompatible with the window it was given")
        }

        // We don't care about rezising and related for this window
        // since that's the job of the layer shell library
        // We just need to update the layer related variables in case they changed

        parentEnvironment = environment

        if let newScene = newScene {
            // Don't set default size even if it has changed. We only set that once
            // at window creation since some backends don't have a concept of
            // 'default' size which would mean that setting the default size every time
            // the default size changed would resize the window (which is incorrect
            // behaviour).
            // backend.setTitle(ofWindow: window, to: newScene.title)
            // backend.setResizability(ofWindow: window, to: newScene.resizability.isResizable)

            // TODO set layer variabled
            if let gtkWindow = window as? Gtk.ApplicationWindow {
                Gtk4LayerShell.initFor(window: gtkWindow)

                LayerShellGroupNode<Content>.setup_layer_shell(scene: scene, gtkWindow: gtkWindow)

                scene = newScene
            } else {
                fatalError("Backend incompatible with zwlr_layer_shell_v1")
            }

        }

        // TODO is this even correct/needed? HUH
        let proposedWindowSize = backend.size(ofWindow: window)

        let _ = viewGraph.update(
            with: newScene?.body,
            proposedSize: proposedWindowSize,
            environment: environment,
            dryRun: false
        )

        if isFirstUpdate {
            backend.show(window: window)
            isFirstUpdate = false
        }
    }

    static func setup_layer_shell(
        scene: LayerShellGroup<Content>, gtkWindow: Gtk.ApplicationWindow
    ) {
        if let monitor_index = scene.monitor {
            let monitor = Gtk4LayerShell.Display.getMonitor(index: monitor_index)
            Gtk4LayerShell.setMonitor(window: gtkWindow, monitor: monitor.opaquePointer!)
        }

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

        if scene.exclusivity == .exclusive {
            Gtk4LayerShell.autoExclusiveZoneEnable(window: gtkWindow)
        } else {
            Gtk4LayerShell.setExclusiveZone(
                window: gtkWindow, exclusiveZone: scene.exclusivity.rawValue)
        }

        Gtk4LayerShell.setLayer(window: gtkWindow, layer: scene.layer)

        Gtk4LayerShell.setKeyboardMode(window: gtkWindow, mode: scene.keyboard_mode)

        // TODO popup

        Gtk4LayerShell.setMargin(
            window: gtkWindow, edge: .bottom, marginSize: scene.margin_bottom)
        Gtk4LayerShell.setMargin(
            window: gtkWindow, edge: .left, marginSize: scene.margin_left)
        Gtk4LayerShell.setMargin(
            window: gtkWindow, edge: .right, marginSize: scene.margin_right)
        Gtk4LayerShell.setMargin(
            window: gtkWindow, edge: .top, marginSize: scene.margin_top)
    }
}
