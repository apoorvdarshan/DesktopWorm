import AppKit

enum WormBehavior: String, Hashable {
    case forwardCrawl = "Forward crawl"
    case roaming = "Roaming"
    case localSearch = "Local search"
    case pirouette = "Pirouette"
    case reverseEscape = "Touch reverse"
    case sensoryPause = "Sensing cursor"
    case headSweep = "Head sweep"
    case shallowTurn = "Shallow turn"
    case deepTurn = "Deep turn"
    case approachCrawl = "Slow approach"
    case dwelling = "Dwelling"
    case omegaTurn = "Omega turn"
    case collisionRecovery = "Collision recovery"
    case paused = "Paused"
}

final class WormWorld {
    private static let pointCount = 40
    private static let segmentLength = 4.55

    private(set) var head = CGPoint(x: 500, y: 400)
    private(set) var heading = Double.pi * 0.15
    private(set) var phase = 0.0
    private(set) var speed = 0.0
    private(set) var behavior: WormBehavior = .forwardCrawl
    private(set) var points: [CGPoint] = []
    private(set) var lastMotor = MotorState(
        forward: 0, reverse: 0, left: 0, right: 0,
        dorsalMuscle: 0, ventralMuscle: 0, arousal: 0
    )

    var speedScale = 1.0

    private var behaviorClock = 0.0
    private var behaviorRemaining = 0.0
    private var turnDirection = 1.0
    private var lastMouse: CGPoint?
    private var foodPulseClock = 0.0
    private var spontaneousClock = 0.0
    private var cursorEngagementCooldown = 0.0
    private var chemotaxisTarget: CGPoint?
    private var targetNeedsDeepTurn = false
    private var pausedBehavior: WormBehavior?
    private var spontaneousIndex = 0
    private var pointVelocities: [CGVector] = []
    private var gaitAmplitude = 0.30
    private var gaitFrequency = 0.90
    private var gaitOmegaBias = 0.0
    private var gaitTravelDirection = 1.0

    init() {
        rebuildBody()
    }

    func place(at point: CGPoint, heading newHeading: Double? = nil) {
        head = point
        if let newHeading {
            heading = newHeading
        }
        rebuildBody()
    }

    func triggerTouch(engine: NeuralEngine) {
        engine.stimulateTouch(1.25)
        chemotaxisTarget = nil
        cursorEngagementCooldown = 2.0
        turnDirection *= -1
        enter(.reverseEscape, for: 1.15)
    }

    func triggerFood(engine: NeuralEngine) {
        engine.stimulateFood(1.4)
        chemotaxisTarget = nil
        cursorEngagementCooldown = 5.5
        enter(.sensoryPause, for: 0.36)
    }

    func setPaused(_ paused: Bool) {
        if paused, behavior != .paused {
            pausedBehavior = behavior
            behavior = .paused
            speed = 0
        } else if !paused, behavior == .paused {
            behavior = pausedBehavior ?? .forwardCrawl
            pausedBehavior = nil
        }
    }

    func update(dt: Double, bounds: CGRect, engine: NeuralEngine, mouse: CGPoint) {
        guard dt > 0, behavior != .paused else { return }
        lastMotor = engine.motorState()
        behaviorClock += dt
        spontaneousClock += dt
        cursorEngagementCooldown = max(0, cursorEngagementCooldown - dt)

        let mouseVelocity: Double
        if let previous = lastMouse {
            mouseVelocity = hypot(mouse.x - previous.x, mouse.y - previous.y) / max(dt, 0.001)
        } else {
            mouseVelocity = 0
        }
        lastMouse = mouse

        let distanceToMouse = hypot(mouse.x - head.x, mouse.y - head.y)
        if distanceToMouse < 95, mouseVelocity > 190, behavior != .reverseEscape {
            triggerTouch(engine: engine)
        }

        if behavior == .sensoryPause, chemotaxisTarget == nil {
            beginChemotaxis(toward: mouse)
        } else if behavior == .forwardCrawl,
                  cursorEngagementCooldown <= 0,
                  distanceToMouse > 115,
                  distanceToMouse < 470,
                  mouseVelocity < 850 {
            beginChemotaxis(toward: mouse)
            enter(.sensoryPause, for: 0.36)
            cursorEngagementCooldown = 4.8
        }

        foodPulseClock -= dt
        if distanceToMouse > 130, distanceToMouse < 600, foodPulseClock <= 0 {
            engine.stimulateFood(0.30)
            foodPulseClock = 0.22
        }

        advanceBehavior(dt: dt)
        let profile = movementProfile()

        let imbalance = lastMotor.dorsalMuscle - lastMotor.ventralMuscle
        let neuralBend = min(0.11, abs(imbalance) * 0.22)
        let locomotorDrive = profile.travelDirection < 0 ? lastMotor.reverse : lastMotor.forward
        let neuralGain = clamped(0.72 + locomotorDrive * 2.0, 0.72, 1.25)
        let targetAmplitude = profile.amplitude * neuralGain * (1 + lastMotor.arousal * 0.8) + neuralBend
        let targetFrequency = profile.frequency * (0.84 + locomotorDrive * 0.9 + lastMotor.arousal * 0.7)
        let gaitBlend = 1 - exp(-dt * 4.6)
        gaitAmplitude += (targetAmplitude - gaitAmplitude) * gaitBlend
        gaitFrequency += (targetFrequency - gaitFrequency) * gaitBlend
        gaitOmegaBias += (profile.omegaBias - gaitOmegaBias) * (1 - exp(-dt * 5.8))
        gaitTravelDirection += (profile.travelDirection - gaitTravelDirection) * (1 - exp(-dt * 6.4))
        phase += dt * 2 * .pi * gaitFrequency * profile.waveDirection

        let neuralTurn = clamped((lastMotor.right - lastMotor.left) * 1.5, -0.42, 0.42)
        let headSweepGain: Double
        switch behavior {
        case .headSweep, .sensoryPause: headSweepGain = 1.35
        case .localSearch, .dwelling: headSweepGain = 0.85
        case .shallowTurn, .deepTurn, .omegaTurn, .pirouette: headSweepGain = 0.55
        default: headSweepGain = 0.22
        }
        let waveSteer = cos(phase + 0.28) * gaitAmplitude * gaitFrequency * (0.10 + headSweepGain * 0.28)
        heading += (profile.turnRate + neuralTurn + waveSteer) * dt

        // Propulsion is generated from body-wave power. With no bend or
        // oscillation, traction is zero and the worm cannot slide.
        let wavePower = clamped(gaitAmplitude * gaitFrequency / 0.56, 0, 1)
        let strokeTraction = 0.34 + 0.66 * pow(abs(cos(phase - 0.35)), 0.72)
        let targetSpeed = gaitTravelDirection * speedScale * profile.maxSpeed * wavePower * strokeTraction
        speed += (targetSpeed - speed) * min(1, dt * 3.9)
        let lateralVelocity = sin(phase) * gaitAmplitude * (3.8 + headSweepGain * 9.5)
        let tangentX = cos(heading)
        let tangentY = sin(heading)
        head.x += (tangentX * speed - tangentY * lateralVelocity) * dt
        head.y += (tangentY * speed + tangentX * lateralVelocity) * dt

        var collided = false
        let margin: CGFloat = 100
        if head.x < bounds.minX + margin {
            head.x = bounds.minX + margin
            collided = true
            turnDirection = 1
        } else if head.x > bounds.maxX - margin {
            head.x = bounds.maxX - margin
            collided = true
            turnDirection = -1
        }
        if head.y < bounds.minY + margin {
            head.y = bounds.minY + margin
            collided = true
            turnDirection = head.x < bounds.midX ? -1 : 1
        } else if head.y > bounds.maxY - margin {
            head.y = bounds.maxY - margin
            collided = true
            turnDirection = head.x < bounds.midX ? 1 : -1
        }
        if collided, behavior != .collisionRecovery {
            enter(.collisionRecovery, for: 0.72)
        }

        if behavior == .approachCrawl,
           let target = chemotaxisTarget,
           hypot(target.x - head.x, target.y - head.y) < 72 {
            enter(.dwelling, for: 0.72)
        }

        solveBody(amplitude: gaitAmplitude, omegaBias: gaitOmegaBias, dt: dt, screenBounds: bounds)
        engine.setProprioceptiveState(
            headBend: signedHeadBend(),
            bodyCurvature: bodyWaveEnergy()
        )
    }

    func bodyPoints() -> [CGPoint] {
        points
    }

    func maximumSegmentError() -> Double {
        zip(points, points.dropFirst()).map {
            abs(hypot($1.x - $0.x, $1.y - $0.y) - Self.segmentLength)
        }.max() ?? 0
    }

    func minimumEdgeClearance(in bounds: CGRect) -> Double {
        points.map { point in
            min(
                point.x - bounds.minX,
                bounds.maxX - point.x,
                point.y - bounds.minY,
                bounds.maxY - point.y
            )
        }.min() ?? 0
    }

    func bodyWaveEnergy() -> Double {
        guard points.count > 3 else { return 0 }
        var total = 0.0
        for index in 1..<(points.count - 1) {
            let incoming = atan2(points[index].y - points[index - 1].y, points[index].x - points[index - 1].x)
            let outgoing = atan2(points[index + 1].y - points[index].y, points[index + 1].x - points[index].x)
            total += abs(wrappedAngle(outgoing - incoming))
        }
        return total / Double(points.count - 2)
    }

    func signedHeadBend() -> Double {
        guard points.count > 6 else { return 0 }
        let first = atan2(points[2].y - points[0].y, points[2].x - points[0].x)
        let neck = atan2(points[6].y - points[4].y, points[6].x - points[4].x)
        return wrappedAngle(first - neck)
    }

    private func advanceBehavior(dt: Double) {
        if behaviorRemaining > 0 {
            behaviorRemaining -= dt
            if behaviorRemaining <= 0 {
                switch behavior {
                case .reverseEscape, .collisionRecovery:
                    enter(.omegaTurn, for: 0.82)
                case .sensoryPause:
                    enter(.headSweep, for: 1.12)
                case .headSweep:
                    if chemotaxisTarget != nil {
                        enter(targetNeedsDeepTurn ? .deepTurn : .shallowTurn, for: targetNeedsDeepTurn ? 1.15 : 0.92)
                    } else {
                        enter(.shallowTurn, for: 0.82)
                    }
                case .shallowTurn, .deepTurn:
                    if chemotaxisTarget != nil {
                        enter(.approachCrawl, for: 2.15)
                    } else {
                        enter(.forwardCrawl, for: 0)
                    }
                case .approachCrawl:
                    enter(.dwelling, for: 0.72)
                case .dwelling:
                    chemotaxisTarget = nil
                    enter(.forwardCrawl, for: 0)
                default:
                    enter(.forwardCrawl, for: 0)
                }
            }
            return
        }

        if behavior == .forwardCrawl, spontaneousClock > 3.4 {
            spontaneousClock = 0
            turnDirection *= -1
            let repertoire: [(WormBehavior, Double)] = [
                (.headSweep, 1.30),
                (.roaming, 2.55),
                (.shallowTurn, 1.00),
                (.localSearch, 2.45),
                (.dwelling, 1.85),
                (.pirouette, 2.45),
                (.deepTurn, 1.15),
            ]
            let next = repertoire[spontaneousIndex % repertoire.count]
            spontaneousIndex += 1
            enter(next.0, for: next.1)
        }
    }

    private func movementProfile() -> (
        travelDirection: Double,
        waveDirection: Double,
        amplitude: Double,
        frequency: Double,
        maxSpeed: Double,
        turnRate: Double,
        omegaBias: Double
    ) {
        switch behavior {
        case .forwardCrawl:
            return (1, 1, 0.40, 1.18, 43, 0.09 * sin(behaviorClock * 0.55), 0)
        case .roaming:
            return (1, 1, 0.37, 1.38, 52, 0.12 * sin(behaviorClock * 0.74), 0)
        case .localSearch:
            let alternatingTurn = sin(behaviorClock * 1.8) >= 0 ? 1.0 : -1.0
            return (0.30, 1, 0.52, 0.82, 29, alternatingTurn * 0.88, alternatingTurn * 0.30)
        case .pirouette:
            if behaviorClock < 0.78 {
                return (-0.72, -1, 0.50, 1.42, 46, turnDirection * 0.18, 0)
            } else if behaviorClock < 1.92 {
                return (0.10, 1, 0.62, 0.88, 25, turnDirection * 2.05, turnDirection * 0.82)
            } else {
                return (0.74, 1, 0.45, 1.20, 40, -turnDirection * 0.20, 0)
            }
        case .reverseEscape:
            return (-1, -1, 0.47, 1.48, 48, turnDirection * 0.18, 0)
        case .sensoryPause:
            return (0, 1, 0.09, 0.34, 0, 0, 0)
        case .headSweep:
            return (0.04, 1, 0.39, 0.58, 20, turnDirection * 1.08 * sin(behaviorClock * 4.8), 0)
        case .shallowTurn:
            return (0.22, 1, 0.46, 0.88, 30, turnDirection * 0.72, turnDirection * 0.22)
        case .deepTurn:
            return (0.10, 1, 0.56, 0.78, 25, turnDirection * 1.58, turnDirection * 0.62)
        case .approachCrawl:
            let target = chemotaxisTarget ?? head
            let desired = atan2(target.y - head.y, target.x - head.x)
            let error = wrappedAngle(desired - heading)
            return (0.68, 1, 0.43, 1.02, 34, clamped(error * 0.42, -0.32, 0.32), clamped(error * 0.08, -0.10, 0.10))
        case .dwelling:
            return (0.02, 1, 0.20, 0.38, 14, 0.22 * sin(behaviorClock * 5.1), 0)
        case .omegaTurn:
            return (0.24, 1, 0.58, 0.94, 30, turnDirection * 2.15, turnDirection * 0.78)
        case .collisionRecovery:
            return (-0.64, -1, 0.49, 1.38, 44, turnDirection * 0.55, 0)
        case .paused:
            return (0, 0, 0, 0, 0, 0, 0)
        }
    }

    private func solveBody(amplitude: Double, omegaBias: Double, dt: Double, screenBounds: CGRect) {
        guard points.count == Self.pointCount else {
            rebuildBody()
            return
        }

        if pointVelocities.count != Self.pointCount {
            pointVelocities = Array(repeating: .zero, count: Self.pointCount)
        }

        let bodyBounds = screenBounds.insetBy(dx: 15, dy: 15)
        var desired = Array(repeating: CGPoint.zero, count: Self.pointCount)
        desired[0] = head
        var unconstrainedDesired = head
        for index in 1..<Self.pointCount {
            let t = Double(index) / Double(Self.pointCount - 1)
            let envelope = 0.24 + 0.76 * pow(max(0, sin(.pi * min(0.94, t))), 0.48)
            let wavePhase = phase - Double(index) * 0.34
            let primaryWave = sin(wavePhase)
            let muscleAsymmetry = 0.14 * sin(wavePhase * 2 + 0.65)
            let travelingWave = (primaryWave + muscleAsymmetry) * amplitude * envelope
            let anteriorTurnEnvelope = sin(.pi * min(1, t * 1.18))
            let turnShape = omegaBias * anteriorTurnEnvelope
            let segmentHeading = heading + travelingWave + turnShape
            unconstrainedDesired = CGPoint(
                x: unconstrainedDesired.x - cos(segmentHeading) * Self.segmentLength,
                y: unconstrainedDesired.y - sin(segmentHeading) * Self.segmentLength
            )
            desired[index] = reflectedPoint(unconstrainedDesired, inside: bodyBounds)
        }

        let previousPoints = points
        points[0] = head
        for index in 1..<points.count {
            let t = Double(index) / Double(points.count - 1)
            let stiffness = 46 - t * 17
            let damping = exp(-dt * (7.2 - t * 2.2))
            pointVelocities[index].dx = (pointVelocities[index].dx + (desired[index].x - points[index].x) * stiffness * dt) * damping
            pointVelocities[index].dy = (pointVelocities[index].dy + (desired[index].y - points[index].y) * stiffness * dt) * damping
            points[index].x += pointVelocities[index].dx * dt
            points[index].y += pointVelocities[index].dy * dt
        }

        // Repeated projection preserves body length. A segment that would leave
        // the overlay reflects inward, producing a visible fold at the screen
        // boundary instead of allowing the tail to be clipped.
        for _ in 0..<5 {
            points[0] = head
            for index in 1..<points.count {
                points[index] = boundaryFoldedSegment(
                    from: points[index - 1],
                    toward: points[index],
                    inside: bodyBounds
                )
            }
        }

        pointVelocities[0] = .zero
        for index in 1..<points.count {
            pointVelocities[index].dx = (points[index].x - previousPoints[index].x) / max(dt, 0.001) * 0.82
            pointVelocities[index].dy = (points[index].y - previousPoints[index].y) / max(dt, 0.001) * 0.82
        }
    }

    private func reflectedPoint(_ point: CGPoint, inside bounds: CGRect) -> CGPoint {
        var reflected = point
        if reflected.x < bounds.minX { reflected.x = bounds.minX + (bounds.minX - reflected.x) }
        if reflected.x > bounds.maxX { reflected.x = bounds.maxX - (reflected.x - bounds.maxX) }
        if reflected.y < bounds.minY { reflected.y = bounds.minY + (bounds.minY - reflected.y) }
        if reflected.y > bounds.maxY { reflected.y = bounds.maxY - (reflected.y - bounds.maxY) }
        return reflected
    }

    private func boundaryFoldedSegment(from anchor: CGPoint, toward target: CGPoint, inside bounds: CGRect) -> CGPoint {
        var dx = target.x - anchor.x
        var dy = target.y - anchor.y
        let distance = max(0.0001, hypot(dx, dy))
        dx = dx / distance * Self.segmentLength
        dy = dy / distance * Self.segmentLength

        var candidate = CGPoint(x: anchor.x + dx, y: anchor.y + dy)
        if candidate.x < bounds.minX { dx = abs(dx) }
        if candidate.x > bounds.maxX { dx = -abs(dx) }
        if candidate.y < bounds.minY { dy = abs(dy) }
        if candidate.y > bounds.maxY { dy = -abs(dy) }
        candidate = CGPoint(x: anchor.x + dx, y: anchor.y + dy)

        // Handles the rare corner case where the anchor is less than one
        // segment from two edges while keeping the segment on-screen.
        if !bounds.contains(candidate) {
            let inward = CGPoint(
                x: min(bounds.maxX, max(bounds.minX, candidate.x)),
                y: min(bounds.maxY, max(bounds.minY, candidate.y))
            )
            let inwardDX = inward.x - anchor.x
            let inwardDY = inward.y - anchor.y
            let inwardDistance = max(0.0001, hypot(inwardDX, inwardDY))
            candidate = CGPoint(
                x: anchor.x + inwardDX / inwardDistance * Self.segmentLength,
                y: anchor.y + inwardDY / inwardDistance * Self.segmentLength
            )
        }
        return candidate
    }

    private func rebuildBody() {
        points = (0..<Self.pointCount).map { index in
            CGPoint(
                x: head.x - cos(heading) * Double(index) * Self.segmentLength,
                y: head.y - sin(heading) * Double(index) * Self.segmentLength
            )
        }
        pointVelocities = Array(repeating: .zero, count: Self.pointCount)
    }

    private func enter(_ next: WormBehavior, for duration: Double) {
        behavior = next
        behaviorClock = 0
        behaviorRemaining = duration
    }

    private func beginChemotaxis(toward target: CGPoint) {
        chemotaxisTarget = target
        let desired = atan2(target.y - head.y, target.x - head.x)
        let error = wrappedAngle(desired - heading)
        turnDirection = error >= 0 ? 1 : -1
        targetNeedsDeepTurn = abs(error) > 1.18
    }

    private func wrappedAngle(_ angle: Double) -> Double {
        var value = angle
        while value > .pi { value -= 2 * .pi }
        while value < -.pi { value += 2 * .pi }
        return value
    }

    private func clamped(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(upper, max(lower, value))
    }
}

final class WormView: NSView {
    let world: WormWorld
    let engine: NeuralEngine
    var showsAnatomy = true

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
        guard points.count > 2 else { return }

        drawShadow(points: points, context: context)
        drawBody(points: points, context: context)
        if showsAnatomy {
            drawInternalAnatomy(points: points, context: context)
        }
        drawCuticle(points: points, context: context)
    }

    private func bodyRadius(at progress: CGFloat) -> CGFloat {
        let core = pow(max(0, sin(.pi * progress)), 0.34)
        let headTaper = min(1, 0.38 + progress * 5.2)
        return max(0.55, 6.2 * core * headTaper)
    }

    private func drawShadow(points: [CGPoint], context: CGContext) {
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -3), blur: 7, color: NSColor.black.withAlphaComponent(0.32).cgColor)
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.12).cgColor)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(11)
        context.beginPath()
        context.addLines(between: points)
        context.strokePath()
        context.restoreGState()
    }

    private func drawBody(points: [CGPoint], context: CGContext) {
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for index in 0..<(points.count - 1) {
            let progress = CGFloat(index + 1) / CGFloat(points.count - 1)
            let radius = bodyRadius(at: progress)

            context.setStrokeColor(NSColor(calibratedRed: 0.28, green: 0.22, blue: 0.13, alpha: 0.52).cgColor)
            context.setLineWidth(radius * 2 + 1.1)
            context.beginPath()
            context.move(to: points[index])
            context.addLine(to: points[index + 1])
            context.strokePath()

            let warmth = 0.035 * sin(CGFloat(index) * 0.42)
            context.setStrokeColor(NSColor(
                calibratedRed: 0.88 + warmth,
                green: 0.81 + warmth * 0.55,
                blue: 0.63,
                alpha: 0.78
            ).cgColor)
            context.setLineWidth(radius * 2)
            context.beginPath()
            context.move(to: points[index])
            context.addLine(to: points[index + 1])
            context.strokePath()
        }
    }

    private func drawInternalAnatomy(points: [CGPoint], context: CGContext) {
        let intestine = Array(points[8...33])
        context.setStrokeColor(NSColor(calibratedRed: 0.43, green: 0.29, blue: 0.13, alpha: 0.26).cgColor)
        context.setLineWidth(3.1)
        context.setLineCap(.round)
        context.beginPath()
        context.addLines(between: intestine)
        context.strokePath()

        let pharynx = Array(points[1...9])
        context.setStrokeColor(NSColor(calibratedRed: 0.54, green: 0.32, blue: 0.15, alpha: 0.46).cgColor)
        context.setLineWidth(2.0)
        context.beginPath()
        context.addLines(between: pharynx)
        context.strokePath()

        for index in [4, 7] {
            context.setFillColor(NSColor(calibratedRed: 0.48, green: 0.28, blue: 0.12, alpha: 0.32).cgColor)
            context.fillEllipse(in: CGRect(x: points[index].x - 2.4, y: points[index].y - 2.4, width: 4.8, height: 4.8))
        }
    }

    private func drawCuticle(points: [CGPoint], context: CGContext) {
        context.setLineCap(.round)
        context.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: 0.25).cgColor)
        context.setLineWidth(0.75)
        context.beginPath()
        context.addLines(between: points)
        context.strokePath()

        for index in stride(from: 3, to: points.count - 2, by: 3) {
            let progress = CGFloat(index) / CGFloat(points.count - 1)
            let radius = bodyRadius(at: progress) * 0.72
            let dx = points[index + 1].x - points[index - 1].x
            let dy = points[index + 1].y - points[index - 1].y
            let length = max(0.001, hypot(dx, dy))
            let nx = -dy / length
            let ny = dx / length
            context.setStrokeColor(NSColor(calibratedRed: 0.30, green: 0.22, blue: 0.13, alpha: 0.11).cgColor)
            context.setLineWidth(0.55)
            context.beginPath()
            context.move(to: CGPoint(x: points[index].x - nx * radius, y: points[index].y - ny * radius))
            context.addLine(to: CGPoint(x: points[index].x + nx * radius, y: points[index].y + ny * radius))
            context.strokePath()
        }
    }
}
