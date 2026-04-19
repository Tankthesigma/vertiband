import Foundation
import Combine
import CoreMotion
import UIKit

/// Phone-based motion sensor. Returns pitch/roll/yaw in degrees at the
/// configured sample rate. The phone is held against the forehead like
/// a headband for the demo; orientation maps:
///   pitch ↦ head forward/back tilt
///   roll  ↦ head side tilt
///   yaw   ↦ head rotation left/right
@MainActor
@Observable
final class MotionService {
    private let manager = CMMotionManager()

    /// Latest pose in degrees.
    private(set) var pitch: Double = 0
    private(set) var roll:  Double = 0
    private(set) var yaw:   Double = 0

    /// Latest gyro magnitude in deg/s.
    private(set) var gyroMag: Double = 0

    /// True once the phone is reporting data (i.e. not plugged in on a
    /// simulator without a real gyro).
    private(set) var isTracking = false

    /// Optional sink called every sample.
    var onSample: ((Double, Double, Double, Double, Double, Double) -> Void)?

    /// Reference yaw captured at `calibrate()`, subtracted from output.
    private var yawOffset: Double = 0

    func start(sampleRateHz: Double = EpleyConfig.sampleRateHz) {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / sampleRateHz
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            // Rotate phone into "worn as headband on forehead" orientation:
            // the back of the phone faces forward, top of phone is upright.
            // Apple's DeviceMotion reports attitude in radians.
            let p = rad2deg(data.attitude.pitch)
            let r = rad2deg(data.attitude.roll)
            let y = rad2deg(data.attitude.yaw) - self.yawOffset
            let gx = rad2deg(data.rotationRate.x)
            let gy = rad2deg(data.rotationRate.y)
            let gz = rad2deg(data.rotationRate.z)
            self.pitch = p
            self.roll  = r
            self.yaw   = wrap180(y)
            self.gyroMag = sqrt(gx*gx + gy*gy + gz*gz)
            self.isTracking = true
            self.onSample?(p, r, wrap180(y), gx, gy, gz)
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        isTracking = false
    }

    func calibrate() {
        yawOffset = rad2deg(manager.deviceMotion?.attitude.yaw ?? 0)
    }
}

private func rad2deg(_ x: Double) -> Double { x * 180.0 / .pi }
private func wrap180(_ x: Double) -> Double {
    var y = x.truncatingRemainder(dividingBy: 360)
    if y >  180 { y -= 360 }
    if y < -180 { y += 360 }
    return y
}
