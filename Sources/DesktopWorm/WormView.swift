import AppKit

final class WormWorld {
    private(set) var head = CGPoint(x: 500, y: 400)
    private(set) var heading = Double.pi * 0.15
    private(set) var phase = 0.0
    private(set) var speed = 42.0
    private(set) var isReversing = false
    private(set) var lastMotor = MotorState(
        forward: 0, reverse: 0, left: 0, right: 0,
        dorsalMuscle: 0, ventralMuscle: 0, arousal: 0
    )

    private var reverseRemaining = 0.0
    private var turnImpulse = 0.0
    private var lastMouse: CGPoint?
    private var foodPulseClock = 0.0

    func place(at point: CGPoint) {
        head = point
    }

    func triggerTouch(engine: NeuralEngine) {
        engine.stimulateTouch(1.25)
        reverseRemaining = 1.25
        turnImpulse = Bool.random() ? 1.0 : -1.0
    }

    func update(dt: Double, bounds: CGRect, engine: NeuralEngine, mouse: CGPoint) {
        lastMotor = engine.motorState()
        let mouseVelocity: Double
        if let previous = lastMouse {
            mouseVelocity = hypot(mouse.x - previous.x, mouse.y - previous.y) / max(dt, 0.001)
        } else {
            mouseVelocity = 0
        }
        lastMouse = mouse

        let distanceToMouse = hypot(mouse.x - head.x, mouse.y - head.y)
        if distanceToMouse < 105 && mouseVelocity > 180 && reverseRemaining <= 0.1 {
            triggerTouch(engine: engine)
        }

        foodPulseClock -= dt
        if distanceToMouse > 145 && distanceToMouse < 650 && foodPulseClock <= 0 {
            engine.stimulateFood(0.34)
            foodPulseClock = 0.18
        }

        if reverseRemaining > 0 {
            reverseRemaining -= dt
            isReversing = true
        } else {
            if isReversing {
                turnImpulse = Bool.random() ? 1.0 : -1.0
            }
            isReversing = false
        }

        let neuralForward = max(0.12, lastMotor.forward)
        let neuralReverse = lastMotor.reverse
        speed += ((34 + neuralForward * 56 + lastMotor.arousal * 18) - speed) * min(1, dt * 2.8)

        let neuralTurn = (lastMotor.right - lastMotor.left) * 1.6
        var angularVelocity = neuralTurn + 0.24 * sin(phase * 0.19)

        if !isReversing && distanceToMouse > 145 && distanceToMouse < 650 {
            let desired = atan2(mouse.y - head.y, mouse.x - head.x)
            angularVelocity += wrappedAngle(desired - heading) * (0.22 + lastMotor.forward * 0.12)
        }
        if abs(turnImpulse) > 0.01 {
            angularVelocity += turnImpulse * 2.25
            turnImpulse *= exp(-dt * 2.2)
        }

        heading += angularVelocity * dt
        let movementSign = isReversing || neuralReverse > neuralForward * 1.9 ? -0.72 : 1.0
        head.x += cos(heading) * speed * movementSign * dt
        head.y += sin(heading) * speed * movementSign * dt

        let activityTempo = 1.0 + lastMotor.arousal * 2.2
        phase += dt * speed * 0.11 * activityTempo * movementSign

        let margin: CGFloat = 95
        if head.x < bounds.minX + margin {
            head.x = bounds.minX + margin
            heading = Double.pi - heading
            turnImpulse = 0.65
        } else if head.x > bounds.maxX - margin {
            head.x = bounds.maxX - margin
            heading = Double.pi - heading
            turnImpulse = -0.65
        }
        if head.y < bounds.minY + margin {
            head.y = bounds.minY + margin
            heading = -heading
            turnImpulse = -0.65
        } else if head.y > bounds.maxY - margin {
            head.y = bounds.maxY - margin
            heading = -heading
            turnImpulse = 0.65
        }
    }

    func bodyPoints(count: Int = 34) -> [CGPoint] {
        let dorsalBalance = lastMotor.dorsalMuscle - lastMotor.ventralMuscle
        let amplitude = 11.0 + min(8.0, abs(dorsalBalance) * 18.0) + lastMotor.arousal * 5.0
        let perpendicular = CGVector(dx: -sin(heading), dy: cos(heading))
        let backwards = CGVector(dx: -cos(heading), dy: -sin(heading))

        return (0..<count).map { index in
            let t = Double(index) / Double(max(1, count - 1))
            let along = Double(index) * 5.2
            let wave = sin(phase - Double(index) * 0.52) * amplitude * pow(t, 0.62)
            return CGPoint(
                x: head.x + backwards.dx * along + perpendicular.dx * wave,
                y: head.y + backwards.dy * along + perpendicular.dy * wave
            )
        }
    }

    private func wrappedAngle(_ angle: Double) -> Double {
        var value = angle
        while value > .pi { value -= 2 * .pi }
        while value < -.pi { value += 2 * .pi }
        return value
    }
}

final class WormView: NSView {
    let world: WormWorld
    let engine: NeuralEngine

    init(frame: CGRect, world: WormWorld, engine: NeuralEngine) {
        self.world = world
        self.engine = engine
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let points = world.bodyPoints()

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -5), blur: 11, color: NSColor.black.withAlphaComponent(0.48).cgColor)
        strokeBody(points: points, context: context, outer: true)
        context.restoreGState()

        strokeBody(points: points, context: context, outer: false)
        drawHead(at: points[0], toward: points[1], context: context)
        drawNeuralGlow(at: points[0], context: context)
    }

    private func strokeBody(points: [CGPoint], context: CGContext, outer: Bool) {
        for index in 0..<(points.count - 1) {
            let progress = CGFloat(index) / CGFloat(points.count - 1)
            let taper = max(0.20, 1.0 - pow(progress, 1.7))
            let width: CGFloat = outer ? 17 * taper + 2 : 11 * taper + 1
            let hueShift = CGFloat(sin(Double(index) * 0.55 + world.phase) * 0.04)
            let color: NSColor
            if outer {
                color = NSColor(calibratedRed: 0.08, green: 0.20, blue: 0.12, alpha: 0.82)
            } else {
                color = NSColor(
                    calibratedRed: 0.42 + hueShift,
                    green: 0.91,
                    blue: 0.55 + hueShift,
                    alpha: 0.94
                )
            }
            context.setStrokeColor(color.cgColor)
            context.setLineCap(.round)
            context.setLineWidth(width)
            context.beginPath()
            context.move(to: points[index])
            context.addLine(to: points[index + 1])
            context.strokePath()
        }

        context.setStrokeColor(NSColor.white.withAlphaComponent(outer ? 0 : 0.36).cgColor)
        context.setLineWidth(1.35)
        context.setLineCap(.round)
        context.beginPath()
        context.addLines(between: points)
        context.strokePath()
    }

    private func drawHead(at head: CGPoint, toward neck: CGPoint, context: CGContext) {
        let angle = atan2(head.y - neck.y, head.x - neck.x)
        context.saveGState()
        context.translateBy(x: head.x, y: head.y)
        context.rotate(by: angle)

        let headRect = CGRect(x: -8, y: -7, width: 19, height: 14)
        context.setFillColor(NSColor(calibratedRed: 0.62, green: 1.0, blue: 0.72, alpha: 0.95).cgColor)
        context.fillEllipse(in: headRect)

        context.setFillColor(NSColor(calibratedRed: 0.15, green: 0.55, blue: 0.30, alpha: 0.82).cgColor)
        context.fillEllipse(in: CGRect(x: 2.5, y: -4, width: 6, height: 8))

        context.setStrokeColor(NSColor(calibratedRed: 0.62, green: 1, blue: 0.8, alpha: 0.65).cgColor)
        context.setLineWidth(1)
        for offset in [-4.0, 4.0] {
            context.beginPath()
            context.move(to: CGPoint(x: 7, y: offset * 0.55))
            context.addLine(to: CGPoint(x: 15, y: offset))
            context.strokePath()
        }
        context.restoreGState()
    }

    private func drawNeuralGlow(at head: CGPoint, context: CGContext) {
        let arousal = engine.motorState().arousal
        let radius = CGFloat(9 + arousal * 18)
        let colors = [
            NSColor.systemCyan.withAlphaComponent(0.28).cgColor,
            NSColor.systemGreen.withAlphaComponent(0).cgColor,
        ] as CFArray
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 1]
        ) else { return }
        context.drawRadialGradient(
            gradient,
            startCenter: head,
            startRadius: 0,
            endCenter: head,
            endRadius: radius,
            options: []
        )
    }
}
