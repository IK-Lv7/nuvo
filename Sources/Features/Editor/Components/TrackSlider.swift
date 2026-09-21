import SwiftUI

/// 独自スライダー。中央がゼロの範囲では、中央から値の方向へ色が伸び、ゼロ付近で吸着して触感を返す。
/// 標準の `Slider` は左端から塗るため、「どちらに何%動かしたか」が見えにくい。
struct TrackSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    /// 指を離した時点で呼ばれる。
    var onEditingEnded: () -> Void = {}

    private let thumbSize: CGFloat = 28
    private let trackHeight: CGFloat = 4
    /// ゼロに吸い付く範囲(全体の幅に対する割合)。狙ってゼロに戻せる程度に小さく取る。
    private let snapRatio = 0.03

    private var isBidirectional: Bool { range.lowerBound < 0 && range.upperBound > 0 }
    private var span: Double { range.upperBound - range.lowerBound }

    private func fraction(_ v: Double) -> CGFloat { CGFloat((v - range.lowerBound) / span) }

    var body: some View {
        GeometryReader { proxy in
            let travel = max(proxy.size.width - thumbSize, 1)
            let position = fraction(value) * travel
            let origin = (isBidirectional ? fraction(0) : 0) * travel

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: trackHeight)
                    .padding(.horizontal, thumbSize / 2)
                Capsule()
                    .fill(Theme.brandGradient)
                    .frame(width: abs(position - origin), height: trackHeight)
                    .offset(x: thumbSize / 2 + min(position, origin))
                if isBidirectional {
                    Capsule()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 2, height: 12)
                        .offset(x: thumbSize / 2 + origin - 1)
                }
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                    .offset(x: position)
            }
            .frame(height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { update(locationX: $0.location.x, travel: travel) }
                    .onEnded { _ in onEditingEnded() })
        }
        .frame(height: 36)
        .sensoryFeedback(.impact(weight: .light), trigger: isBidirectional && value == 0)
        .accessibilityElement()
        .accessibilityValue(Text(Int((value * 100).rounded()), format: .number))
        .accessibilityAdjustableAction { direction in
            let step = span * 0.05
            switch direction {
            case .increment: value = min(value + step, range.upperBound)
            case .decrement: value = max(value - step, range.lowerBound)
            @unknown default: break
            }
            onEditingEnded()
        }
    }

    private func update(locationX: CGFloat, travel: CGFloat) {
        let ratio = min(max((locationX - thumbSize / 2) / travel, 0), 1)
        var newValue = range.lowerBound + Double(ratio) * span
        if isBidirectional, abs(newValue) < span * snapRatio { newValue = 0 }
        value = newValue
    }
}
