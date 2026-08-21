import AppKit
import Foundation

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

    print("PASS: OpenWorm graph loaded")
    print("  neurons: \(connectome.neurons.count)")
    print("  neural edges: \(connectome.edges.count)")
    print("  muscles: \(connectome.muscles.count)")
    print("  neuromuscular edges: \(connectome.muscleEdges.count)")
    print(String(format: "  baseline forward/reverse: %.3f / %.3f", baseline.forward, baseline.reverse))
    print(String(format: "  post-touch forward/reverse: %.3f / %.3f", touched.forward, touched.reverse))
    return 0
}

do {
    let connectome = try Connectome.load()
    if CommandLine.arguments.contains("--selftest") {
        exit(runSelfTest(connectome: connectome))
    }

    let app = NSApplication.shared
    let delegate = AppDelegate(connectome: connectome)
    app.delegate = delegate
    app.run()
} catch {
    fputs("DesktopWorm failed to load the connectome: \(error)\n", stderr)
    exit(1)
}
