import Foundation

/// Persisted session record. Same shape as the Pi's session JSON so
/// records are portable between device and phone.
struct SessionRecord: Identifiable, Codable, Hashable {
    let id: String
    let startDate: Date
    var endDate: Date?
    let side: EpleyConfig.Side
    var steps: [StepRecord]
    var vertiscore: Double?
    var grade: String?
    var recoveryProbability: Double?
    var nystagmusPeakRatio: Double?
    var aiSummary: String?
    var userFeedback: String?
    var baselineGyroNoise: Baseline?

    init(id: String = UUID().uuidString,
         startDate: Date = .now,
         side: EpleyConfig.Side,
         steps: [StepRecord] = []) {
        self.id = id
        self.startDate = startDate
        self.side = side
        self.steps = steps
    }

    struct StepRecord: Codable, Hashable, Identifiable {
        var id: String { name }
        let name: String
        let description: String
        let targetPitch: Double
        let targetRoll: Double
        let targetYaw: Double
        let holdTargetS: Double
        var alignTimeS: Double = 0
        var holdActualS: Double = 0
        var sway: SwayMetrics = .zero
        var events: [Event] = []

        struct Event: Codable, Hashable {
            let t: TimeInterval
            let kind: String
            let detail: String
        }
    }

    struct SwayMetrics: Codable, Hashable {
        var swayAreaDeg2: Double
        var pathLengthDeg: Double
        var meanVelocityDegS: Double
        var rmsGyroDegS: Double
        var f50Hz: Double
        var f95Hz: Double
        var driftDeg: Double
        var alignedFraction: Double
        var nSamples: Int
        var durationS: Double

        static let zero = SwayMetrics(
            swayAreaDeg2: 0, pathLengthDeg: 0, meanVelocityDegS: 0, rmsGyroDegS: 0,
            f50Hz: 0, f95Hz: 0, driftDeg: 0, alignedFraction: 0, nSamples: 0, durationS: 0
        )
    }

    struct Baseline: Codable, Hashable {
        var bandPower1to3Hz: Double
        var noiseFloorDegS: Double
    }
}
