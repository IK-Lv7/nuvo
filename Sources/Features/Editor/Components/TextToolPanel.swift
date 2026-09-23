import NuvoCore
import SwiftUI

/// 文字の追加・編集。位置は、写真の上をドラッグして動かす。
struct TextToolPanel: View {
    let viewModel: EditorViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                header
                if let text = viewModel.selectedText {
                    field(text)
                    ColorPresetRow(
                        presets: TextColorPreset.allCases,
                        tint: { $0.tint },
                        title: { LocalizedStringKey.dynamic("textColor." + $0.rawValue) },
                        selected: text.color,
                        onSelectPreset: { color in viewModel.updateSelectedText { $0.color = color } },
                        customBinding: colorPickerBinding(current: text.color) { color in
                            viewModel.updateSelectedText { $0.color = color }
                        })
                    ChipStrip(items: TextStyle.allCases, selected: text.style,
                              title: { LocalizedStringKey.dynamic("textStyle." + $0.rawValue) },
                              noneTitle: "", showsNone: false,
                              // 各書体の名前を、その書体で見せる。
                              itemFont: { style in style.previewFontName.map { .custom($0, size: 15) } }) { style in
                        if let style { viewModel.updateSelectedText { $0.style = style } }
                    }
                    HStack(spacing: 10) {
                        toggle("editor.bold", isOn: text.isBold) { viewModel.updateSelectedText { $0.isBold.toggle() } }
                        toggle("editor.shadow", isOn: text.hasShadow) { viewModel.updateSelectedText { $0.hasShadow.toggle() } }
                        Spacer()
                    }
                    TrackSlider(
                        value: Binding(get: { text.size },
                                       set: { size in viewModel.updateSelectedText(commit: false) { $0.size = size } }),
                        range: TextOverlay.sizeRange,
                        onEditingEnded: { viewModel.commitEdit() })
                    Text("editor.textHint").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { viewModel.addText() } label: { Label("editor.addText", systemImage: "plus") }
                .buttonStyle(PillButtonStyle())
            ForEach(Array(viewModel.parameters.texts.enumerated()), id: \.element.id) { index, text in
                Button { viewModel.selectText(text.id) } label: { Text("\(index + 1)") }
                    .buttonStyle(PillButtonStyle(isOn: text.id == viewModel.selectedText?.id))
            }
            Spacer()
            if viewModel.selectedText != nil {
                Button { viewModel.removeSelectedText() } label: { Image(systemName: "trash") }
                    .buttonStyle(PillButtonStyle())
                    .accessibilityLabel(Text("editor.deleteText"))
            }
        }
    }

    private func field(_ text: TextOverlay) -> some View {
        TextField("editor.textPlaceholder",
                  text: Binding(get: { text.text },
                                set: { value in viewModel.updateSelectedText(commit: false) { $0.text = value } }),
                  axis: .vertical)
            .focused($isFocused)
            .lineLimit(1...3)
            .padding(10)
            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            // 複数行の入力では確定キーが改行になるため、入力欄から外れたときに履歴へ積む。
            .onChange(of: isFocused) { _, focused in
                if !focused { viewModel.commitEdit() }
            }
    }

    private func toggle(_ title: LocalizedStringKey, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title) }
            .buttonStyle(PillButtonStyle(isOn: isOn))
    }
}
