import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let connectomeWindowStyleMask: NSWindow.StyleMask = [.titled, .closable, .resizable]
    static let repositoryURL = URL(string: "https://github.com/aopv/DesktopWorm")!
    static let developerXURL = URL(string: "https://x.com/apoorvdarshan")!

    private let engine: NeuralEngine
    private let world = WormWorld()

    private var overlayWindow: NSWindow!
    private var wormView: WormView!
    private var neuralWindow: NSPanel!
    private var neuralView: NeuralMapView!
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var previousTick = ProcessInfo.processInfo.systemUptime
    private var paused = false
    private var showsAnatomy = true
    private var pauseItem: NSMenuItem!
    private var behaviorItem: NSMenuItem!
    private var anatomyItem: NSMenuItem!
    private var speedItems: [NSMenuItem] = []

    init(connectome: Connectome) {
        self.engine = NeuralEngine(connectome: connectome)
        super.init()
    }

    static func connectomeHUDOrigin(windowSize: NSSize, visibleFrame: NSRect) -> CGPoint {
        CGPoint(
            x: max(visibleFrame.minX + 12, visibleFrame.maxX - windowSize.width - 18),
            y: visibleFrame.minY + 18
        )
    }

    static func makeStatusIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 3.1, y: 11.8))
            path.curve(
                to: NSPoint(x: 8.9, y: 12.7),
                controlPoint1: NSPoint(x: 4.1, y: 15.2),
                controlPoint2: NSPoint(x: 7.0, y: 15.2)
            )
            path.curve(
                to: NSPoint(x: 13.8, y: 10.3),
                controlPoint1: NSPoint(x: 11.0, y: 10.1),
                controlPoint2: NSPoint(x: 13.2, y: 12.8)
            )
            path.curve(
                to: NSPoint(x: 8.6, y: 5.0),
                controlPoint1: NSPoint(x: 14.4, y: 7.8),
                controlPoint2: NSPoint(x: 11.6, y: 5.0)
            )
            path.curve(
                to: NSPoint(x: 4.7, y: 6.8),
                controlPoint1: NSPoint(x: 6.8, y: 5.0),
                controlPoint2: NSPoint(x: 5.3, y: 5.5)
            )
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.lineWidth = 1.75
            NSColor.black.setStroke()
            path.stroke()

            let head = NSBezierPath(ovalIn: NSRect(x: 2.0, y: 10.7, width: 2.4, height: 2.4))
            NSColor.black.setFill()
            head.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "DesktopWorm"
        return image
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let mouse = NSEvent.mouseLocation
        let launchScreen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        configureOverlay(on: launchScreen)
        configureNeuralWindow(on: launchScreen)
        configureMenuBar()
        startLoop()
        showNeuralMap()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    private func configureOverlay(on selectedScreen: NSScreen?) {
        guard let screen = selectedScreen else { return }
        overlayWindow?.orderOut(nil)
        overlayWindow?.close()
        let frame = screen.frame
        world.place(at: CGPoint(x: frame.width * 0.57, y: frame.height * 0.55))

        overlayWindow = NSWindow(
            contentRect: CGRect(origin: .zero, size: frame.size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        overlayWindow.setFrame(frame, display: true)
        overlayWindow.backgroundColor = .clear
        overlayWindow.isOpaque = false
        overlayWindow.hasShadow = false
        overlayWindow.ignoresMouseEvents = true
        overlayWindow.level = .floating
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        overlayWindow.isReleasedWhenClosed = false

        wormView = WormView(frame: CGRect(origin: .zero, size: frame.size), world: world, engine: engine)
        wormView.showsAnatomy = showsAnatomy
        overlayWindow.contentView = wormView
        overlayWindow.orderFrontRegardless()
    }

    private func configureNeuralWindow(on selectedScreen: NSScreen?) {
        let contentSize = NSSize(width: 520, height: 340)
        let frame = NSRect(origin: .zero, size: contentSize)
        neuralWindow = NSPanel(
            contentRect: frame,
            styleMask: Self.connectomeWindowStyleMask,
            backing: .buffered,
            defer: false
        )
        neuralWindow.title = "DesktopWorm · Living Connectome"
        neuralWindow.appearance = NSAppearance(named: .darkAqua)
        neuralWindow.titleVisibility = .hidden
        neuralWindow.titlebarAppearsTransparent = false
        neuralWindow.backgroundColor = NSColor(calibratedRed: 0.025, green: 0.045, blue: 0.065, alpha: 1)
        neuralWindow.isFloatingPanel = true
        neuralWindow.hidesOnDeactivate = false
        neuralWindow.level = .floating
        neuralWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        neuralWindow.isReleasedWhenClosed = false
        neuralWindow.minSize = NSSize(width: 440, height: 280)
        neuralWindow.animationBehavior = .utilityWindow

        let visibleFrame = (selectedScreen ?? NSScreen.main)?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let placedFrame = neuralWindow.frame
        neuralWindow.setFrameOrigin(Self.connectomeHUDOrigin(
            windowSize: placedFrame.size,
            visibleFrame: visibleFrame
        ))

        neuralView = NeuralMapView(frame: frame, engine: engine, world: world)
        neuralView.autoresizingMask = [.width, .height]
        neuralWindow.contentView = neuralView
    }

    private func configureMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = ""
        statusItem.button?.image = Self.makeStatusIcon()
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "DesktopWorm · 302-neuron connectome"

        let menu = NSMenu()
        let heading = NSMenuItem(title: "DesktopWorm · 302 neurons", action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        behaviorItem = NSMenuItem(title: "Behavior · Forward crawl", action: nil, keyEquivalent: "")
        behaviorItem.isEnabled = false
        menu.addItem(behaviorItem)
        menu.addItem(.separator())

        menu.addItem(item("Show Living Connectome", action: #selector(showNeuralMap), key: "n"))
        menu.addItem(item("Touch Stimulus", action: #selector(touchStimulus), key: "t"))
        menu.addItem(item("Food / Chemical Signal", action: #selector(foodStimulus), key: "f"))
        menu.addItem(item("Move Worm to Cursor", action: #selector(moveToCursor), key: "m"))
        menu.addItem(makeSpeedMenu())
        anatomyItem = item("Show Internal Anatomy", action: #selector(toggleAnatomy), key: "")
        anatomyItem.state = .on
        menu.addItem(anatomyItem)
        pauseItem = item("Pause", action: #selector(togglePause), key: "p")
        menu.addItem(pauseItem)
        menu.addItem(item("Reset Neural State", action: #selector(reset), key: "r"))
        menu.addItem(.separator())
        menu.addItem(item("About the Model", action: #selector(showAbout), key: ""))
        menu.addItem(item("Star DesktopWorm on GitHub…", action: #selector(openRepository), key: ""))
        menu.addItem(item("Follow @apoorvdarshan on X…", action: #selector(openDeveloperOnX), key: ""))
        menu.addItem(item("Quit DesktopWorm", action: #selector(quit), key: "q"))
        statusItem.menu = menu
    }

    private func makeSpeedMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Crawl Speed", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Crawl Speed")
        speedItems = [
            speedItem("Slow · 0.6×", scale: 0.6),
            speedItem("Natural · 1.0×", scale: 1.0),
            speedItem("Fast · 1.5×", scale: 1.5),
        ]
        speedItems.forEach(submenu.addItem)
        parent.submenu = submenu
        return parent
    }

    private func speedItem(_ title: String, scale: Double) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(changeSpeed(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = NSNumber(value: scale)
        item.state = scale == 1.0 ? .on : .off
        return item
    }

    private func item(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func startLoop() {
        previousTick = ProcessInfo.processInfo.systemUptime
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(1.0 / 20.0, max(1.0 / 240.0, now - previousTick))
        previousTick = now
        if paused {
            neuralView.sample()
            return
        }

        let neuralSteps = 3
        for _ in 0..<neuralSteps {
            engine.step(dt: dt / Double(neuralSteps))
        }

        let mouseGlobal = NSEvent.mouseLocation
        let frame = overlayWindow.frame
        let mouseLocal = CGPoint(x: mouseGlobal.x - frame.minX, y: mouseGlobal.y - frame.minY)
        world.update(dt: dt, bounds: wormView.bounds, engine: engine, mouse: mouseLocal)
        behaviorItem.title = "Behavior · \(world.behavior.rawValue)"
        neuralView.sample()
        wormView.needsDisplay = true
        if neuralWindow.isVisible {
            neuralView.needsDisplay = true
        }
    }

    @objc private func showNeuralMap() {
        neuralWindow.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func touchStimulus() {
        world.triggerTouch(engine: engine)
    }

    @objc private func foodStimulus() {
        world.triggerFood(engine: engine)
    }

    @objc private func moveToCursor() {
        let global = NSEvent.mouseLocation
        if !overlayWindow.frame.contains(global),
           let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(global) }) {
            configureOverlay(on: targetScreen)
        }
        let frame = overlayWindow.frame
        world.place(at: CGPoint(x: global.x - frame.minX, y: global.y - frame.minY))
    }

    @objc private func togglePause() {
        paused.toggle()
        world.setPaused(paused)
        pauseItem.title = paused ? "Resume" : "Pause"
        behaviorItem.title = "Behavior · \(world.behavior.rawValue)"
    }

    @objc private func toggleAnatomy() {
        showsAnatomy.toggle()
        wormView.showsAnatomy = showsAnatomy
        anatomyItem.state = showsAnatomy ? .on : .off
        wormView.needsDisplay = true
    }

    @objc private func changeSpeed(_ sender: NSMenuItem) {
        guard let scale = (sender.representedObject as? NSNumber)?.doubleValue else { return }
        world.speedScale = scale
        speedItems.forEach { $0.state = $0 === sender ? .on : .off }
    }

    @objc private func reset() {
        engine.reset()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "DesktopWorm"
        alert.informativeText = """
        A native macOS desktop organism using all 302 neurons and 95 muscles from the OpenWorm c302 C. elegans dataset.

        Scientific boundary: neuron identities and anatomical connections are dataset-derived. Neural equations, uncertain synaptic signs, sensory conversion, behavior selection and body physics are explicit modeling choices. The app does not reproduce measured thoughts, consciousness or a complete biological animal.

        Created by Apoorv Darshan. Concept inspired by DesktopFly by Denis Shiryaev. Connectome data and framework by the OpenWorm c302 contributors, based on the Cook et al. whole-animal connectome.

        Full credits and citations are bundled in CREDITS.md and THIRD_PARTY_NOTICES.md.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func openRepository() {
        NSWorkspace.shared.open(Self.repositoryURL)
    }

    @objc private func openDeveloperOnX() {
        NSWorkspace.shared.open(Self.developerXURL)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
