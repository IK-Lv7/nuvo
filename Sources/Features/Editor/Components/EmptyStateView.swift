import PhotosUI
import SwiftUI

/// 起動直後の画面。何ができるアプリかと、Nuvo の立場(無料・透かしなし・オフライン)を最初に伝える。
struct EmptyStateView: View {
    @Binding var pickerItem: PhotosPickerItem?
    /// コラージュ用に選んだ写真(2〜4枚)。EditorView がこれを見て、組み合わせ方を選ぶ画面を開く。
    @Binding var collageItems: [PhotosPickerItem]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            logo
            VStack(spacing: 8) {
                Text("Nuvo")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                Text("empty.tagline")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("empty.choose", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Theme.brandGradient, in: Capsule())
                    .foregroundStyle(Color.white)
            }
            PhotosPicker(selection: $collageItems, maxSelectionCount: 4, matching: .images) {
                Label("empty.collage", systemImage: "square.grid.2x2")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(PillButtonStyle())
            HStack(spacing: 8) {
                badge("empty.badge.free", "gift")
                badge("empty.badge.noWatermark", "checkmark.seal")
                badge("empty.badge.offline", "wifi.slash")
            }
            Spacer()
            Spacer()
        }
        .padding(Theme.Spacing.l)
    }

    private var logo: some View {
        Text("N")
            .font(.system(size: 56, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.white)
            .frame(width: 104, height: 104)
            .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: Theme.accent.opacity(0.35), radius: 24, y: 10)
            .accessibilityHidden(true)
    }

    private func badge(_ key: LocalizedStringKey, _ symbol: String) -> some View {
        Label(key, systemImage: symbol)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08), in: Capsule())
    }
}
