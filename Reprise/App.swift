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
        super.init(contentRect: NSRect(x: 0, y: 0, width: 288, height: 304), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar; collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isOpaque = false; backgroundColor = .clear; hasShadow = false
        hidesOnDeactivate = false; isReleasedWhenClosed = false
    }
}

final class RepriseHost: NSHostingView<RepriseNotch> {
    var interactiveRect = NSRect.zero
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard interactiveRect.contains(point) else { return nil }
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
    var host: RepriseHost!
    var monitors: [Any] = []
    var cursorTimer: Timer?
    var screenObserver: Any?
    var captureObserver: NSObjectProtocol?
    var captureTimer: Timer?
    var ticks: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let icon = Bundle.main.image(forResource: "Reprise") { NSApp.applicationIconImage = icon }
        let main = NSMenu()
        let appMenu = NSMenu(); appMenu.addItem(withTitle: "Mes fils", action: #selector(showPresentation), keyEquivalent: "0")
        appMenu.addItem(.separator()); appMenu.addItem(withTitle: "Quitter Reprise", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem(); appItem.submenu = appMenu; main.addItem(appItem)
        let editMenu = NSMenu(title: "Édition")
        for (title, action, key) in [("Couper", #selector(NSText.cut(_:)), "x"), ("Copier", #selector(NSText.copy(_:)), "c"), ("Coller", #selector(NSText.paste(_:)), "v"), ("Tout sélectionner", #selector(NSText.selectAll(_:)), "a")] {
            editMenu.addItem(withTitle: title, action: action, keyEquivalent: key)
        }
        let editItem = NSMenuItem(); editItem.submenu = editMenu; main.addItem(editItem)
        NSApp.mainMenu = main

        panel = ReprisePanel(); panel.title = "Reprise — Le fil"
        host = RepriseHost(rootView: RepriseNotch(store: store))
        panel.contentView = host
        store.openEditor = { [weak self] in self?.showEditor() }
        store.showWelcome = { [weak self] in self?.showPresentation() }
        store.onShapeChange = { [weak self] in self?.reveal() }
        placePanel(); panel.orderFrontRegardless()
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.placePanel() }
        }
        // Keep the window frame fixed; only the SwiftUI shape animates.
        // Cursor tracking is owned here, not by two competing SwiftUI views.
        ticks = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.placePanel(); self?.cursorMoved() }
        }
        let eventTypes: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: eventTypes, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.cursorMoved() }
        }) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: eventTypes, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.cursorMoved() }; return event
        }) { monitors.append(local) }
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.cursorMoved() }
        }
        RunLoop.main.add(timer, forMode: .common); cursorTimer = timer
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = RepriseBrand.menuIcon()
        let menu = NSMenu()
        menu.addItem(withTitle: "Retrouver mon fil", action: #selector(reveal), keyEquivalent: "")
        menu.addItem(withTitle: "Déposer un fil…", action: #selector(newThread), keyEquivalent: "")
        menu.addItem(withTitle: "Coller un lien ou un extrait…", action: #selector(pasteThread), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Changer de bord", action: #selector(changeSide), keyEquivalent: "")
        menu.addItem(withTitle: "Mes fils", action: #selector(showPresentation), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quitter Reprise", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
        status.menu = menu
        captureObserver = DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name(CaptureInbox.notification), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.store.drainCaptures() }
        }
        captureTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.store.drainCaptures() }
        }
        store.drainCaptures()
        if !CommandLine.arguments.contains("--quiet") { showPresentation() }
    }
    func placePanel() {
        guard let screen = NSScreen.screens.first else { return }
        let frame = screen.frame
        let size = RepriseMetrics.canvas
        let target = NSRect(x: store.side == .right ? frame.maxX - size.width : frame.minX,
                            y: frame.midY - size.height / 2 - min(80, frame.height * 0.08),
                            width: size.width, height: size.height)
        if panel.frame != target { panel.setFrame(target, display: true) }
    }
    func cursorMoved() {
        guard let panel, let host else { return }
        let size = store.isOpen ? RepriseMetrics.expandedSize(note: store.note, targeted: store.targeted) : RepriseMetrics.closed
        let rect = NSRect(x: store.side == .right ? RepriseMetrics.canvas.width - size.width : 0,
                          y: (RepriseMetrics.canvas.height - size.height) / 2,
                          width: size.width, height: size.height)
        host.interactiveRect = rect
        let cursor = NSEvent.mouseLocation
        let point = NSPoint(x: cursor.x - panel.frame.minX, y: panel.frame.maxY - cursor.y)
        let inside = rect.insetBy(dx: -3, dy: -4).contains(point)
        panel.ignoresMouseEvents = !inside && !store.targeted
        if !store.editing { store.hover(inside) }
    }
    @objc func reveal() {
        welcome?.orderOut(nil); store.reveal(); panel.orderFrontRegardless()
    }
    @objc func newThread() { store.edit() }
    @objc func pasteThread() { store.paste() }
    @objc func changeSide() { store.side = store.side == .right ? .left : .right; placePanel() }
    @objc func showPresentation() {
        store.fold()
        if welcome == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 550), styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "Reprise — Mes fils"; window.titlebarAppearsTransparent = true; window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false; window.backgroundColor = NSColor(Atelier.paper)
            window.contentView = NSHostingView(rootView: LibraryView(store: store))
            window.center(); welcome = window
        }
        welcome?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func showEditor() {
        if let editor { editor.close() }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 490), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Garder un fil — Reprise"; window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(Atelier.paper); window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua); window.delegate = self
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
