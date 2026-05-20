import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var store: AppStore!
    private let theme = AppTheme()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var dashboardWindow: NSWindow?
    private var subscriptions = Set<AnyCancellable>()
    private var popoverMonitor: Any?
    private var lastIconKey: String = ""

    func applicationWillFinishLaunching(_ notification: Notification) {
        guardSingleInstance()
    }

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Fonts.registerBundled()

        let store = AppStore()
        self.store = store

        setupStatusItem(store: store)
        setupPopover(store: store)
        observeStore(store)
        refreshStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.saveNow()
    }

    private func guardSingleInstance() {
        let me = ProcessInfo.processInfo.processIdentifier
        let bid = Bundle.main.bundleIdentifier
        let mineByID = bid.map {
            NSRunningApplication.runningApplications(withBundleIdentifier: $0)
        } ?? []
        let others = mineByID.filter { $0.processIdentifier != me }
        if !others.isEmpty {
            NSApp.terminate(nil)
        }
    }

    @MainActor
    private func setupStatusItem(store: AppStore) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleStatusClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Flow"
        }
    }

    @MainActor
    private func setupPopover(store: AppStore) {
        let panel = MenuBarPanel(
            onOpenDashboard: { [weak self] in
                self?.closePopover()
                self?.openDashboard()
            },
            onClose: { [weak self] in self?.closePopover() }
        )
        .environmentObject(store)
        .environmentObject(theme)

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.appearance = theme.nsAppearance
        let hosting = NSHostingController(rootView: panel)
        hosting.sizingOptions = [.intrinsicContentSize]
        popover.contentViewController = hosting

        // Track system theme changes for the popover too.
        theme.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.popover.appearance = self.theme.nsAppearance
            }
            .store(in: &subscriptions)
    }

    private func observeStore(_ store: AppStore) {
        // Refresh the menu bar icon whenever the displayed time string changes (1Hz while running,
        // single update when starting/stopping) or the active task changes.
        store.$elapsedDisplay
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshStatusItem() }
            .store(in: &subscriptions)
        store.$currentTaskID
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshStatusItem()
                self?.reanchorPopoverIfShown()
            }
            .store(in: &subscriptions)
    }

    @MainActor
    private func reanchorPopoverIfShown() {
        guard let popover = popover, popover.isShown,
              let button = statusItem?.button else { return }
        popover.performClose(nil)
        DispatchQueue.main.async { [weak self] in
            self?.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @MainActor
    private func refreshStatusItem() {
        guard let button = statusItem?.button, let store = store else { return }
        let key = store.currentTask == nil ? "idle" : store.elapsedDisplay
        if key == lastIconKey, button.image != nil { return }
        lastIconKey = key
        let img = MenuBarIcon.render(running: store.currentTask, elapsed: store.elapsedDisplay)
        button.image = img
        button.imagePosition = .imageOnly
    }

    @objc
    private func handleStatusClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        switch event.type {
        case .rightMouseUp:
            showRightClickMenu()
        case .leftMouseUp:
            if event.modifierFlags.contains(.option), store?.currentTask != nil {
                store.pauseResume()
                return
            }
            togglePopover()
        default:
            togglePopover()
        }
    }

    @MainActor
    private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    @MainActor
    private func openPopover() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        if popoverMonitor == nil {
            popoverMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    private func closePopover() {
        if popover.isShown { popover.performClose(nil) }
        if let m = popoverMonitor {
            NSEvent.removeMonitor(m)
            popoverMonitor = nil
        }
    }

    @MainActor
    private func showRightClickMenu() {
        let menu = NSMenu()
        let newItem = NSMenuItem(title: "New task…", action: #selector(menuNewTask), keyEquivalent: "n")
        newItem.target = self
        menu.addItem(newItem)

        if store?.currentTask != nil {
            let end = NSMenuItem(title: "End current task", action: #selector(menuEndTask), keyEquivalent: "")
            end.target = self
            menu.addItem(end)
        }

        menu.addItem(.separator())

        let dash = NSMenuItem(title: "Open dashboard", action: #selector(menuOpenDashboard), keyEquivalent: "d")
        dash.target = self
        menu.addItem(dash)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Flow", action: #selector(menuQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @MainActor @objc private func menuNewTask() {
        store.draftName = ""
        openPopover()
    }

    @MainActor @objc private func menuEndTask() {
        store.endCurrentTask()
    }

    @MainActor @objc private func menuOpenDashboard() {
        openDashboard()
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }

    @MainActor
    private func openDashboard() {
        if let existing = dashboardWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let root = DashboardView()
            .environmentObject(store)
            .environmentObject(theme)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.contentViewController = hosting
        window.appearance = theme.nsAppearance
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        // Let the frosted BlurView in DashboardView paint the whole window.
        window.isOpaque = false
        window.backgroundColor = .clear
        window.title = "Flow"
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        dashboardWindow = window

        // Keep the window appearance in sync with the system pref.
        theme.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self, weak window] _ in
                window?.appearance = self?.theme.nsAppearance
            }
            .store(in: &subscriptions)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === dashboardWindow {
            dashboardWindow = nil
        }
    }
}
