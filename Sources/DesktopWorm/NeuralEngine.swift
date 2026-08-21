import Foundation

struct MotorState {
    let forward: Double
    let reverse: Double
    let left: Double
    let right: Double
    let dorsalMuscle: Double
    let ventralMuscle: Double
    let arousal: Double
}

final class NeuralEngine {
    let connectome: Connectome
    let indexByName: [String: Int]

    private(set) var activity: [Double]
    private(set) var membrane: [Double]
    private(set) var muscles: [Double]
    private(set) var time: Double = 0

    private var external: [Double]
    private var randomState: UInt64 = 0xC0FFEE302
    private var touchEnvelope: Double = 0
    private var foodEnvelope: Double = 0

    init(connectome: Connectome) {
        self.connectome = connectome
        self.indexByName = Dictionary(uniqueKeysWithValues: connectome.neurons.enumerated().map { ($1.id, $0) })
        self.activity = Array(repeating: 0.02, count: connectome.neurons.count)
        self.membrane = Array(repeating: -1.5, count: connectome.neurons.count)
        self.external = Array(repeating: 0, count: connectome.neurons.count)
        self.muscles = Array(repeating: 0, count: connectome.muscles.count)
    }

    func reset() {
        activity = Array(repeating: 0.02, count: connectome.neurons.count)
        membrane = Array(repeating: -1.5, count: connectome.neurons.count)
        external = Array(repeating: 0, count: connectome.neurons.count)
        muscles = Array(repeating: 0, count: connectome.muscles.count)
        touchEnvelope = 0
        foodEnvelope = 0
        time = 0
    }

    func stimulateTouch(_ strength: Double = 1) {
        touchEnvelope = max(touchEnvelope, min(1.5, strength))
    }

    func stimulateFood(_ strength: Double = 1) {
        foodEnvelope = max(foodEnvelope, min(1.5, strength))
    }

    func step(dt: Double = 0.01) {
        time += dt
        touchEnvelope *= exp(-dt * 4.0)
        foodEnvelope *= exp(-dt * 1.4)
        external = Array(repeating: 0, count: activity.count)

        inject(["ALML", "ALMR", "AVM", "PLML", "PLMR", "PVM"], amount: touchEnvelope * 3.8)
        inject(["ASHL", "ASHR", "FLPL", "FLPR"], amount: touchEnvelope * 2.4)
        inject(["AWAL", "AWAR", "AWCL", "AWCR", "ASEL", "ASER"], amount: foodEnvelope * 2.1)

        // A light spontaneous sensory background keeps the complete network alive.
        let wander = 0.16 + 0.08 * sin(time * 0.73)
        inject(["AWBL", "AWBR", "AFDL", "AFDR"], amount: wander)

        var current = external
        for edge in connectome.edges {
            let weight = log1p(Double(edge.weight))
            if edge.kind == "electrical" {
                current[edge.target] += (activity[edge.source] - activity[edge.target]) * weight * 0.008
            } else {
                current[edge.target] += activity[edge.source] * weight * Double(edge.sign) * 0.018
            }
        }

        for index in activity.indices {
            let noise = (nextRandom() - 0.5) * 0.035
            membrane[index] += dt * ((-1.3 - membrane[index]) * 5.2 + current[index] * 8.5 + noise)
            let target = 1.0 / (1.0 + exp(-2.4 * (membrane[index] + 0.35)))
            activity[index] += (target - activity[index]) * min(1, dt * 12)
            activity[index] = min(1, max(0, activity[index]))
        }

        updateMuscles(dt: dt)
    }

    func motorState() -> MotorState {
        let forward = mean(["AVBL", "AVBR", "PVCL", "PVCR"])
        let reverse = mean(["AVAL", "AVAR", "AVDL", "AVDR", "AVEL", "AVER", "RIML", "RIMR"])
        let left = mean(["AIBL", "RIAL", "SMDDL", "SMDVL"])
        let right = mean(["AIBR", "RIAR", "SMDDR", "SMDVR"])

        var dorsal = 0.0
        var ventral = 0.0
        var dorsalCount = 0.0
        var ventralCount = 0.0
        for (index, name) in connectome.muscles.enumerated() {
            if name.hasPrefix("MD") {
                dorsal += muscles[index]
                dorsalCount += 1
            } else if name.hasPrefix("MV") {
                ventral += muscles[index]
                ventralCount += 1
            }
        }

        return MotorState(
            forward: forward,
            reverse: reverse,
            left: left,
            right: right,
            dorsalMuscle: dorsal / max(1, dorsalCount),
            ventralMuscle: ventral / max(1, ventralCount),
            arousal: activity.reduce(0, +) / Double(activity.count)
        )
    }

    func strongestActiveNeurons(limit: Int) -> [(Neuron, Double)] {
        activity.enumerated()
            .sorted { $0.element > $1.element }
            .prefix(limit)
            .map { (connectome.neurons[$0.offset], $0.element) }
    }

    private func inject(_ names: [String], amount: Double) {
        for name in names {
            if let index = indexByName[name] {
                external[index] += amount
            }
        }
    }

    private func mean(_ names: [String]) -> Double {
        let values = names.compactMap { indexByName[$0].map { activity[$0] } }
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    private func updateMuscles(dt: Double) {
        var drive = Array(repeating: 0.0, count: muscles.count)
        for edge in connectome.muscleEdges {
            drive[edge.target] += activity[edge.source] * log1p(Double(edge.weight)) * Double(edge.sign)
        }
        for index in muscles.indices {
            let normalized = 1.0 / (1.0 + exp(-(drive[index] - 0.8)))
            muscles[index] += (normalized - muscles[index]) * min(1, dt * 10)
        }
    }

    private func nextRandom() -> Double {
        randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
        return Double(randomState >> 11) / Double(UInt64.max >> 11)
    }
}
