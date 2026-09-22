import NuvoCore
import SwiftUI

/// スタンプ(SF Symbols・同梱の絵文字画像)の追加・選択・編集。位置は、写真の上をドラッグして動かす。
struct StampToolPanel: View {
    let viewModel: EditorViewModel

    private var stamps: [StampOverlay] { viewModel.parameters.stamps ?? [] }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                emojiPalette
                symbolPalette
                if !stamps.isEmpty { header }
                if let stamp = viewModel.selectedStamp {
                    // 絵文字画像にはすでに色がついているため、色は SF Symbols のスタンプにだけ効く。
                    if stamp.imageAssetName == nil {
                        ChipStrip(items: TextColor.allCases, selected: stamp.color,
                                  title: { LocalizedStringKey.dynamic("textColor." + $0.rawValue) },
                                  noneTitle: "", showsNone: false) { color in
                            if let color { viewModel.updateSelectedStamp { $0.color = color } }
                        }
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
    private var emojiPalette: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(EmojiStamp.allCases, id: \.self) { emoji in
                    Button { viewModel.addEmojiStamp(emoji) } label: {
                        emojiThumbnail(emoji.assetName, size: 32)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.09)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(LocalizedStringKey.dynamic("stamp." + emoji.rawValue)))
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
    }

    private var symbolPalette: some View {
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
                Button { viewModel.selectStamp(stamp.id) } label: { stampThumbnail(stamp) }
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

    @ViewBuilder
    private func stampThumbnail(_ stamp: StampOverlay) -> some View {
        if let assetName = stamp.imageAssetName {
            emojiThumbnail(assetName, size: 18)
        } else {
            Image(systemName: stamp.symbolName)
        }
    }

    @ViewBuilder
    private func emojiThumbnail(_ assetName: String, size: CGFloat) -> some View {
        // パレット・一覧どちらも小さな表示なので、都度その大きさでラスタライズすれば十分(EmojiStampRenderer が結果を使い回す)。
        if let cgImage = EmojiStampRenderer.image(assetName: assetName, pointSize: size * 2) {
            Image(decorative: cgImage, scale: 2).resizable().aspectRatio(contentMode: .fit).frame(width: size, height: size)
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }
}
