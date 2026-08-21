import AppKit
import Foundation

func renderPreview(connectome: Connectome, path: String) -> Int32 {
    _ = NSApplication.shared
    let engine = NeuralEngine(connectome: connectome)
    let world = WormWorld()
    let size = CGSize(width: 760, height: 220)
    let bounds = CGRect(origin: .zero, size: size)
    world.place(at: CGPoint(x: 520, y: 110))
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
        print("PASS: offscreen preview rendered to \(path)")
        return 0
    } catch {
        fputs("FAIL: could not write offscreen preview: \(error)\n", stderr)
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

    print("PASS: OpenWorm graph loaded")
    print("  neurons: \(connectome.neurons.count)")
    print("  neural edges: \(connectome.edges.count)")
    print("  muscles: \(connectome.muscles.count)")
    print("  neuromuscular edges: \(connectome.muscleEdges.count)")
    print(String(format: "  baseline forward/reverse: %.3f / %.3f", baseline.forward, baseline.reverse))
    print(String(format: "  post-touch forward/reverse: %.3f / %.3f", touched.forward, touched.reverse))
    print(String(format: "  articulated body max error: %.6f px", world.maximumSegmentError()))
    print("  behaviors: crawl, sense, head sweep, shallow/deep turn, approach, dwell, reverse, omega, recovery, pause")
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

    let app = NSApplication.shared
    let delegate = AppDelegate(connectome: connectome)
    app.delegate = delegate
    app.run()
} catch {
    fputs("DesktopWorm failed to load the connectome: \(error)\n", stderr)
    exit(1)
}
