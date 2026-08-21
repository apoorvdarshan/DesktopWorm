import Foundation

struct Connectome: Decodable {
    let dataset: String
    let sourceRevision: String
    let neurons: [Neuron]
    let edges: [NeuralEdge]
    let muscles: [String]
    let muscleEdges: [MuscleEdge]

    static func load() throws -> Connectome {
        guard let url = Bundle.module.url(forResource: "connectome", withExtension: "json") else {
            throw ConnectomeError.resourceMissing
        }
        return try JSONDecoder().decode(Connectome.self, from: Data(contentsOf: url))
    }
}

struct Neuron: Decodable {
    let id: String
    let roles: [String]
    let transmitters: [String]

    var category: NeuronCategory {
        if roles.contains("sensory") && !roles.contains("motor") { return .sensory }
        if roles.contains("motor") { return .motor }
        return .interneuron
    }
}

enum NeuronCategory: String, CaseIterable {
    case sensory
    case interneuron
    case motor
}

struct NeuralEdge: Decodable {
    let source: Int
    let target: Int
    let weight: Int
    let kind: String
    let sign: Int
}

struct MuscleEdge: Decodable {
    let source: Int
    let target: Int
    let weight: Int
    let sign: Int
}

enum ConnectomeError: Error {
    case resourceMissing
}
