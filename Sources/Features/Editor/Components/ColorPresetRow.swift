import NuvoCore
import SwiftUI

/// 色見本と、カラーコードで選べる「その他の色」の横並び一覧。色を選ぶだけで、濃さは別のスライダーで扱う。
/// リップ・チークなど、色を選べるメイク項目で共通に使う(ChipStrip と同じ、呼び出し側が一覧を渡す形)。
struct ColorPresetRow<Preset: Hashable>: View {
    let presets: [Preset]
    /// 見本の色。
    let tint: (Preset) -> MakeupTint
    /// 見本のラベルに使うローカライズキー("lipstick." + rawValue など)。
    let title: (Preset) -> LocalizedStringKey
    let selected: MakeupTint
    let onSelectPreset: (MakeupTint) -> Void
    /// 「その他の色」を開いたときの、標準の色選択画面(カラーコードの入力も含む)。
    let customBinding: Binding<Color>

    private var matchingPreset: Preset? {
        presets.first { tint($0) == selected }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(presets, id: \.self) { preset in
                    swatch(color: tint(preset), isSelected: matchingPreset == preset) {
                        onSelectPreset(tint(preset))
                    } label: {
                        Text(title(preset))
                    }
                }
                // 見本のどれとも一致しない色(=カラーコードで選んだ色)は、その他の欄に反映する。
                ColorPicker(selection: customBinding, supportsOpacity: false) {
                    swatchCircle(color: matchingPreset == nil ? selected : nil, isSelected: matchingPreset == nil)
                }
                .labelsHidden()
                .frame(width: 40, height: 40)
            }
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
    }

    private func swatch(color: MakeupTint, isSelected: Bool, action: @escaping () -> Void,
                        label: () -> Text) -> some View {
        VStack(spacing: 4) {
            Button(action: action) { swatchCircle(color: color, isSelected: isSelected) }
                .buttonStyle(.plain)
            label().font(.caption2).foregroundStyle(isSelected ? Color.white : Color.secondary)
        }
    }

    @ViewBuilder
    private func swatchCircle(color: MakeupTint?, isSelected: Bool) -> some View {
        // カラーコードのボタンは、まだ何も選んでいない見た目(点線の円)からはじめる。
        let fill = color.map { Color(red: $0.red, green: $0.green, blue: $0.blue) }
        Circle()
            .fill(fill ?? Color.clear)
            .overlay {
                if fill == nil {
                    Image(systemName: "eyedropper").font(.system(size: 14)).foregroundStyle(Color.white)
                }
            }
            .overlay {
                Circle().strokeBorder(isSelected ? Theme.accent : Color.white.opacity(0.3),
                                     style: StrokeStyle(lineWidth: isSelected ? 3 : (fill == nil ? 1.5 : 1),
                                                        dash: fill == nil ? [4, 3] : []))
            }
            .frame(width: 40, height: 40)
    }
}

/// `ColorPresetRow.customBinding` 用の、色を選べるどの画面でも同じ変換をする Binding。
/// SwiftUI の `Color` ⇔ `MakeupTint` の行き来をここに集約する
/// (リップ・チーク・アイシャドウ・カラコン・文字入れ・スタンプ、すべてこれを使う)。
func colorPickerBinding(current: MakeupTint, apply: @escaping (MakeupTint) -> Void) -> Binding<Color> {
    Binding(
        get: { Color(red: current.red, green: current.green, blue: current.blue) },
        set: { color in
            guard let rgb = color.srgbComponents() else { return }
            apply(MakeupTint(red: rgb.red, green: rgb.green, blue: rgb.blue))
        })
}
