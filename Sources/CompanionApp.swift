import AppKit
import SwiftUI

@main
struct CapriCompanionApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = CompanionAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class CompanionAppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPetPanel?
    private var mainframePanel: FloatingPetPanel?
    private var statusItem: NSStatusItem?
    private let store = AppStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        createPanel()
        createStatusItem()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        Task { await store.refreshConnection() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func createPanel() {
        let scale = CGFloat(store.petScale)
        let size = CGSize(width: 184 * scale, height: 316 * scale)
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let rect = NSRect(x: visible.maxX - size.width - 24, y: visible.maxY - size.height - 24,
                          width: size.width, height: size.height)
        let window = FloatingPetPanel(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = store.petMovementEnabled
        window.hidesOnDeactivate = false
        window.title = "Capri Companion"
        window.contentView = NSHostingView(rootView: CompanionRootView(store: store))
        panel = window
    }

    private func createMainframePanel() {
        guard mainframePanel == nil else { return }
        let size = CGSize(width: 496, height: 724)
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let rect = NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                          width: size.width, height: size.height)
        let window = FloatingPetPanel(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.hidesOnDeactivate = false
        window.title = "Capri Mainframe"
        window.contentView = NSHostingView(rootView: MainframeWindowRootView(store: store))
        mainframePanel = window
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "bird.fill", accessibilityDescription: "Capri Companion")
                ?? NSImage(systemSymbolName: "circle.hexagongrid.fill", accessibilityDescription: "Capri Companion")
            button.toolTip = "Capri Companion"
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Capri", action: #selector(showPet), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Open Mainframe", action: #selector(openMainframe), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Capri Companion", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc func showPet() {
        store.page = .companion
        panel?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openMainframe() {
        store.page = .mainframe
        createMainframePanel()
        mainframePanel?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func closeMainframe() {
        mainframePanel?.orderOut(nil)
        store.page = .companion
        panel?.orderFrontRegardless()
    }

    @objc func setPetMovementEnabled(_ enabled: Bool) {
        store.petMovementEnabled = enabled
        panel?.isMovableByWindowBackground = enabled
    }

    @objc func resetPetPosition() {
        guard let panel else { return }
        let visible = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        panel.setFrameOrigin(NSPoint(x: visible.maxX - panel.frame.width - 24,
                                     y: visible.maxY - panel.frame.height - 24))
        setPetMovementEnabled(true)
    }

    @objc func hidePet() {
        panel?.orderOut(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

@MainActor
private final class FloatingPetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class CompanionController {
    static let shared = CompanionController()
    private init() {}
    func hidePet() { (NSApp.delegate as? CompanionAppDelegate)?.hidePet() }
    func openMainframe() { (NSApp.delegate as? CompanionAppDelegate)?.openMainframe() }
    func closeMainframe() { (NSApp.delegate as? CompanionAppDelegate)?.closeMainframe() }
    func setPetMovementEnabled(_ enabled: Bool) { (NSApp.delegate as? CompanionAppDelegate)?.setPetMovementEnabled(enabled) }
    func resetPetPosition() { (NSApp.delegate as? CompanionAppDelegate)?.resetPetPosition() }
}
