import SwiftUI

// SwiftUI brush-stroke enso. Same single-stroke shape as the app icon,
// rendered as a filled polygon so the tapered width is preserved at any
// size and any color. Uses smoothstep lift-off + multi-frequency wobble.
struct EnsoView: View {
    var size: CGFloat = 32
    var color: Color = GrayPalette.charcoal

    var body: some View {
        Canvas { ctx, _ in
            ctx.fill(EnsoView.brushPath(side: size), with: .color(color))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    static func brushPath(side: CGFloat) -> Path {
        let cx = side / 2
        let cy = side / 2
        let radius = side * 0.38
        let startDeg: CGFloat = 35
        let sweepDeg: CGFloat = 320
        let maxW = side * 0.115
        let endW = side * 0.012

        let N = 240
        var outer: [CGPoint] = []
        var inner: [CGPoint] = []
        outer.reserveCapacity(N + 1)
        inner.reserveCapacity(N + 1)

        for i in 0...N {
            let t = CGFloat(i) / CGFloat(N)
            let angle = (startDeg + sweepDeg * t - 90) * .pi / 180

            // Width profile along the stroke.
            let baseW: CGFloat
            if t < 0.08 {
                baseW = maxW * (0.55 + 0.45 * (t / 0.08))
            } else if t < 0.75 {
                let bodyT = (t - 0.08) / 0.67
                baseW = maxW * (1.0 - 0.15 * bodyT)
            } else {
                let liftT = (t - 0.75) / 0.25
                let eased = liftT * liftT * (3 - 2 * liftT)
                baseW = maxW * 0.85 * (1 - eased) + endW * eased
            }
            let wobble = 1 + 0.04 * sin(t * .pi * 7)
            let w = baseW * wobble

            let px = cx + radius * cos(angle)
            let py = cy + radius * sin(angle)
            let nx = cos(angle)
            let ny = sin(angle)

            outer.append(CGPoint(x: px + nx * w / 2, y: py + ny * w / 2))
            inner.append(CGPoint(x: px - nx * w / 2, y: py - ny * w / 2))
        }

        var path = Path()
        path.move(to: outer[0])
        for p in outer.dropFirst() { path.addLine(to: p) }
        for p in inner.reversed() { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }
}
