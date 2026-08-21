import AppKit

private struct ActivitySample {
    let forward: Double
    let reverse: Double
    let dorsal: Double
    let ventral: Double
    let arousal: Double
}

final class NeuralMapView: NSView {
    let engine: NeuralEngine
    let world: WormWorld

    private let normalizedPositions: [CGPoint]
    private let displayEdges: [NeuralEdge]
    private var history: [ActivitySample] = []
    private var lastSampleTime = -1.0
    private(set) var sampleCount = 0

    init(frame: CGRect, engine: NeuralEngine, world: WormWorld) {
        self.engine = engine
        self.world = world
        self.normalizedPositions = NeuralMapView.makeLayout(for: engine.connectome.neurons)
        self.displayEdges = Array(engine.connectome.edges.sorted { $0.weight > $1.weight }.prefix(1_400))
        super.init(frame: frame)
        appearance = NSAppearance(named: .darkAqua)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { true }

    func sample() {
        guard engine.time - lastSampleTime >= 0.045 else { return }
        lastSampleTime = engine.time
        let state = engine.motorState()
        history.append(ActivitySample(
            forward: state.forward,
            reverse: state.reverse,
            dorsal: state.dorsalMuscle,
            ventral: state.ventralMuscle,
            arousal: state.arousal
        ))
        if history.count > 180 {
            history.removeFirst(history.count - 180)
        }
        sampleCount += 1
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        drawBackground(context)

        if bounds.width < 720 || bounds.height < 520 {
            drawCompact(context: context)
            return
        }

        let sidebarWidth = min(300, max(260, bounds.width * 0.27))
        let sidebarX = bounds.maxX - sidebarWidth - 26
        let contentTop = bounds.maxY - 130
        let timelineRect = CGRect(x: 26, y: 28, width: sidebarX - 44, height: 102)
        let graphRect = CGRect(
            x: 26,
            y: 148,
            width: sidebarX - 44,
            height: max(280, contentTop - 148)
        )
        let inspectorRect = CGRect(x: sidebarX, y: 28, width: sidebarWidth, height: contentTop - 28)

        drawHeader()
        drawGraph(in: graphRect, context: context)
        drawTimeline(in: timelineRect, context: context)
        drawInspector(in: inspectorRect)
    }

    private func drawCompact(context: CGContext) {
        drawText(
            "LIVING CONNECTOME",
            at: CGPoint(x: 15, y: bounds.maxY - 32),
            font: .systemFont(ofSize: 15, weight: .bold),
            color: .white
        )
        drawText(
            "302 neurons · OpenWorm c302 data · modeled dynamics",
            at: CGPoint(x: 16, y: bounds.maxY - 49),
            font: .systemFont(ofSize: 8.5, weight: .medium),
            color: NSColor.white.withAlphaComponent(0.48)
        )
        let liveDot = CGRect(x: bounds.maxX - 31, y: bounds.maxY - 30, width: 7, height: 7)
        context.setFillColor(NSColor.systemGreen.withAlphaComponent(0.9).cgColor)
        context.fillEllipse(in: liveDot)
        drawText("LIVE", at: CGPoint(x: bounds.maxX - 62, y: bounds.maxY - 33), font: .monospacedSystemFont(ofSize: 7.5, weight: .semibold), color: .systemGreen)

        let bottomHeight: CGFloat = 38
        let inspectorWidth = min(170, bounds.width * 0.34)
        let graphRect = CGRect(
            x: 12,
            y: bottomHeight + 10,
            width: bounds.width - inspectorWidth - 30,
            height: bounds.height - bottomHeight - 72
        )
        let inspectorRect = CGRect(
            x: graphRect.maxX + 8,
            y: graphRect.minY,
            width: inspectorWidth,
            height: graphRect.height
        )
        let statusRect = CGRect(x: 12, y: 9, width: bounds.width - 24, height: bottomHeight - 5)

        drawCompactGraph(in: graphRect, context: context)
        drawCompactInspector(in: inspectorRect)
        drawCompactStatus(in: statusRect)
    }

    private func drawCompactGraph(in rect: CGRect, context: CGContext) {
        drawCard(rect)
        drawText("FUNCTIONAL FLOW · NOT ANATOMICAL POSITION", at: CGPoint(x: rect.minX + 10, y: rect.maxY - 18), font: .monospacedSystemFont(ofSize: 6.8, weight: .semibold), color: NSColor.white.withAlphaComponent(0.38))

        let inner = CGRect(x: rect.minX + 9, y: rect.minY + 9, width: rect.width - 18, height: rect.height - 34)
        let laneWidth = inner.width / 3
        let colors: [NSColor] = [.systemCyan, .systemPurple, .systemOrange]
        let titles = ["SENS", "INTER", "MOTOR"]
        for index in 0..<3 {
            let lane = CGRect(x: inner.minX + CGFloat(index) * laneWidth + 2, y: inner.minY, width: laneWidth - 4, height: inner.height)
            let path = NSBezierPath(roundedRect: lane, xRadius: 7, yRadius: 7)
            colors[index].withAlphaComponent(0.035).setFill()
            path.fill()
            colors[index].withAlphaComponent(0.09).setStroke()
            path.lineWidth = 0.5
            path.stroke()
            drawText(titles[index], at: CGPoint(x: lane.minX + 5, y: lane.maxY - 13), font: .monospacedSystemFont(ofSize: 6.5, weight: .semibold), color: colors[index].withAlphaComponent(0.68))
        }

        let nodeRect = CGRect(x: inner.minX + 3, y: inner.minY + 4, width: inner.width - 6, height: inner.height - 20)
        let points = normalizedPositions.map {
            CGPoint(x: nodeRect.minX + $0.x * nodeRect.width, y: nodeRect.minY + $0.y * nodeRect.height)
        }
        drawEdges(points: points, context: context, limit: 520)
        drawNodes(points: points, context: context, labelLimit: 3)
    }

    private func drawCompactInspector(in rect: CGRect) {
        drawCard(rect)
        var y = rect.maxY - 19
        drawText("MODELED BEHAVIOR", at: CGPoint(x: rect.minX + 10, y: y), font: .monospacedSystemFont(ofSize: 6.8, weight: .semibold), color: NSColor.white.withAlphaComponent(0.38))
        y -= 20
        drawText(world.behavior.rawValue.uppercased(), at: CGPoint(x: rect.minX + 10, y: y), font: .monospacedSystemFont(ofSize: 10.5, weight: .bold), color: .systemMint)
        y -= 24

        let state = engine.motorState()
        let stats = [
            ("FORWARD", state.forward, NSColor.systemGreen),
            ("REVERSE", state.reverse, NSColor.systemPink),
            ("DORSAL", state.dorsalMuscle, NSColor.systemCyan),
            ("VENTRAL", state.ventralMuscle, NSColor.systemPurple),
        ]
        for (label, value, color) in stats {
            drawText(label, at: CGPoint(x: rect.minX + 10, y: y), font: .monospacedSystemFont(ofSize: 6.8, weight: .medium), color: NSColor.white.withAlphaComponent(0.52))
            drawText("\(Int((value * 100).rounded()))", at: CGPoint(x: rect.maxX - 25, y: y), font: .monospacedSystemFont(ofSize: 7, weight: .semibold), color: color)
            drawBar(value: value, color: color, rect: CGRect(x: rect.minX + 10, y: y - 10, width: rect.width - 20, height: 3.5))
            y -= 25
        }

        y -= 1
        drawText("ACTIVE", at: CGPoint(x: rect.minX + 10, y: y), font: .monospacedSystemFont(ofSize: 6.8, weight: .semibold), color: NSColor.white.withAlphaComponent(0.38))
        y -= 16
        for (neuron, value) in engine.strongestActiveNeurons(limit: 3) {
            drawText(neuron.id, at: CGPoint(x: rect.minX + 10, y: y), font: .monospacedSystemFont(ofSize: 7.5, weight: .semibold), color: color(for: neuron.category))
            drawText("\(Int((value * 100).rounded()))%", at: CGPoint(x: rect.maxX - 29, y: y), font: .monospacedSystemFont(ofSize: 7, weight: .semibold), color: .white)
            y -= 14
        }

        drawText("c302 DATA", at: CGPoint(x: rect.minX + 10, y: rect.minY + 11), font: .monospacedSystemFont(ofSize: 6.5, weight: .semibold), color: .systemGreen)
        drawText("DYNAMICS MODELED", at: CGPoint(x: rect.minX + 64, y: rect.minY + 11), font: .monospacedSystemFont(ofSize: 6.5, weight: .semibold), color: .systemOrange)
    }

    private func drawCompactStatus(in rect: CGRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9)
        NSColor.white.withAlphaComponent(0.04).setFill()
        path.fill()
        drawText("AVB/PVC", at: CGPoint(x: rect.minX + 10, y: rect.minY + 11), font: .monospacedSystemFont(ofSize: 6.7, weight: .semibold), color: .systemGreen)
        drawText("AVA/AVD/AVE/RIM", at: CGPoint(x: rect.minX + 61, y: rect.minY + 11), font: .monospacedSystemFont(ofSize: 6.7, weight: .semibold), color: .systemPink)
        drawText("autonomous repertoire · scientific boundary in expanded view", at: CGPoint(x: rect.maxX - 270, y: rect.minY + 11), font: .systemFont(ofSize: 7.2, weight: .regular), color: NSColor.white.withAlphaComponent(0.36))
    }

    private func drawBackground(_ context: CGContext) {
        let colors = [
            NSColor(calibratedRed: 0.018, green: 0.030, blue: 0.048, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.046, green: 0.025, blue: 0.075, alpha: 1).cgColor,
        ] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: bounds.maxY),
            end: CGPoint(x: bounds.maxX, y: 0),
            options: []
        )

        context.setFillColor(NSColor.white.withAlphaComponent(0.025).cgColor)
        for x in stride(from: 20.0, through: Double(bounds.width), by: 34) {
            for y in stride(from: 18.0, through: Double(bounds.height), by: 34) {
                context.fillEllipse(in: CGRect(x: x, y: y, width: 1.2, height: 1.2))
            }
        }
    }

    private func drawHeader() {
        drawText(
            "LIVING CONNECTOME",
            at: CGPoint(x: 27, y: bounds.maxY - 47),
            font: .systemFont(ofSize: 26, weight: .bold),
            color: .white
        )
        drawText(
            "C. elegans hermaphrodite · all 302 neurons · live connectome-constrained simulation",
            at: CGPoint(x: 29, y: bounds.maxY - 70),
            font: .systemFont(ofSize: 11.5, weight: .medium),
            color: NSColor.white.withAlphaComponent(0.58)
        )

        var x: CGFloat = 28
        x += drawPill("DATA · OPENWORM c302", at: CGPoint(x: x, y: bounds.maxY - 106), color: .systemGreen) + 8
        x += drawPill("302 NEURONS", at: CGPoint(x: x, y: bounds.maxY - 106), color: .systemCyan) + 8
        x += drawPill("5,806 NEURAL EDGES", at: CGPoint(x: x, y: bounds.maxY - 106), color: .systemPurple) + 8
        x += drawPill("DYNAMICS · MODELED", at: CGPoint(x: x, y: bounds.maxY - 106), color: .systemOrange) + 8
        _ = drawPill("LAYOUT · FUNCTIONAL", at: CGPoint(x: x, y: bounds.maxY - 106), color: .systemBlue)
    }

    private func drawGraph(in rect: CGRect, context: CGContext) {
        drawCard(rect)
        drawText(
            "CONNECTOME ACTIVITY FLOW",
            at: CGPoint(x: rect.minX + 17, y: rect.maxY - 28),
            font: .monospacedSystemFont(ofSize: 11, weight: .semibold),
            color: NSColor.white.withAlphaComponent(0.72)
        )
        drawText(
            "functional grouping · node position is not anatomical location",
            at: CGPoint(x: rect.minX + 17, y: rect.maxY - 46),
            font: .systemFont(ofSize: 9.5, weight: .regular),
            color: NSColor.white.withAlphaComponent(0.36)
        )

        let inner = CGRect(x: rect.minX + 16, y: rect.minY + 18, width: rect.width - 32, height: rect.height - 78)
        let laneWidth = inner.width / 3
        let laneColors: [NSColor] = [.systemCyan, .systemPurple, .systemOrange]
        let laneTitles = ["SENSORY", "INTERNEURONS", "MOTOR"]
        for index in 0..<3 {
            let lane = CGRect(x: inner.minX + CGFloat(index) * laneWidth + 3, y: inner.minY, width: laneWidth - 6, height: inner.height)
            let path = NSBezierPath(roundedRect: lane, xRadius: 11, yRadius: 11)
            laneColors[index].withAlphaComponent(0.035).setFill()
            path.fill()
            laneColors[index].withAlphaComponent(0.10).setStroke()
            path.lineWidth = 0.7
            path.stroke()
            drawText(
                laneTitles[index],
                at: CGPoint(x: lane.midX - 34, y: lane.maxY - 20),
                font: .monospacedSystemFont(ofSize: 9.5, weight: .semibold),
                color: laneColors[index].withAlphaComponent(0.72)
            )
        }

        let nodeRect = CGRect(x: inner.minX + 5, y: inner.minY + 9, width: inner.width - 10, height: inner.height - 42)
        let points = normalizedPositions.map {
            CGPoint(x: nodeRect.minX + $0.x * nodeRect.width, y: nodeRect.minY + $0.y * nodeRect.height)
        }
        drawEdges(points: points, context: context)
        drawNodes(points: points, context: context)
    }

    private func drawEdges(points: [CGPoint], context: CGContext, limit: Int = .max) {
        context.saveGState()
        for edge in displayEdges.prefix(limit) {
            let sourceActivity = engine.activity[edge.source]
            let targetActivity = engine.activity[edge.target]
            let active = max(sourceActivity, targetActivity)
            let alpha = min(0.34, 0.012 + active * 0.28)
            let color = edge.kind == "electrical"
                ? NSColor.systemCyan.withAlphaComponent(alpha)
                : (edge.sign < 0
                    ? NSColor.systemPink.withAlphaComponent(alpha)
                    : NSColor.white.withAlphaComponent(alpha))
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(active > 0.34 ? 0.75 : 0.35)
            context.beginPath()
            context.move(to: points[edge.source])
            context.addLine(to: points[edge.target])
            context.strokePath()
        }
        context.restoreGState()
    }

    private func drawNodes(points: [CGPoint], context: CGContext, labelLimit: Int = 7) {
        let topIndices = engine.activity.enumerated()
            .sorted { $0.element > $1.element }
            .prefix(labelLimit)
            .map(\.offset)
        let labeled = Set(topIndices)

        for index in points.indices {
            let activity = engine.activity[index]
            let neuron = engine.connectome.neurons[index]
            let baseColor = color(for: neuron.category)
            let radius = CGFloat(1.8 + activity * 5.4)
            if activity > 0.28 {
                context.setFillColor(baseColor.withAlphaComponent(CGFloat(activity) * 0.16).cgColor)
                context.fillEllipse(in: CGRect(
                    x: points[index].x - radius * 2.5,
                    y: points[index].y - radius * 2.5,
                    width: radius * 5,
                    height: radius * 5
                ))
            }
            context.setFillColor(baseColor.withAlphaComponent(0.32 + activity * 0.68).cgColor)
            context.fillEllipse(in: CGRect(
                x: points[index].x - radius,
                y: points[index].y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            if labeled.contains(index) {
                drawText(
                    neuron.id,
                    at: CGPoint(x: points[index].x + 6, y: points[index].y + (index.isMultiple(of: 2) ? 3 : -11)),
                    font: .monospacedSystemFont(ofSize: 8.5, weight: .semibold),
                    color: baseColor.withAlphaComponent(0.92)
                )
            }
        }
    }

    private func drawTimeline(in rect: CGRect, context: CGContext) {
        drawCard(rect)
        drawText(
            "MOTOR-CIRCUIT HISTORY · ~9 SECONDS",
            at: CGPoint(x: rect.minX + 15, y: rect.maxY - 25),
            font: .monospacedSystemFont(ofSize: 9.5, weight: .semibold),
            color: NSColor.white.withAlphaComponent(0.58)
        )
        drawText("AVB/PVC", at: CGPoint(x: rect.maxX - 205, y: rect.maxY - 25), font: .monospacedSystemFont(ofSize: 8.5, weight: .medium), color: .systemGreen)
        drawText("AVA/AVD/AVE/RIM", at: CGPoint(x: rect.maxX - 150, y: rect.maxY - 25), font: .monospacedSystemFont(ofSize: 8.5, weight: .medium), color: .systemPink)
        drawText("MEAN", at: CGPoint(x: rect.maxX - 50, y: rect.maxY - 25), font: .monospacedSystemFont(ofSize: 8.5, weight: .medium), color: .systemOrange)

        let plot = CGRect(x: rect.minX + 14, y: rect.minY + 13, width: rect.width - 28, height: rect.height - 48)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.055).cgColor)
        context.setLineWidth(0.5)
        for fraction in [0.25, 0.5, 0.75] {
            let y = plot.minY + plot.height * fraction
            context.beginPath()
            context.move(to: CGPoint(x: plot.minX, y: y))
            context.addLine(to: CGPoint(x: plot.maxX, y: y))
            context.strokePath()
        }

        drawTrace(history.map(\.forward), color: .systemGreen, in: plot, context: context)
        drawTrace(history.map(\.reverse), color: .systemPink, in: plot, context: context)
        drawTrace(history.map(\.arousal), color: .systemOrange, in: plot, context: context)
    }

    private func drawTrace(_ values: [Double], color: NSColor, in rect: CGRect, context: CGContext) {
        guard values.count > 1 else { return }
        context.setStrokeColor(color.withAlphaComponent(0.9).cgColor)
        context.setLineWidth(1.35)
        context.beginPath()
        for (index, value) in values.enumerated() {
            let x = rect.minX + CGFloat(index) / CGFloat(max(1, values.count - 1)) * rect.width
            let y = rect.minY + CGFloat(min(1, max(0, value))) * rect.height
            if index == 0 { context.move(to: CGPoint(x: x, y: y)) }
            else { context.addLine(to: CGPoint(x: x, y: y)) }
        }
        context.strokePath()
    }

    private func drawInspector(in rect: CGRect) {
        drawCard(rect)
        var y = rect.maxY - 27
        drawText("CURRENT BEHAVIOR · MODELED", at: CGPoint(x: rect.minX + 16, y: y), font: .monospacedSystemFont(ofSize: 9.5, weight: .semibold), color: NSColor.white.withAlphaComponent(0.48))
        y -= 30
        drawText(world.behavior.rawValue.uppercased(), at: CGPoint(x: rect.minX + 16, y: y), font: .monospacedSystemFont(ofSize: 16, weight: .bold), color: .systemMint)
        y -= 37

        drawText("LIVE CIRCUIT DRIVE", at: CGPoint(x: rect.minX + 16, y: y), font: .monospacedSystemFont(ofSize: 9.5, weight: .semibold), color: NSColor.white.withAlphaComponent(0.48))
        y -= 25
        let state = engine.motorState()
        let stats = [
            ("AVB/PVC forward", state.forward, NSColor.systemGreen),
            ("AVA/AVD/AVE/RIM reverse", state.reverse, NSColor.systemPink),
            ("Dorsal muscles", state.dorsalMuscle, NSColor.systemCyan),
            ("Ventral muscles", state.ventralMuscle, NSColor.systemPurple),
            ("Network mean", state.arousal, NSColor.systemOrange),
        ]
        for (label, value, color) in stats {
            drawText(label, at: CGPoint(x: rect.minX + 16, y: y), font: .systemFont(ofSize: 10.5, weight: .medium), color: NSColor.white.withAlphaComponent(0.68))
            drawText("\(Int((value * 100).rounded()))%", at: CGPoint(x: rect.maxX - 48, y: y), font: .monospacedSystemFont(ofSize: 10, weight: .semibold), color: color)
            drawBar(value: value, color: color, rect: CGRect(x: rect.minX + 16, y: y - 14, width: rect.width - 32, height: 5))
            y -= 34
        }

        y -= 2
        drawText("MOST ACTIVE NEURONS", at: CGPoint(x: rect.minX + 16, y: y), font: .monospacedSystemFont(ofSize: 9.5, weight: .semibold), color: NSColor.white.withAlphaComponent(0.48))
        y -= 24
        for (neuron, value) in engine.strongestActiveNeurons(limit: 6) {
            let transmitter = neuron.transmitters.first?.uppercased() ?? "?"
            let category = neuron.category.rawValue.prefix(3).uppercased()
            drawText(neuron.id, at: CGPoint(x: rect.minX + 16, y: y), font: .monospacedSystemFont(ofSize: 10.5, weight: .semibold), color: color(for: neuron.category))
            drawText("\(category) · \(transmitter)", at: CGPoint(x: rect.minX + 70, y: y), font: .monospacedSystemFont(ofSize: 8.5, weight: .regular), color: NSColor.white.withAlphaComponent(0.46))
            drawText("\(Int((value * 100).rounded()))%", at: CGPoint(x: rect.maxX - 46, y: y), font: .monospacedSystemFont(ofSize: 9.5, weight: .semibold), color: .white)
            y -= 21
        }

        let boundaryRect = CGRect(x: rect.minX + 12, y: rect.minY + 12, width: rect.width - 24, height: 91)
        let boundary = NSBezierPath(roundedRect: boundaryRect, xRadius: 10, yRadius: 10)
        NSColor.systemOrange.withAlphaComponent(0.065).setFill()
        boundary.fill()
        NSColor.systemOrange.withAlphaComponent(0.18).setStroke()
        boundary.lineWidth = 0.7
        boundary.stroke()
        drawText("SCIENTIFIC BOUNDARY", at: CGPoint(x: boundaryRect.minX + 11, y: boundaryRect.maxY - 22), font: .monospacedSystemFont(ofSize: 8.8, weight: .semibold), color: .systemOrange)
        drawMultiline(
            "Anatomical cells and connections: c302 data. Neural equations, signs, behavior selection and body physics: modeled. This is not measured thought or consciousness.",
            in: CGRect(x: boundaryRect.minX + 11, y: boundaryRect.minY + 10, width: boundaryRect.width - 22, height: 52),
            font: .systemFont(ofSize: 9.2, weight: .regular),
            color: NSColor.white.withAlphaComponent(0.54)
        )
    }

    private func drawCard(_ rect: CGRect) {
        let card = NSBezierPath(roundedRect: rect, xRadius: 15, yRadius: 15)
        NSColor.white.withAlphaComponent(0.042).setFill()
        card.fill()
        NSColor.white.withAlphaComponent(0.09).setStroke()
        card.lineWidth = 0.8
        card.stroke()
    }

    private func drawBar(value: Double, color: NSColor, rect: CGRect) {
        let track = NSBezierPath(roundedRect: rect, xRadius: 2.5, yRadius: 2.5)
        NSColor.white.withAlphaComponent(0.08).setFill()
        track.fill()
        let width = max(2, rect.width * CGFloat(min(1, max(0, value))))
        let fill = NSBezierPath(roundedRect: CGRect(x: rect.minX, y: rect.minY, width: width, height: rect.height), xRadius: 2.5, yRadius: 2.5)
        color.withAlphaComponent(0.88).setFill()
        fill.fill()
    }

    @discardableResult
    private func drawPill(_ text: String, at point: CGPoint, color: NSColor) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 8.8, weight: .semibold),
        ]
        let width = ceil((text as NSString).size(withAttributes: attributes).width) + 18
        let rect = CGRect(x: point.x, y: point.y, width: width, height: 23)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        color.withAlphaComponent(0.10).setFill()
        path.fill()
        color.withAlphaComponent(0.20).setStroke()
        path.lineWidth = 0.6
        path.stroke()
        drawText(text, at: CGPoint(x: rect.minX + 9, y: rect.minY + 6), font: .monospacedSystemFont(ofSize: 8.8, weight: .semibold), color: color)
        return width
    }

    private func drawText(_ string: String, at point: CGPoint, font: NSFont, color: NSColor) {
        string.draw(at: point, withAttributes: [.font: font, .foregroundColor: color])
    }

    private func drawMultiline(_ string: String, in rect: CGRect, font: NSFont, color: NSColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 1.5
        string.draw(in: rect, withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ])
    }

    private func color(for category: NeuronCategory) -> NSColor {
        switch category {
        case .sensory: return .systemCyan
        case .interneuron: return .systemPurple
        case .motor: return .systemOrange
        }
    }

    private static func makeLayout(for neurons: [Neuron]) -> [CGPoint] {
        var result = Array(repeating: CGPoint.zero, count: neurons.count)
        for category in NeuronCategory.allCases {
            let members = neurons.indices.filter { neurons[$0].category == category }
            let centerX: CGFloat
            let width: CGFloat
            switch category {
            case .sensory: centerX = 0.12; width = 0.17
            case .interneuron: centerX = 0.50; width = 0.23
            case .motor: centerX = 0.88; width = 0.17
            }
            let columns = max(4, Int(ceil(sqrt(Double(members.count)))))
            let rows = Int(ceil(Double(members.count) / Double(columns)))
            for (offset, index) in members.enumerated() {
                let column = offset % columns
                let row = offset / columns
                let x = centerX + (CGFloat(column) / CGFloat(max(1, columns - 1)) - 0.5) * width
                let baseY = 0.04 + CGFloat(row) / CGFloat(max(1, rows - 1)) * 0.90
                let wave = sin(CGFloat(column) * 1.7 + CGFloat(row) * 0.45) * 0.008
                result[index] = CGPoint(x: x, y: min(0.96, max(0.03, baseY + wave)))
            }
        }
        return result
    }
}
