import SwiftUI

/// Draws the target tolerance box + current pose dot in degree space.
/// Axes: roll (x) and pitch (y).
struct PoseCanvas: View {
    let pose: SessionEngine.Pose
    let target: Pose
    let aligned: Bool
    let phase: SessionEngine.Phase

    struct Pose: Equatable { let pitch: Double; let roll: Double }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let scale = min(w, h) / 120.0 // ±60° across the shorter dimension

            ZStack {
                // Background glow
                Circle()
                    .fill(RadialGradient(colors: [Theme.Palette.cyan.opacity(0.12), .clear],
                                         center: .center, startRadius: 8, endRadius: min(w,h)/1.4))
                    .frame(width: w, height: h)
                    .blendMode(.screen)

                // Grid
                Canvas { ctx, size in
                    let stroke = GraphicsContext.Shading.color(.white.opacity(0.06))
                    for i in 1..<10 {
                        let x = Double(i) * Double(size.width) / 10
                        let y = Double(i) * Double(size.height) / 10
                        ctx.stroke(Path { p in p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height)) }, with: stroke, lineWidth: 1)
                        ctx.stroke(Path { p in p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y)) }, with: stroke, lineWidth: 1)
                    }
                    // axes
                    let axis = GraphicsContext.Shading.color(.white.opacity(0.18))
                    ctx.stroke(Path { p in p.move(to: CGPoint(x: 0, y: size.height/2)); p.addLine(to: CGPoint(x: size.width, y: size.height/2)) }, with: axis, lineWidth: 1)
                    ctx.stroke(Path { p in p.move(to: CGPoint(x: size.width/2, y: 0)); p.addLine(to: CGPoint(x: size.width/2, y: size.height)) }, with: axis, lineWidth: 1)
                }

                // Target tolerance box
                let tx = w/2 + target.roll  * scale
                let ty = h/2 - target.pitch * scale
                let tolDim: CGFloat = 15 * scale * 2
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(aligned ? Theme.Palette.success : Theme.Palette.cyan,
                                  style: StrokeStyle(lineWidth: 2, dash: aligned ? [] : [4,4]))
                    .frame(width: tolDim, height: tolDim)
                    .position(x: tx, y: ty)
                    .animation(Theme.Motion.easeFast, value: aligned)

                // Target dot
                Circle().fill(aligned ? Theme.Palette.success : Theme.Palette.cyan)
                    .frame(width: 6, height: 6)
                    .position(x: tx, y: ty)

                // Current pose with glow
                let px = w/2 + pose.roll  * scale
                let py = h/2 - pose.pitch * scale
                Circle().fill(Color.white)
                    .frame(width: 14, height: 14)
                    .shadow(color: (aligned ? Theme.Palette.success : Theme.Palette.cyan).opacity(0.8), radius: 14)
                    .position(x: px, y: py)
                    .animation(.interactiveSpring(), value: pose)
            }
        }
    }
}
