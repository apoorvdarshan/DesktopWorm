import AppKit

private final class DriveMeterView: NSView {
    var value = 0.0 {
        didSet { needsDisplay = true }
    }
    let color: NSColor

    init(color: NSColor) {
        self.color = color
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 245, height: 7) }

    override func draw(_ dirtyRect: NSRect) {
        let track = NSBezierPath(roundedRect: bounds, xRadius: 3.5, yRadius: 3.5)
        NSColor.white.withAlphaComponent(0.08).setFill()
        track.fill()

        let width = max(3, bounds.width * CGFloat(min(1, max(0, value))))
        let fill = NSBezierPath(
            roundedRect: CGRect(x: 0, y: 0, width: width, height: bounds.height),
            xRadius: 3.5,
            yRadius: 3.5
        )
        color.withAlphaComponent(0.90).setFill()
        fill.fill()
    }
}

final class MovementLabController: NSObject {
    let panel: NSPanel
    var onMotion: ((MotionShowcase) -> Void)?
    var onShowNeuralMap: (() -> Void)?

    private let behaviorLabel = NSTextField(labelWithString: "FORWARD CRAWL")
    private let activeNeuronsLabel = NSTextField(wrappingLabelWithString: "")
    private var meters: [String: DriveMeterView] = [:]
    private var values: [String: NSTextField] = [:]
    private(set) var motionButtonCount = 0

    override init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 570, height: 760),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()
        configurePanel()
    }

    func show() {
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func update(behavior: WormBehavior, motor: MotorState, active: [(Neuron, Double)]) {
        behaviorLabel.stringValue = behavior.rawValue.uppercased()
        setMeter("forward", value: motor.forward)
        setMeter("reverse", value: motor.reverse)
        setMeter("dorsal", value: motor.dorsalMuscle)
        setMeter("ventral", value: motor.ventralMuscle)
        setMeter("arousal", value: motor.arousal)
        activeNeuronsLabel.stringValue = active.map {
            "\($0.0.id)  \(Int(($0.1 * 100).rounded()))%"
        }.joined(separator: "   •   ")
    }

    private func configurePanel() {
        panel.title = "DesktopWorm · Movement Lab"
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 520, height: 700)

        let root = NSVisualEffectView()
        root.material = .hudWindow
        root.appearance = NSAppearance(named: .darkAqua)
        root.blendingMode = .behindWindow
        root.state = .active
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(calibratedRed: 0.025, green: 0.035, blue: 0.052, alpha: 0.92).cgColor
        panel.contentView = root

        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 15
        content.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 22),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -22),
            content.topAnchor.constraint(equalTo: root.topAnchor, constant: 48),
            content.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -20),
        ])

        let eyebrow = label("LIVE CONNECTOME · MOVEMENT LAB", size: 11, weight: .semibold, color: .systemMint)
        eyebrow.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        content.addArrangedSubview(eyebrow)

        let title = label("DesktopWorm", size: 27, weight: .bold, color: .labelColor)
        content.addArrangedSubview(title)

        let truthRow = NSStackView(views: [
            pill("ANATOMY · OPENWORM c302", color: .systemGreen),
            pill("DYNAMICS · MODELED", color: .systemOrange),
            pill("BODY · MODELED", color: .systemBlue),
        ])
        truthRow.orientation = .horizontal
        truthRow.spacing = 7
        content.addArrangedSubview(truthRow)

        let stateCard = card()
        content.addArrangedSubview(stateCard)
        let stateStack = NSStackView()
        stateStack.orientation = .vertical
        stateStack.alignment = .leading
        stateStack.spacing = 5
        stateStack.translatesAutoresizingMaskIntoConstraints = false
        stateCard.addSubview(stateStack)
        NSLayoutConstraint.activate([
            stateCard.widthAnchor.constraint(equalTo: content.widthAnchor),
            stateStack.leadingAnchor.constraint(equalTo: stateCard.leadingAnchor, constant: 15),
            stateStack.trailingAnchor.constraint(equalTo: stateCard.trailingAnchor, constant: -15),
            stateStack.topAnchor.constraint(equalTo: stateCard.topAnchor, constant: 12),
            stateStack.bottomAnchor.constraint(equalTo: stateCard.bottomAnchor, constant: -12),
        ])
        stateStack.addArrangedSubview(label("CURRENT MODELED BEHAVIOR", size: 10, weight: .semibold, color: .secondaryLabelColor))
        behaviorLabel.font = .monospacedSystemFont(ofSize: 17, weight: .bold)
        behaviorLabel.textColor = .systemMint
        stateStack.addArrangedSubview(behaviorLabel)

        content.addArrangedSubview(sectionTitle("MOVEMENT REPERTOIRE"))
        let motionGrid = makeMotionGrid()
        content.addArrangedSubview(motionGrid)
        motionGrid.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true

        content.addArrangedSubview(sectionTitle("LIVE MOTOR-CIRCUIT DRIVE"))
        let meterStack = NSStackView()
        meterStack.orientation = .vertical
        meterStack.alignment = .leading
        meterStack.spacing = 7
        meterStack.addArrangedSubview(metricRow("AVB/PVC forward", key: "forward", color: .systemGreen))
        meterStack.addArrangedSubview(metricRow("AVA/AVD/AVE/RIM reverse", key: "reverse", color: .systemPink))
        meterStack.addArrangedSubview(metricRow("Dorsal muscles", key: "dorsal", color: .systemCyan))
        meterStack.addArrangedSubview(metricRow("Ventral muscles", key: "ventral", color: .systemPurple))
        meterStack.addArrangedSubview(metricRow("Network mean", key: "arousal", color: .systemOrange))
        content.addArrangedSubview(meterStack)
        meterStack.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true

        content.addArrangedSubview(sectionTitle("MOST ACTIVE NEURONS"))
        activeNeuronsLabel.font = .monospacedSystemFont(ofSize: 10.5, weight: .medium)
        activeNeuronsLabel.textColor = .secondaryLabelColor
        activeNeuronsLabel.maximumNumberOfLines = 2
        content.addArrangedSubview(activeNeuronsLabel)

        let disclosure = label(
            "Scientific boundary: cell identities and anatomical connections come from OpenWorm c302. Neural equations, uncertain synaptic signs, behavior selection, sensory conversion and 2D body mechanics are explicit simulation choices—not measured thoughts or consciousness.",
            size: 10.5,
            weight: .regular,
            color: .tertiaryLabelColor
        )
        disclosure.maximumNumberOfLines = 4
        disclosure.preferredMaxLayoutWidth = 520
        content.addArrangedSubview(disclosure)

        panel.center()
    }

    private func makeMotionGrid() -> NSGridView {
        var rows: [[NSView]] = []
        let motions = MotionShowcase.allCases
        for start in stride(from: 0, to: motions.count, by: 3) {
            var row: [NSView] = []
            for offset in 0..<3 {
                let index = start + offset
                if index < motions.count {
                    row.append(motionButton(motions[index]))
                } else {
                    row.append(NSView())
                }
            }
            rows.append(row)
        }

        let neuralButton = NSButton(title: "Open neural map", target: self, action: #selector(showNeuralMap))
        styleButton(neuralButton, accent: .systemMint)
        if var final = rows.popLast() {
            if let emptyIndex = final.firstIndex(where: { type(of: $0) == NSView.self }) {
                final[emptyIndex] = neuralButton
                rows.append(final)
            } else {
                rows.append(final)
                rows.append([neuralButton, NSView(), NSView()])
            }
        }

        let grid = NSGridView(views: rows)
        grid.rowSpacing = 8
        grid.columnSpacing = 8
        for column in 0..<3 {
            grid.column(at: column).xPlacement = .fill
        }
        for row in rows {
            row[1].widthAnchor.constraint(equalTo: row[0].widthAnchor).isActive = true
            row[2].widthAnchor.constraint(equalTo: row[0].widthAnchor).isActive = true
        }
        return grid
    }

    private func motionButton(_ motion: MotionShowcase) -> NSButton {
        motionButtonCount += 1
        let button = NSButton(title: motion.title, target: self, action: #selector(performMotion(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(motion.rawValue)
        button.toolTip = motion.help
        styleButton(button, accent: motion == .touchEscape ? .systemPink : .labelColor)
        return button
    }

    private func styleButton(_ button: NSButton, accent: NSColor) {
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 11.5, weight: .medium)
        button.contentTintColor = accent
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
    }

    private func metricRow(_ title: String, key: String, color: NSColor) -> NSView {
        let name = label(title, size: 10.5, weight: .medium, color: .secondaryLabelColor)
        name.widthAnchor.constraint(equalToConstant: 175).isActive = true

        let meter = DriveMeterView(color: color)
        meter.widthAnchor.constraint(greaterThanOrEqualToConstant: 245).isActive = true
        meters[key] = meter

        let value = label("0%", size: 10.5, weight: .semibold, color: color)
        value.alignment = .right
        value.widthAnchor.constraint(equalToConstant: 38).isActive = true
        values[key] = value

        let row = NSStackView(views: [name, meter, value])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    private func setMeter(_ key: String, value: Double) {
        let clamped = min(1, max(0, value))
        meters[key]?.value = clamped
        values[key]?.stringValue = "\(Int((clamped * 100).rounded()))%"
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        return label
    }

    private func sectionTitle(_ text: String) -> NSTextField {
        let result = label(text, size: 10, weight: .semibold, color: .tertiaryLabelColor)
        result.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
        return result
    }

    private func pill(_ text: String, color: NSColor) -> NSTextField {
        let result = NSTextField(labelWithString: "  \(text)  ")
        result.font = .monospacedSystemFont(ofSize: 9, weight: .semibold)
        result.textColor = color
        result.wantsLayer = true
        result.layer?.backgroundColor = color.withAlphaComponent(0.10).cgColor
        result.layer?.cornerRadius = 5
        result.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return result
    }

    private func card() -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.055).cgColor
        view.layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor
        view.layer?.borderWidth = 1
        view.layer?.cornerRadius = 12
        return view
    }

    @objc private func performMotion(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue,
              let motion = MotionShowcase(rawValue: rawValue) else { return }
        onMotion?(motion)
    }

    @objc private func showNeuralMap() {
        onShowNeuralMap?()
    }
}
