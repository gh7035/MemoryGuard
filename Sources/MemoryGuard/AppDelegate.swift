import AppKit
import SwiftUI
import Combine
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    let monitor = MemoryMonitor()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        NotificationManager.shared.setup()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.behavior = .transient

        monitor.$usedMemoryGB
            .combineLatest(monitor.$currentLevel)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] used, level in self?.updateButton(used: used, level: level) }
            .store(in: &cancellables)
    }

    private func updateButton(used: Double, level: AlertLevel) {
        guard let button = statusItem.button else { return }
        let color: NSColor
        switch level {
        case .normal:   color = .systemGreen
        case .warning:  color = .systemYellow
        case .critical: color = .systemRed
        }
        button.attributedTitle = NSAttributedString(
            string: String(format: "%.1f GB", used),
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: color
            ]
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // 팝오버 열 때마다 뷰 새로 생성 — 닫혀있는 동안 메모리 해제
            popover.contentViewController = NSHostingController(
                rootView: MenuBarView().environmentObject(monitor)
            )
            popover.contentSize = NSSize(width: 290, height: 540)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
