import Gtk4LayerShell
import GtkBackend
import SwiftCrossUI

#if !os(WASI)
    import Foundation
#endif

public enum Exclusivity: Int {
    case ignore = -1
    case normal = 0
    case exclusive = 1
}

/// A scene that presents a group of identically structured windows. Currently
/// only supports having a single instance of the window but will eventually
/// support duplicating the window.
public struct LayerShellGroup<Content: View>: Scene {
    public typealias Node = LayerShellGroupNode<Content>

    public let commands: Commands = Commands(menus: [])

    /// Storing the window group contents lazily allows us to recompute the view
    /// when the window size changes without having to recompute the whole app.
    /// This allows the window group contents to remain linked to the app state
    /// instead of getting frozen in time when the app's body gets evaluated.
    var content: () -> Content

    var body: Content {
        content()
    }

    var monitor: Int?

    var anchor: [Gtk4LayerShell.Edge]?

    var exclusivity: Exclusivity

    var layer: Gtk4LayerShell.Layer

    var keyboard_mode: Gtk4LayerShell.KeyboardMode

    var popup: Bool

    var margin_bottom: Int

    var margin_left: Int

    var margin_right: Int

    var margin_top: Int

    /// The unqiue namespece for the window
    var namespace: String

    /// Creates a window group in the given unique namespace
    public init(_ namespace: String, @ViewBuilder _ content: @escaping () -> Content) {
        self.content = content
        self.namespace = namespace
        monitor = nil
        anchor = nil
        exclusivity = .normal
        layer = .top
        keyboard_mode = .none
        popup = false
        margin_bottom = 0
        margin_left = 0
        margin_right = 0
        margin_top = 0
    }

    public func monitor(_ monitor: Int) -> Self {
        var windowGroup = self
        windowGroup.monitor = monitor
        return windowGroup
    }

    public func anchor(_ anchor: [Gtk4LayerShell.Edge]) -> Self {
        var windowGroup = self
        windowGroup.anchor = anchor
        return windowGroup
    }

    public func exclusivity(_ exclusivity: Exclusivity) -> Self {
        var windowGroup = self
        windowGroup.exclusivity = exclusivity
        return windowGroup
    }

    public func layer(_ layer: Gtk4LayerShell.Layer) -> Self {
        var windowGroup = self
        windowGroup.layer = layer
        return windowGroup
    }

    public func keyboardMode(_ keyboard_mode: Gtk4LayerShell.KeyboardMode) -> Self {
        var windowGroup = self
        windowGroup.keyboard_mode = keyboard_mode
        return windowGroup
    }

    public func popup(_ popup: Bool) -> Self {
        var windowGroup = self
        windowGroup.popup = popup
        return windowGroup
    }

    public func marginBottom(_ margin_bottom: Int) -> Self {
        var windowGroup = self
        windowGroup.margin_bottom = margin_bottom
        return windowGroup
    }

    public func marginLeft(_ margin_left: Int) -> Self {
        var windowGroup = self
        windowGroup.margin_left = margin_left
        return windowGroup
    }

    public func marginRight(_ margin_right: Int) -> Self {
        var windowGroup = self
        windowGroup.margin_right = margin_right
        return windowGroup
    }

    public func marginTop(_ margin_top: Int) -> Self {
        var windowGroup = self
        windowGroup.margin_top = margin_top
        return windowGroup
    }
}
