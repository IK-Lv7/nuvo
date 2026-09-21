import SwiftUI

/// 写真の表示領域。ピンチで拡大、ドラッグで移動、ダブルタップで元の大きさに戻る。
/// 長押しで元の写真に切り替わる(業界標準の操作)。
struct CanvasView: View {
    let viewModel: EditorViewModel
    let isHealing: Bool
    let isEditingText: Bool
    /// ズームの範囲を動かしている間(構図のズームを選択中で、1 倍より大きい)。
    let isMovingCrop: Bool
    /// 「加工する人」を選んでいる間。顔に目印を出し、タップで入り切り、指で囲んで選べる。
    var isSelectingPeople = false
    let showsHint: Bool

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @State private var lastCropTranslation: CGSize = .zero

    /// 拡大の上限。プレビューは長辺 1536px のため、これ以上は粗く見える。
    private let maxScale: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image = viewModel.displayedImage {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay { interactionLayer }
                        .scaleEffect(scale)
                        .offset(offset)
                        .accessibilityLabel(Text("editor.photo"))
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .clipped()
            .gesture(zoomGesture(in: proxy.size))
            .simultaneousGesture(panGesture(in: proxy.size))
            .onTapGesture(count: 2) { if !isHealing && !isEditingText && !isMovingCrop && !isSelectingPeople { resetZoom() } }
            .onLongPressGesture(minimumDuration: 0.3, perform: {}, onPressingChanged: { pressing in
                viewModel.isComparing = pressing
            })
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) { caption }
        .animation(.easeOut(duration: 0.15), value: viewModel.isComparing)
    }

    // MARK: ジェスチャー

    private func zoomGesture(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(baseScale * value.magnification, 1), maxScale)
                offset = clamped(offset, in: size)
            }
            .onEnded { _ in
                baseScale = scale
                if scale <= 1 { resetZoom() } else { baseOffset = offset }
            }
    }

    /// 拡大しているときだけ動かせる。文字の編集中は、ドラッグを文字の移動に使う。
    private func panGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1, !isEditingText, !isHealing, !isMovingCrop, !isSelectingPeople else { return }
                offset = clamped(CGSize(width: baseOffset.width + value.translation.width,
                                        height: baseOffset.height + value.translation.height), in: size)
            }
            .onEnded { _ in baseOffset = offset }
    }

    /// 写真の端が、表示領域の内側まで入り込まないようにする。
    private func clamped(_ value: CGSize, in size: CGSize) -> CGSize {
        let limitX = (scale - 1) * size.width / 2
        let limitY = (scale - 1) * size.height / 2
        return CGSize(width: min(max(value.width, -limitX), limitX), height: min(max(value.height, -limitY), limitY))
    }

    private func resetZoom() {
        withAnimation(.easeOut(duration: 0.2)) {
            scale = 1
            baseScale = 1
            offset = .zero
            baseOffset = .zero
        }
    }

    // MARK: 写真の上の操作

    /// 修復モードではタップ、文字の編集中はドラッグで、位置を画像内の相対座標にして渡す。
    /// 拡大・移動の内側に置くので、拡大中でも座標は写真に対する位置になる。
    @ViewBuilder
    private var interactionLayer: some View {
        if isHealing {
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        viewModel.addSpot(at: unit(location, in: geometry.size))
                    }
            }
        } else if isMovingCrop {
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let step = CGSize(width: value.translation.width - lastCropTranslation.width,
                                                  height: value.translation.height - lastCropTranslation.height)
                                lastCropTranslation = value.translation
                                viewModel.moveCrop(byUnit: CGSize(width: step.width / max(geometry.size.width, 1),
                                                                  height: step.height / max(geometry.size.height, 1)))
                            }
                            .onEnded { _ in
                                lastCropTranslation = .zero
                                viewModel.commitEdit()
                            })
            }
        } else if isSelectingPeople {
            PeopleOverlay(viewModel: viewModel)
        } else if isEditingText {
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { viewModel.moveSelectedText(to: unit($0.location, in: geometry.size)) }
                            .onEnded { _ in viewModel.commitEdit() })
            }
        }
    }

    private func unit(_ location: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: location.x / max(size.width, 1), y: location.y / max(size.height, 1))
    }

    // MARK: 表示

    @ViewBuilder
    private var caption: some View {
        if viewModel.isComparing {
            chip("editor.original")
        } else if showsHint {
            chip("editor.holdHint")
        }
    }

    private func chip(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 8)
            .transition(.opacity)
    }
}
