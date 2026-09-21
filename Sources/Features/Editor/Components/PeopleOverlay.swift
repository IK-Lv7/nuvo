import SwiftUI

/// 写真の上に、顔ごとの目印を出す。タップで加工する・しないを切り替え、指で囲むと、囲んだ人だけを選ぶ。
/// 座標は画像に対する相対位置(0...1、左上原点)。拡大・移動の内側に置くので、拡大中でも顔に合う。
struct PeopleOverlay: View {
    let viewModel: EditorViewModel

    @State private var lasso: [CGPoint] = []

    /// これ以上動いたら、タップではなく囲む操作とみなす(pt)。
    private let lassoThreshold: CGFloat = 12

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(viewModel.detectedFaces.enumerated()), id: \.offset) { index, face in
                    marker(index: index, box: face.boundingBox, in: geometry.size)
                }
                lassoPath(in: geometry.size)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .onTapGesture { location in viewModel.toggleFace(at: unit(location, in: geometry.size)) }
            .gesture(
                DragGesture(minimumDistance: lassoThreshold)
                    .onChanged { lasso.append(unit($0.location, in: geometry.size)) }
                    .onEnded { _ in
                        viewModel.selectFaces(insideLasso: lasso)
                        lasso = []
                    })
        }
        .sensoryFeedback(.selection, trigger: viewModel.parameters.unselectedFaces)
    }

    private func marker(index: Int, box: CGRect, in size: CGSize) -> some View {
        let isSelected = viewModel.isFaceSelected(index)
        let diameter = max(box.width * size.width, box.height * size.height) * 1.15
        return ZStack(alignment: .topTrailing) {
            Circle()
                .fill(isSelected ? Color.clear : Color.black.opacity(0.35))
                .overlay {
                    Circle().strokeBorder(isSelected ? Theme.accent : Color.white.opacity(0.7),
                                          style: StrokeStyle(lineWidth: isSelected ? 3 : 1.5,
                                                             dash: isSelected ? [] : [5, 4]))
                }
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(isSelected ? Theme.accent : Color.white.opacity(0.8))
                .background(Circle().fill(Color.black.opacity(0.4)))
                .offset(x: 4, y: -4)
        }
        .frame(width: diameter, height: diameter)
        .position(x: box.midX * size.width, y: box.midY * size.height)
        // 位置の判定は、写真全体のタップで行う。目印は見た目だけ。
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("people.faceLabel \(index + 1)"))
        .accessibilityValue(isSelected ? Text("people.selected") : Text("people.notSelected"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { viewModel.toggleFace(index) }
    }

    @ViewBuilder
    private func lassoPath(in size: CGSize) -> some View {
        if lasso.count > 1 {
            Path { path in
                path.addLines(lasso.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) })
            }
            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .allowsHitTesting(false)
        }
    }

    private func unit(_ location: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: location.x / max(size.width, 1), y: location.y / max(size.height, 1))
    }
}
