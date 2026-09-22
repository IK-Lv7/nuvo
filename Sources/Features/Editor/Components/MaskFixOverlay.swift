import NuvoCore
import SwiftUI

/// 「切り抜きを直す」ペン。自動検出の結果を薄いピンクで示し、ドラッグで足す・消すを描く。
/// 下地(自動検出の結果)は写真ごとに1回だけ計算済みのものを描き、線は SwiftUI がその場で描く
/// (指を動かすたびに写真を作り直さないので、なめらかに動く)。
struct MaskFixOverlay: View {
    let viewModel: EditorViewModel
    let mode: MaskStroke.Mode
    let radius: Double

    @State private var isDrawing = false

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                if let overlay = viewModel.maskOverlayImage {
                    context.draw(Image(decorative: overlay, scale: 1), in: CGRect(origin: .zero, size: size))
                }
                for stroke in viewModel.parameters.maskStrokes ?? [] {
                    draw(stroke, in: &context, size: size)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let point = unit(value.location, in: geometry.size)
                        if isDrawing {
                            viewModel.extendMaskStroke(to: point)
                        } else {
                            isDrawing = true
                            viewModel.beginMaskStroke(at: point, mode: mode, radius: radius)
                        }
                    }
                    .onEnded { _ in
                        isDrawing = false
                        viewModel.endMaskStroke()
                    })
        }
    }

    /// 「足す」はピンクを重ね、「消す」はその場のピンクを透明にして写真を透かす(=マスクの見た目でも直感的に分かる)。
    private func draw(_ stroke: MaskStroke, in context: inout GraphicsContext, size: CGSize) {
        guard !stroke.points.isEmpty else { return }
        let points = stroke.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        var path = Path()
        // 長さ 0 の線分でも、丸い線端(lineCap: .round)のおかげで点として描ける(タップだけの場合)。
        path.move(to: points[0])
        for point in points.dropFirst() { path.addLine(to: point) }
        if points.count == 1 { path.addLine(to: points[0]) }
        let lineWidth = stroke.radius * Double(max(size.width, size.height)) * 2
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        switch stroke.mode {
        case .keep:
            context.stroke(path, with: .color(Theme.accent.opacity(0.45)), style: style)
        case .erase:
            context.blendMode = .destinationOut
            context.stroke(path, with: .color(.black), style: style)
            context.blendMode = .normal
        }
    }

    private func unit(_ location: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: location.x / max(size.width, 1), y: location.y / max(size.height, 1))
    }
}
