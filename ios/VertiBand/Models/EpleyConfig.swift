import Foundation

/// Static configuration for the Epley maneuver — mirror of `config.py` on
/// the Pi. Angles in degrees, times in seconds.
enum EpleyConfig {
    static let sampleRateHz: Double = 50
    static let stabilityTimeS: Double = 1.5
    static let pitchToleranceDeg: Double = 15
    static let rollToleranceDeg: Double = 15
    static let yawToleranceDeg: Double = 15

    enum Side: String, CaseIterable, Identifiable, Codable {
        case right, left
        var id: String { rawValue }
        var title: String { self == .right ? "Right side" : "Left side" }
    }

    struct Step: Identifiable, Hashable, Codable {
        let id: String
        let name: String
        let description: String
        let pitch: Double
        let roll: Double
        let yaw: Double
        let holdS: Double
    }

    static func steps(for side: Side) -> [Step] {
        switch side {
        case .right: return [
            Step(id: "step1", name: "Step 1", description: "Turn your head 45° to the right.",
                 pitch: 0, roll: 0, yaw: 45, holdS: 30),
            Step(id: "step2", name: "Step 2", description: "Lie back slowly, keeping the angle.",
                 pitch: -30, roll: 0, yaw: 45, holdS: 30),
            Step(id: "step3", name: "Step 3", description: "Rotate your head 90° to the left.",
                 pitch: -30, roll: 0, yaw: -45, holdS: 30),
            Step(id: "step4", name: "Step 4", description: "Roll onto your left side.",
                 pitch: -30, roll: -45, yaw: -45, holdS: 30),
            Step(id: "step5", name: "Step 5", description: "Sit up, slowly.",
                 pitch: 0, roll: 0, yaw: 0, holdS: 5),
        ]
        case .left: return [
            Step(id: "step1", name: "Step 1", description: "Turn your head 45° to the left.",
                 pitch: 0, roll: 0, yaw: -45, holdS: 30),
            Step(id: "step2", name: "Step 2", description: "Lie back slowly, keeping the angle.",
                 pitch: -30, roll: 0, yaw: -45, holdS: 30),
            Step(id: "step3", name: "Step 3", description: "Rotate your head 90° to the right.",
                 pitch: -30, roll: 0, yaw: 45, holdS: 30),
            Step(id: "step4", name: "Step 4", description: "Roll onto your right side.",
                 pitch: -30, roll: 45, yaw: 45, holdS: 30),
            Step(id: "step5", name: "Step 5", description: "Sit up, slowly.",
                 pitch: 0, roll: 0, yaw: 0, holdS: 5),
        ]
        }
    }
}
