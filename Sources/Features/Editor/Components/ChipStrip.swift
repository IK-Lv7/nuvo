import SwiftUI

/// 横に並べた選択肢。先頭の「なし」で解除する(フィルター・背景色・証明写真で共通)。
struct ChipStrip<Item: Hashable>: View {
    let items: [Item]
    let selected: Item?
    let title: (Item) -> LocalizedStringKey
    let noneTitle: LocalizedStringKey
    /// false にすると先頭の「なし」を出さない(必ずどれかを選ぶ項目用)。
    var showsNone = true
    /// 選択肢ごとのフォント(書体の見本表示用)。nil なら既定のフォント。
    var itemFont: (Item) -> Font? = { _ in nil }
    let onSelect: (Item?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if showsNone {
                    chip(noneTitle, isSelected: selected == nil, font: nil) { onSelect(nil) }
                }
                ForEach(items, id: \.self) { item in
                    chip(title(item), isSelected: selected == item, font: itemFont(item)) { onSelect(item) }
                }
            }
        }
        .scrollClipDisabled()
    }

    private func chip(_ title: LocalizedStringKey, isSelected: Bool, font: Font?, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(font) }
            .buttonStyle(PillButtonStyle(isOn: isSelected))
    }
}
