import AppKit

final class NeuralMapView: NSView {
    let engine: NeuralEngine
    private let normalizedPositions: [CGPoint]
    private let displayEdges: [NeuralEdge]

    init(frame: CGRect, engine: NeuralEngine) {
        self.engine = engine
        self.normalizedPositions = NeuralMapView.makeLayout(for: engine.connectome.neurons)
        self.displayEdges = Array(engine.connectome.edges.sorted { $0.weight > $1.weight }.prefix(1_050))
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        drawBackground(context)

        let graphRect = CGRect(x: 34, y: 54, width: max(300, bounds.width - 290), height: max(260, bounds.height - 170))
        let points = normalizedPositions.map {
            CGPoint(x: graphRect.minX + $0.x * graphRect.width, y: graphRect.minY + $0.y * graphRect.height)
        }

        drawHeader()
        drawColumnLabels(in: graphRect)
        drawEdges(points: points, context: context)
        drawNodes(points: points, context: context)
        drawInspector(in: CGRect(x: bounds.width - 236, y: 42, width: 208, height: bounds.height - 92))
    }

    private func drawBackground(_ context: CGContext) {
        let colors = [
            NSColor(calibratedRed: 0.025, green: 0.045, blue: 0.065, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.055, green: 0.035, blue: 0.095, alpha: 1).cgColor,
        ] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: bounds.maxY),
            end: CGPoint(x: bounds.maxX, y: 0),
            options: []
        )
    }

    private func drawHeader() {
        drawText(
            "C. ELEGANS · COMPLETE CONNECTOME",
            at: CGPoint(x: 30, y: bounds.height - 42),
            font: .monospacedSystemFont(ofSize: 17, weight: .semibold),
            color: NSColor(calibratedRed: 0.63, green: 1, blue: 0.78, alpha: 1)
        )
        drawText(
            "302 neurons  •  live graded-activity model  •  OpenWorm c302",
            at: CGPoint(x: 31, y: bounds.height - 64),
            font: .systemFont(ofSize: 12, weight: .regular),
            color: .secondaryLabelColor
        )
    }

    private func drawColumnLabels(in rect: CGRect) {
        let labels: [(String, CGFloat, NSColor)] = [
            ("SENSORY", 0.10, .systemCyan),
            ("INTERNEURONS", 0.50, .systemPurple),
            ("MOTOR", 0.90, .systemOrange),
        ]
        for (label, x, color) in labels {
            drawText(
                label,
                at: CGPoint(x: rect.minX + rect.width * x - 36, y: rect.maxY + 10),
                font: .monospacedSystemFont(ofSize: 10, weight: .medium),
                color: color.withAlphaComponent(0.82)
            )
        }
    }

    private func drawEdges(points: [CGPoint], context: CGContext) {
        context.saveGState()
        context.setLineWidth(0.45)
        for edge in displayEdges {
            let sourceActivity = engine.activity[edge.source]
            let alpha = min(0.23, 0.018 + sourceActivity * 0.20)
            let color = edge.kind == "electrical"
                ? NSColor.systemCyan.withAlphaComponent(alpha)
                : (edge.sign < 0
                    ? NSColor.systemPink.withAlphaComponent(alpha)
                    : NSColor.white.withAlphaComponent(alpha))
            context.setStrokeColor(color.cgColor)
            context.beginPath()
            context.move(to: points[edge.source])
            context.addLine(to: points[edge.target])
            context.strokePath()
        }
        context.restoreGState()
    }

    private func drawNodes(points: [CGPoint], context: CGContext) {
        for index in points.indices {
            let activity = engine.activity[index]
            let neuron = engine.connectome.neurons[index]
            let baseColor: NSColor
            switch neuron.category {
            case .sensory: baseColor = .systemCyan
            case .interneuron: baseColor = .systemPurple
            case .motor: baseColor = .systemOrange
            }
            let radius = CGFloat(1.7 + activity * 5.2)
            if activity > 0.42 {
                context.setFillColor(baseColor.withAlphaComponent(CGFloat(activity) * 0.18).cgColor)
                context.fillEllipse(in: CGRect(
                    x: points[index].x - radius * 2.4,
                    y: points[index].y - radius * 2.4,
                    width: radius * 4.8,
                    height: radius * 4.8
                ))
            }
            context.setFillColor(baseColor.withAlphaComponent(0.35 + activity * 0.65).cgColor)
            context.fillEllipse(in: CGRect(
                x: points[index].x - radius,
                y: points[index].y - radius,
                width: radius * 2,
                height: radius * 2
            ))
        }
    }

    private func drawInspector(in rect: CGRect) {
        let panel = NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16)
        NSColor.white.withAlphaComponent(0.055).setFill()
        panel.fill()
        NSColor.white.withAlphaComponent(0.10).setStroke()
        panel.lineWidth = 1
        panel.stroke()

        var y = rect.maxY - 30
        drawText("LIVE ACTIVITY", at: CGPoint(x: rect.minX + 17, y: y), font: .monospacedSystemFont(ofSize: 11, weight: .semibold), color: .systemGreen)
        y -= 28

        let state = engine.motorState()
        let stats = [
            ("Forward", state.forward, NSColor.systemGreen),
            ("Reverse", state.reverse, NSColor.systemPink),
            ("Dorsal muscle", state.dorsalMuscle, NSColor.systemCyan),
            ("Ventral muscle", state.ventralMuscle, NSColor.systemPurple),
            ("Network arousal", state.arousal, NSColor.systemOrange),
        ]
        for (label, value, color) in stats {
            drawText(label, at: CGPoint(x: rect.minX + 17, y: y), font: .systemFont(ofSize: 11), color: .secondaryLabelColor)
            drawBar(value: value, color: color, rect: CGRect(x: rect.minX + 17, y: y - 15, width: rect.width - 34, height: 5))
            y -= 38
        }

        y -= 4
        drawText("MOST ACTIVE", at: CGPoint(x: rect.minX + 17, y: y), font: .monospacedSystemFont(ofSize: 10, weight: .semibold), color: .tertiaryLabelColor)
        y -= 22
        for (neuron, value) in engine.strongestActiveNeurons(limit: 7) {
            let role = neuron.category.rawValue.prefix(3).uppercased()
            drawText(
                String(format: "%-5@  %-4@  %3.0f%%", neuron.id as NSString, role as NSString, value * 100),
                at: CGPoint(x: rect.minX + 17, y: y),
                font: .monospacedSystemFont(ofSize: 10, weight: .regular),
                color: .labelColor
            )
            y -= 19
        }

        drawText(
            "Solid: chemical  ·  Cyan: electrical\nPink: inhibitory GABA source",
            at: CGPoint(x: rect.minX + 17, y: rect.minY + 22),
            font: .systemFont(ofSize: 9.5),
            color: .tertiaryLabelColor
        )
    }

    private func drawBar(value: Double, color: NSColor, rect: CGRect) {
        let background = NSBezierPath(roundedRect: rect, xRadius: 2.5, yRadius: 2.5)
        NSColor.white.withAlphaComponent(0.08).setFill()
        background.fill()

        let clamped = CGFloat(min(1, max(0, value)))
        let fill = NSBezierPath(roundedRect: CGRect(x: rect.minX, y: rect.minY, width: max(2, rect.width * clamped), height: rect.height), xRadius: 2.5, yRadius: 2.5)
        color.withAlphaComponent(0.85).setFill()
        fill.fill()
    }

    private func drawText(_ string: String, at point: CGPoint, font: NSFont, color: NSColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        string.draw(
            at: point,
            withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph,
            ]
        )
    }

    private static func makeLayout(for neurons: [Neuron]) -> [CGPoint] {
        var result = Array(repeating: CGPoint.zero, count: neurons.count)
        for category in NeuronCategory.allCases {
            let members = neurons.indices.filter { neurons[$0].category == category }
            let centerX: CGFloat
            let width: CGFloat
            switch category {
            case .sensory: centerX = 0.12; width = 0.18
            case .interneuron: centerX = 0.50; width = 0.24
            case .motor: centerX = 0.88; width = 0.18
            }
            let columns = max(3, Int(ceil(sqrt(Double(members.count)))))
            let rows = Int(ceil(Double(members.count) / Double(columns)))
            for (offset, index) in members.enumerated() {
                let column = offset % columns
                let row = offset / columns
                let x = centerX + (CGFloat(column) / CGFloat(max(1, columns - 1)) - 0.5) * width
                let y = 0.06 + CGFloat(row) / CGFloat(max(1, rows - 1)) * 0.88
                result[index] = CGPoint(x: x, y: y)
            }
        }
        return result
    }
}
