import AppKit
import SwiftUI

/// Owns the menu bar status item and a non-activating panel that drops down
/// beneath it. Using a panel (not NSPopover) means showing it never activates
/// the app, so the user's current window keeps keyboard focus.
@MainActor
final class StatusBarController: NSObject {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var outsideClickMonitor: Any?

    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "AgentPet")
        item.button?.target = self
        item.button?.action = #selector(toggle)
        statusItem = item
    }

    @objc private func toggle() {
        if panel != nil { close() } else { open() }
    }

    private func open() {
        guard let button = statusItem?.button, let buttonWindow = button.window else { return }

        let hosting = NSHostingView(rootView: MenuContentView(dismiss: { [weak self] in self?.close() }))
        hosting.setFrameSize(NSSize(width: 300, height: 400))
        let size = hosting.fittingSize

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = hosting

        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        panel.setFrameOrigin(NSPoint(x: buttonFrame.maxX - size.width, y: buttonFrame.minY - size.height - 4))
        panel.orderFrontRegardless()
        self.panel = panel

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    private func close() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
    }
}
