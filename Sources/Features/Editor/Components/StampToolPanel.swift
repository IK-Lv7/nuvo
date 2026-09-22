import NuvoCore
import SwiftUI

/// スタンプ(SF Symbols)の追加・選択・編集。位置は、写真の上をドラッグして動かす。
struct StampToolPanel: View {
    let viewModel: EditorViewModel

    private var stamps: [StampOverlay] { viewModel.parameters.stamps ?? [] }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                palette
                if !stamps.isEmpty { header }
                if let stamp = viewModel.selectedStamp {
                    ChipStrip(items: TextColor.allCases, selected: stamp.color,
                              title: { LocalizedStringKey.dynamic("textColor." + $0.rawValue) },
                              noneTitle: "", showsNone: false) { color in
                        if let color { viewModel.updateSelectedStamp { $0.color = color } }
                    }
                    TrackSlider(
                        value: Binding(get: { stamp.size },
                                       set: { size in viewModel.updateSelectedStamp(commit: false) { $0.size = size } }),
                        range: StampOverlay.sizeRange,
                        onEditingEnded: { viewModel.commitEdit() })
                    Text("editor.stampHint").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// タップすると、その見た目のスタンプを新しく追加する(すでにあるスタンプの見た目は変えない)。
    private var palette: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(StampSymbol.allCases, id: \.self) { symbol in
                    Button { viewModel.addStamp(symbol.symbolName) } label: {
                        Image(systemName: symbol.symbolName)
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.09)))
                            .foregroundStyle(Color.white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(LocalizedStringKey.dynamic("stamp." + symbol.rawValue)))
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
    }

    private var header: some View {
        HStack(spacing: 10) {
            ForEach(stamps) { stamp in
                Button { viewModel.selectStamp(stamp.id) } label: { Image(systemName: stamp.symbolName) }
                    .buttonStyle(PillButtonStyle(isOn: stamp.id == viewModel.selectedStamp?.id))
            }
            Spacer()
            if viewModel.selectedStamp != nil {
                Button { viewModel.removeSelectedStamp() } label: { Image(systemName: "trash") }
                    .buttonStyle(PillButtonStyle())
                    .accessibilityLabel(Text("editor.deleteStamp"))
            }
        }
    }
}
