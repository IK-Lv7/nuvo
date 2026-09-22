import CoreImage
import NuvoCore
import PhotosUI
import SwiftUI

/// 複数の写真を選んだあとの、組み合わせ方を決める画面。決まったレイアウトから選び、
/// 余白・背景色を調整して、1枚の写真として編集画面へ渡す。
/// プレビューは軽い縮小画像で行い、実際の合成(フル解像度)は「作成」を押したときだけ行う。
struct CollageComposerView: View {
    let items: [PhotosPickerItem]
    let onCompose: (CIImage) -> Void
    let onCancel: () -> Void

    @State private var thumbnails: [UIImage] = []
    @State private var layout: CollageLayout?
    @State private var spacing: Double = 0.02
    @State private var background: BackgroundColor = .white
    @State private var isLoadingThumbnails = true
    @State private var isComposing = false
    @State private var loadFailed = false

    private let renderer = ImageRenderer()

    private var availableLayouts: [CollageLayout] { CollageLayout.layouts(forCount: thumbnails.count) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isLoadingThumbnails {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if loadFailed || layout == nil {
                    Text("collage.loadFailed").foregroundStyle(.secondary).frame(maxHeight: .infinity)
                } else if let layout {
                    preview(layout)
                    layoutPicker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("collage.spacing").font(.footnote).foregroundStyle(.secondary)
                        TrackSlider(value: $spacing, range: 0...0.08, onEditingEnded: {})
                    }
                    ChipStrip(items: BackgroundColor.allCases, selected: background,
                              title: { LocalizedStringKey.dynamic("background." + $0.rawValue) },
                              noneTitle: "", showsNone: false) { color in
                        if let color { background = color }
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(Theme.Spacing.l)
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle(Text("collage.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("collage.cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isComposing {
                        ProgressView()
                    } else {
                        Button("collage.create") { Task { await compose() } }
                            .disabled(layout == nil)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await loadThumbnails() }
    }

    private func preview(_ layout: CollageLayout) -> some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Color(cgColor: background.ciColor.cgColor)
                ForEach(Array(layout.slots.enumerated()), id: \.offset) { index, slot in
                    if thumbnails.indices.contains(index) {
                        let rect = CGRect(x: slot.minX * side, y: slot.minY * side,
                                          width: slot.width * side, height: slot.height * side)
                            .insetBy(dx: side * spacing / 2, dy: side * spacing / 2)
                        Image(uiImage: thumbnails[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: max(rect.width, 0), height: max(rect.height, 0))
                            .clipped()
                            .position(x: rect.midX, y: rect.midY)
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity)
            .animation(.easeOut(duration: 0.15), value: spacing)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var layoutPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(availableLayouts, id: \.self) { option in
                    Button { layout = option } label: {
                        Text(LocalizedStringKey.dynamic("collageLayout." + option.rawValue))
                    }
                    .buttonStyle(PillButtonStyle(isOn: layout == option))
                }
            }
        }
    }

    private func loadThumbnails() async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                images.append(image)
            }
        }
        thumbnails = images
        layout = CollageLayout.layouts(forCount: images.count).first
        loadFailed = layout == nil
        isLoadingThumbnails = false
    }

    /// フル解像度で読み直して合成する。プレビューの縮小画像は使わない(書き出しの画質を保つため)。
    private func compose() async {
        guard let layout else { return }
        isComposing = true
        defer { isComposing = false }
        var images: [CIImage] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = renderer.loadImage(from: data) else { continue }
            images.append(image)
        }
        guard images.count == layout.slotCount else {
            loadFailed = true
            return
        }
        // 出力の大きさは、選んだ写真の中でいちばん大きい長辺に合わせる(上限は時間・メモリを考えて 3000px)。
        let longEdge = min(images.map { max($0.extent.width, $0.extent.height) }.max() ?? 2000, 3000)
        let canvas = CGSize(width: longEdge, height: longEdge)
        guard let composed = CollageComposer.compose(images: images, layout: layout, canvasSize: canvas,
                                                      spacingRatio: spacing, background: background) else {
            loadFailed = true
            return
        }
        onCompose(composed)
    }
}
