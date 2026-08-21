import AppKit
import Foundation

func renderPreview(connectome: Connectome, path: String, edgeFold: Bool = false) -> Int32 {
    _ = NSApplication.shared
    let engine = NeuralEngine(connectome: connectome)
    let world = WormWorld()
    let size = CGSize(width: 760, height: 220)
    let bounds = CGRect(origin: .zero, size: size)
    if edgeFold {
        world.place(at: CGPoint(x: 390, y: 145), heading: -.pi / 2)
    } else {
        world.place(at: CGPoint(x: 520, y: 110))
    }
    world.triggerFood(engine: engine)
    for _ in 0..<80 {
        engine.step(dt: 1.0 / 60.0)
        world.update(
            dt: 1.0 / 60.0,
            bounds: bounds,
            engine: engine,
            mouse: CGPoint(x: 700, y: 178)
        )
    }

    let view = WormView(frame: bounds, world: world, engine: engine)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor(calibratedWhite: 0.075, alpha: 1).setFill()
    bounds.fill()
    view.draw(bounds)
    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fputs("FAIL: could not render offscreen preview\n", stderr)
        return 1
    }

    do {
        try png.write(to: URL(fileURLWithPath: path), options: .atomic)
        print("PASS: \(edgeFold ? "edge-fold" : "offscreen") preview rendered to \(path)")
        return 0
    } catch {
        fputs("FAIL: could not write offscreen preview: \(error)\n", stderr)
        return 1
    }
}

func renderNeuralPreview(connectome: Connectome, path: String) -> Int32 {
    _ = NSApplication.shared
    let engine = NeuralEngine(connectome: connectome)
    let world = WormWorld()
    let size = CGSize(width: 520, height: 340)
    let bounds = CGRect(origin: .zero, size: size)
    let simulationBounds = CGRect(x: 0, y: 0, width: 1_200, height: 800)
    world.place(at: CGPoint(x: 600, y: 400))
    let view = NeuralMapView(frame: bounds, engine: engine, world: world)
    for _ in 0..<360 {
        engine.step(dt: 1.0 / 60.0)
        world.update(
            dt: 1.0 / 60.0,
            bounds: simulationBounds,
            engine: engine,
            mouse: CGPoint(x: 1_000, y: 650)
        )
        view.sample()
    }

    let image = NSImage(size: size)
    image.lockFocus()
    view.draw(bounds)
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fputs("FAIL: could not encode Living Connectome preview\n", stderr)
        return 1
    }
    do {
        try png.write(to: URL(fileURLWithPath: path), options: .atomic)
        print("PASS: Living Connectome rendered to \(path)")
        return 0
    } catch {
        fputs("FAIL: could not write Living Connectome preview: \(error)\n", stderr)
        return 1
    }
}

func runSelfTest(connectome: Connectome) -> Int32 {
    guard connectome.neurons.count == 302 else {
        fputs("FAIL: expected 302 neurons, found \(connectome.neurons.count)\n", stderr)
        return 1
    }
    guard connectome.muscles.count == 95 else {
        fputs("FAIL: expected 95 muscles, found \(connectome.muscles.count)\n", stderr)
        return 1
    }
    guard connectome.edges.count > 5_000, connectome.muscleEdges.count > 800 else {
        fputs("FAIL: connectome graph is unexpectedly sparse\n", stderr)
        return 1
    }

    let engine = NeuralEngine(connectome: connectome)
    for _ in 0..<300 { engine.step() }
    let baseline = engine.motorState()
    let baselineDVA = engine.indexByName["DVA"].map { engine.activity[$0] } ?? 0
    engine.setProprioceptiveState(headBend: 0.45, bodyCurvature: 0.22)
    for _ in 0..<80 { engine.step() }
    let proprioceptiveDVA = engine.indexByName["DVA"].map { engine.activity[$0] } ?? 0
    guard proprioceptiveDVA > baselineDVA,
          engine.activityChange.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
        fputs("FAIL: modeled SMD/DVA proprioceptive feedback is inactive\n", stderr)
        return 1
    }
    engine.stimulateTouch(1.4)
    for _ in 0..<120 { engine.step() }
    let touched = engine.motorState()

    guard engine.activity.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }) else {
        fputs("FAIL: neural activity left valid range\n", stderr)
        return 1
    }
    guard engine.muscles.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }) else {
        fputs("FAIL: muscle activity left valid range\n", stderr)
        return 1
    }
    guard connectome.edges.prefix(300).contains(where: { engine.signalStrength(for: $0) > 0 }) else {
        fputs("FAIL: active c302 edges have no visual signal flux\n", stderr)
        return 1
    }
    let touchChangedNetwork = zip(engine.activity, Array(repeating: 0.02, count: engine.activity.count))
        .contains { abs($0 - $1) > 0.05 }
    guard touchChangedNetwork else {
        fputs("FAIL: sensory stimulation did not change network activity\n", stderr)
        return 1
    }

    let world = WormWorld()
    let simulationBounds = CGRect(x: 0, y: 0, width: 1200, height: 800)
    let quietMouse = CGPoint(x: 1050, y: 700)
    let startingHead = world.head
    for _ in 0..<90 {
        engine.step(dt: 1.0 / 60.0)
        world.update(dt: 1.0 / 60.0, bounds: simulationBounds, engine: engine, mouse: quietMouse)
    }
    guard world.bodyPoints().count == 40, world.maximumSegmentError() < 0.001 else {
        fputs("FAIL: articulated body constraints are unstable\n", stderr)
        return 1
    }
    guard hypot(world.head.x - startingHead.x, world.head.y - startingHead.y) > 5 else {
        fputs("FAIL: body wave did not generate locomotion\n", stderr)
        return 1
    }
    guard world.bodyWaveEnergy() > 0.025 else {
        fputs("FAIL: locomotion translated without a visible articulated body wave\n", stderr)
        return 1
    }

    // A stationary pointer must not repeatedly trap autonomous locomotion in
    // the chemotaxis pause/approach cycle. Sustained runs should cover desktop
    // distance while their speed remains coupled to the articulated gait.
    let roamingWorld = WormWorld()
    roamingWorld.place(at: CGPoint(x: 2_000, y: 1_500))
    let roamingBounds = CGRect(x: 0, y: 0, width: 4_000, height: 3_000)
    let stationaryCursor = CGPoint(x: 2_300, y: 1_500)
    var roamingPathLength = 0.0
    var previousRoamingHead = roamingWorld.head
    var cursorInducedStop = false
    for _ in 0..<720 {
        engine.step(dt: 1.0 / 60.0)
        roamingWorld.update(
            dt: 1.0 / 60.0,
            bounds: roamingBounds,
            engine: engine,
            mouse: stationaryCursor
        )
        roamingPathLength += hypot(
            roamingWorld.head.x - previousRoamingHead.x,
            roamingWorld.head.y - previousRoamingHead.y
        )
        previousRoamingHead = roamingWorld.head
        cursorInducedStop = cursorInducedStop
            || roamingWorld.behavior == .sensoryPause
            || roamingWorld.behavior == .approachCrawl
    }
    guard roamingPathLength > 350, !cursorInducedStop else {
        fputs("FAIL: autonomous roaming stalled beside a stationary cursor\n", stderr)
        return 1
    }

    let edgeWorld = WormWorld()
    edgeWorld.place(at: CGPoint(x: 600, y: 650), heading: -.pi / 2)
    for _ in 0..<12 {
        engine.step(dt: 1.0 / 60.0)
        edgeWorld.update(dt: 1.0 / 60.0, bounds: simulationBounds, engine: engine, mouse: quietMouse)
    }
    guard edgeWorld.minimumEdgeClearance(in: simulationBounds) >= 14.9,
          edgeWorld.maximumSegmentError() < 0.001 else {
        fputs("FAIL: trailing body clipped instead of folding at screen edge\n", stderr)
        return 1
    }

    world.triggerTouch(engine: engine)
    guard world.behavior == .reverseEscape else {
        fputs("FAIL: touch did not select reverse behavior\n", stderr)
        return 1
    }
    for _ in 0..<75 {
        engine.step(dt: 1.0 / 60.0)
        world.update(dt: 1.0 / 60.0, bounds: simulationBounds, engine: engine, mouse: quietMouse)
    }
    guard world.behavior == .omegaTurn else {
        fputs("FAIL: reverse behavior did not transition to omega turn\n", stderr)
        return 1
    }

    world.triggerFood(engine: engine)
    guard world.behavior == .sensoryPause else {
        fputs("FAIL: food signal did not begin staged chemotaxis\n", stderr)
        return 1
    }
    var observedChemotaxisBehaviors: Set<WormBehavior> = [world.behavior]
    for _ in 0..<380 {
        engine.step(dt: 1.0 / 60.0)
        world.update(dt: 1.0 / 60.0, bounds: simulationBounds, engine: engine, mouse: quietMouse)
        observedChemotaxisBehaviors.insert(world.behavior)
    }
    let sawBodyTurn = observedChemotaxisBehaviors.contains(.shallowTurn)
        || observedChemotaxisBehaviors.contains(.deepTurn)
    guard observedChemotaxisBehaviors.contains(.headSweep),
          sawBodyTurn,
          observedChemotaxisBehaviors.contains(.approachCrawl),
          observedChemotaxisBehaviors.contains(.dwelling) else {
        fputs("FAIL: chemotaxis skipped a visible movement stage\n", stderr)
        return 1
    }
    world.setPaused(true)
    let pausedHead = world.head
    world.update(dt: 0.2, bounds: simulationBounds, engine: engine, mouse: quietMouse)
    guard world.behavior == .paused, world.head == pausedHead else {
        fputs("FAIL: pause did not freeze the body\n", stderr)
        return 1
    }
    world.setPaused(false)

    let spontaneousWorld = WormWorld()
    spontaneousWorld.place(at: CGPoint(x: 2_000, y: 1_500))
    let largeBounds = CGRect(x: 0, y: 0, width: 4_000, height: 3_000)
    let farMouse = CGPoint(x: 3_900, y: 2_900)
    var spontaneousBehaviors: Set<WormBehavior> = []
    for _ in 0..<1_800 {
        engine.step(dt: 1.0 / 30.0)
        spontaneousWorld.update(
            dt: 1.0 / 30.0,
            bounds: largeBounds,
            engine: engine,
            mouse: farMouse
        )
        spontaneousBehaviors.insert(spontaneousWorld.behavior)
    }
    let expectedSpontaneous: Set<WormBehavior> = [
        .headSweep, .shallowTurn, .roaming, .localSearch, .dwelling, .pirouette, .deepTurn,
    ]
    guard expectedSpontaneous.isSubset(of: spontaneousBehaviors) else {
        fputs("FAIL: spontaneous controller did not rotate through the full repertoire\n", stderr)
        return 1
    }

    _ = NSApplication.shared
    let neuralView = NeuralMapView(
        frame: CGRect(x: 0, y: 0, width: 1_100, height: 720),
        engine: engine,
        world: spontaneousWorld
    )
    for _ in 0..<12 {
        engine.step(dt: 0.05)
        neuralView.sample()
    }
    guard neuralView.sampleCount >= 10 else {
        fputs("FAIL: Living Connectome history is not sampling activity\n", stderr)
        return 1
    }
    let anatomicalLayout = NeuralMapView.makeAnatomicalLayout(for: connectome.neurons)
    guard anatomicalLayout.count == 302,
          anatomicalLayout.allSatisfy({ $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) }) else {
        fputs("FAIL: nervous-system schematic did not place every neuron\n", stderr)
        return 1
    }
    let regionCounts = Dictionary(grouping: connectome.neurons, by: NeuralMapView.anatomicalRegion(for:)).mapValues(\.count)
    guard NeuralAnatomicalRegion.allCases.allSatisfy({ (regionCounts[$0] ?? 0) > 0 }),
          (regionCounts[.anteriorComplex] ?? 0) > 150,
          (regionCounts[.ventralCord] ?? 0) > 60 else {
        fputs("FAIL: nervous-system schematic regions are unexpectedly sparse\n", stderr)
        return 1
    }
    let testDisplay = CGRect(x: 1_440, y: 24, width: 1_920, height: 1_056)
    let hudOrigin = AppDelegate.connectomeHUDOrigin(
        windowSize: NSSize(width: 520, height: 362),
        visibleFrame: testDisplay
    )
    guard hudOrigin.x == testDisplay.maxX - 538,
          hudOrigin.y == testDisplay.minY + 18 else {
        fputs("FAIL: compact connectome HUD is not anchored bottom-right\n", stderr)
        return 1
    }
    guard !AppDelegate.connectomeWindowStyleMask.contains(.fullSizeContentView) else {
        fputs("FAIL: connectome content extends beneath the native title bar\n", stderr)
        return 1
    }
    let statusIcon = AppDelegate.makeStatusIcon()
    guard statusIcon.isTemplate,
          statusIcon.size == NSSize(width: 18, height: 18),
          statusIcon.accessibilityDescription == "DesktopWorm" else {
        fputs("FAIL: menu-bar worm is not a native monochrome template icon\n", stderr)
        return 1
    }

    print("PASS: OpenWorm graph loaded")
    print("  neurons: \(connectome.neurons.count)")
    print("  neural edges: \(connectome.edges.count)")
    print("  muscles: \(connectome.muscles.count)")
    print("  neuromuscular edges: \(connectome.muscleEdges.count)")
    print(String(format: "  baseline forward/reverse: %.3f / %.3f", baseline.forward, baseline.reverse))
    print(String(format: "  post-touch forward/reverse: %.3f / %.3f", touched.forward, touched.reverse))
    print(String(format: "  DVA proprioceptive response: %.3f → %.3f", baselineDVA, proprioceptiveDVA))
    print(String(format: "  articulated body max error: %.6f px", world.maximumSegmentError()))
    print(String(format: "  articulated body wave energy: %.4f rad/segment", world.bodyWaveEnergy()))
    print(String(format: "  12-second autonomous path: %.1f px", roamingPathLength))
    print(String(format: "  minimum edge-fold clearance: %.2f px", edgeWorld.minimumEdgeClearance(in: simulationBounds)))
    print("  behaviors: crawl, sense, head sweep, shallow/deep turn, approach, dwell, reverse, omega, recovery, pause")
    print("  spontaneous repertoire states observed: \(spontaneousBehaviors.count)")
    print("  Living Connectome history samples: \(neuralView.sampleCount)")
    print("  schematic regions: head + nerve ring \(regionCounts[.anteriorComplex] ?? 0), ventral cord \(regionCounts[.ventralCord] ?? 0), body sensory \(regionCounts[.bodySensory] ?? 0), tail \(regionCounts[.tailGanglia] ?? 0)")
    print("  compact HUD placement: bottom-right on active display")
    print("  title-bar safe area: native content separation")
    print("  menu-bar icon: adaptive monochrome template")
    return 0
}

do {
    let connectome = try Connectome.load()
    if CommandLine.arguments.contains("--selftest") {
        exit(runSelfTest(connectome: connectome))
    }
    if let previewIndex = CommandLine.arguments.firstIndex(of: "--render-preview"),
       CommandLine.arguments.indices.contains(previewIndex + 1) {
        exit(renderPreview(connectome: connectome, path: CommandLine.arguments[previewIndex + 1]))
    }
    if let previewIndex = CommandLine.arguments.firstIndex(of: "--render-edge-preview"),
       CommandLine.arguments.indices.contains(previewIndex + 1) {
        exit(renderPreview(connectome: connectome, path: CommandLine.arguments[previewIndex + 1], edgeFold: true))
    }
    if let previewIndex = CommandLine.arguments.firstIndex(of: "--render-neural-preview"),
       CommandLine.arguments.indices.contains(previewIndex + 1) {
        exit(renderNeuralPreview(connectome: connectome, path: CommandLine.arguments[previewIndex + 1]))
    }

    let app = NSApplication.shared
    let delegate = AppDelegate(connectome: connectome)
    app.delegate = delegate
    app.run()
} catch {
    fputs("DesktopWorm failed to load the connectome: \(error)\n", stderr)
    exit(1)
}
