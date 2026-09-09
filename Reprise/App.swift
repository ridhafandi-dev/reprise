import AppKit
import SwiftUI
import Combine

// Panel behavior adapted from Codenotch's NotchPanel: non-activating, edge
// anchored, transparent, and visible across spaces. Editing uses a separate
// normal window so hovering never steals keyboard focus.
final class ReprisePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 430, height: 488), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar; collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isOpaque = false; backgroundColor = .clear; hasShadow = false
        hidesOnDeactivate = false; isReleasedWhenClosed = false
    }
}

final class RepriseHost: NSHostingView<RepriseNotch> {
    var store: RepriseStore!
    override func hitTest(_ point: NSPoint) -> NSView? {
        let width: CGFloat = store.isOpen ? 382 : 40
        let height: CGFloat = store.isOpen ? 448 : 132
        let x: CGFloat = store.side == .right ? bounds.maxX - width : 0
        let visible = NSRect(x: x, y: (bounds.height - height) / 2, width: width, height: height)
        guard visible.contains(point) else { return nil }
        return super.hitTest(point)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = RepriseStore()
    var panel: ReprisePanel!
    var welcome: NSWindow?
    var editor: NSWindow?
    var status: NSStatusItem!
    var monitor: Any?
    var screenObserver: Any?
    var ticks: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let main = NSMenu()
        let appMenu = NSMenu(); appMenu.addItem(withTitle: "Présentation de Reprise", action: #selector(showPresentation), keyEquivalent: "0")
        appMenu.addItem(.separator()); appMenu.addItem(withTitle: "Quitter Reprise", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem(); appItem.submenu = appMenu; main.addItem(appItem)
        let editMenu = NSMenu(title: "Édition")
        for (title, action, key) in [("Couper", #selector(NSText.cut(_:)), "x"), ("Copier", #selector(NSText.copy(_:)), "c"), ("Coller", #selector(NSText.paste(_:)), "v"), ("Tout sélectionner", #selector(NSText.selectAll(_:)), "a")] {
            editMenu.addItem(withTitle: title, action: action, keyEquivalent: key)
        }
        let editItem = NSMenuItem(); editItem.submenu = editMenu; main.addItem(editItem)
        NSApp.mainMenu = main

        panel = ReprisePanel(); panel.title = "Reprise — Le fil"
        let host = NSHostingView(rootView: RepriseNotch(store: store))
        panel.contentView = host
        store.openEditor = { [weak self] in self?.showEditor() }
        store.showWelcome = { [weak self] in self?.showPresentation() }
        placePanel(); panel.orderFrontRegardless()
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.placePanel() }
        }
        // Size the native window to the visible notch. A large invisible
        // window with ignoresMouseEvents toggled by polling can swallow AX
        // presses and incoming drags; the compact window needs no such timer.
        ticks = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.placePanel() }
        }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "bookmark", accessibilityDescription: "Reprise")
        let menu = NSMenu()
        menu.addItem(withTitle: "Retrouver mon fil", action: #selector(reveal), keyEquivalent: "")
        menu.addItem(withTitle: "Déposer un fil…", action: #selector(newThread), keyEquivalent: "")
        menu.addItem(withTitle: "Coller un lien ou un extrait…", action: #selector(pasteThread), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Changer de bord", action: #selector(changeSide), keyEquivalent: "")
        menu.addItem(withTitle: "Présentation", action: #selector(showPresentation), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quitter Reprise", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
        status.menu = menu
        if !CommandLine.arguments.contains("--quiet") { showPresentation() }
    }
    func placePanel() {
        guard let screen = NSScreen.screens.first else { return }
        let frame = screen.frame
        let width: CGFloat = store.isOpen ? 382 : 40
        let height: CGFloat = store.isOpen ? 448 : 132
        let target = NSRect(x: store.side == .right ? frame.maxX - width : frame.minX,
                            y: frame.midY - height / 2 - min(80, frame.height * 0.08),
                            width: width, height: height)
        panel.setFrame(target, display: true)
    }
    @objc func reveal() {
        welcome?.orderOut(nil); store.reveal(); panel.orderFrontRegardless()
    }
    @objc func newThread() { store.edit() }
    @objc func pasteThread() { store.paste() }
    @objc func changeSide() { store.side = store.side == .right ? .left : .right; placePanel() }
    @objc func showPresentation() {
        if welcome == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 870, height: 532), styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "Reprise — Étude 01"; window.titlebarAppearsTransparent = true; window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false; window.backgroundColor = NSColor(Ink.paper)
            window.contentView = NSHostingView(rootView: WelcomeView(store: store) { [weak self] in self?.reveal() })
            window.center(); welcome = window
        }
        welcome?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func showEditor() {
        if let editor { editor.close() }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 490), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Garder un fil — Reprise"; window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(Ink.black); window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua); window.delegate = self
        window.contentView = NSHostingView(rootView: EditorView(store: store) { [weak self] in self?.editor?.close() })
        window.center(); editor = window; window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func windowWillClose(_ notification: Notification) { store.editing = false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPresentation(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct RepriseApplication {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.regular); app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
