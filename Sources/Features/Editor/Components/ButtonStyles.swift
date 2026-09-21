import SwiftUI

/// 選択肢・操作ボタンの共通の見た目。
struct PillButtonStyle: ButtonStyle {
    var isOn = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                Capsule().fill(isOn ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Color.white.opacity(0.12)))
            }
            .foregroundStyle(Color.white)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// 上部バーの丸いアイコンボタン。
struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .frame(width: 40, height: 40)
            .background(.ultraThinMaterial, in: Circle())
            .foregroundStyle(Color.white)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
