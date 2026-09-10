import AppKit
import SwiftUI

// The panel never becomes key/main; neither incoming requests nor hovering
// activate Reprise. Bookmark windows and their store are not instantiated.
final class ReprisePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    init() {
        super.init(contentRect: NSRect(origin: .zero, size: GateMetrics.canvas),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar; collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isOpaque = false; backgroundColor = .clear; hasShadow = false
        hidesOnDeactivate = false; isReleasedWhenClosed = false
    }
}
final class RepriseHost: NSHostingView<GateNotch> {
    var interactiveRect = NSRect.zero
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard interactiveRect.contains(point) else { return nil }
        return super.hitTest(point)
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var session: GateSession?
    var panel: ReprisePanel?
    var host: RepriseHost?
    var status: NSStatusItem?
    var timer: Timer?
    var observer: NSObjectProtocol?
    var screenObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let icon = Bundle.main.image(forResource: "Reprise") { NSApp.applicationIconImage = icon }
        let main = NSMenu(); let item = NSMenuItem(); item.submenu = makeMenu(); main.addItem(item); NSApp.mainMenu = main
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status?.button?.image = RepriseBrand.menuIcon(); status?.menu = makeMenu()
        do {
            let session = GateSession(backend: try GateStore(directory: GateStore.defaultDirectory()))
            self.session = session
            let panel = ReprisePanel(); panel.title = "Reprise — AEGIS Gate"
            let host = RepriseHost(rootView: GateNotch(session: session))
            panel.contentView = host; self.panel = panel; self.host = host
            placePanel(); update(); panel.orderFrontRegardless()
            observer = DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name(GateStore.notification), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.update() }
            }
            screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.placePanel() }
            }
            let timer = Timer(timeInterval: 0.10, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.update() }
            }
            RunLoop.main.add(timer, forMode: .common); self.timer = timer
        } catch {
            // Fail closed with a visible menu status; no fallback to bookmark storage.
            let failure = NSMenuItem(title: "Gate indisponible — vérifier le stockage", action: nil, keyEquivalent: "")
            status?.menu?.insertItem(failure, at: 0)
        }
    }
    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Envoyer une demande de démonstration", action: #selector(demo), keyEquivalent: "")
        menu.addItem(withTitle: "Refuser toutes les demandes en attente", action: #selector(denyAll), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quitter Reprise", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
        return menu
    }
    private func placePanel() {
        guard let screen = NSScreen.screens.first, let panel else { return }
        let frame = screen.frame; let size = GateMetrics.canvas
        panel.setFrame(NSRect(x: frame.maxX - size.width, y: frame.midY - size.height / 2,
                              width: size.width, height: size.height), display: true)
    }
    private func update() {
        guard let session, let panel, let host else { return }
        let size = GateMetrics.size(session)
        let rect = NSRect(x: GateMetrics.canvas.width - size.width,
                          y: (GateMetrics.canvas.height - size.height) / 2,
                          width: size.width, height: size.height)
        host.interactiveRect = rect
        let cursor = NSEvent.mouseLocation
        let point = NSPoint(x: cursor.x - panel.frame.minX, y: panel.frame.maxY - cursor.y)
        let inside = rect.insetBy(dx: -3, dy: -4).contains(point)
        panel.ignoresMouseEvents = !inside
        session.hover(inside); session.tick()
    }
    @objc private func demo() { session?.sendDemo(); update() }
    @objc private func denyAll() { session?.denyAll(); update() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        session?.reveal(); return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        if let observer { DistributedNotificationCenter.default().removeObserver(observer) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        // Pending requests survive quitting. Their deadline remains authoritative.
    }
}

@main struct RepriseApplication {
    static func main() {
        let app = NSApplication.shared; let delegate = AppDelegate()
        app.setActivationPolicy(.accessory); app.delegate = delegate
        app.run(); withExtendedLifetime(delegate) {}
    }
}
