import PhotosUI
import SwiftUI

/// 写真の差し替え、Undo/Redo、保存。
struct EditorTopBar: View {
    let viewModel: EditorViewModel
    @Binding var pickerItem: PhotosPickerItem?
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel(Text("editor.changePhoto"))

            Button { viewModel.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .buttonStyle(IconButtonStyle())
                .disabled(!viewModel.canUndo)
                .opacity(viewModel.canUndo ? 1 : 0.4)
                .accessibilityLabel(Text("editor.undo"))
            Button { viewModel.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .buttonStyle(IconButtonStyle())
                .disabled(!viewModel.canRedo)
                .opacity(viewModel.canRedo ? 1 : 0.4)
                .accessibilityLabel(Text("editor.redo"))

            Spacer()

            Button(action: onSettings) { Image(systemName: "gearshape") }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel(Text("editor.settings"))

            Button { Task { await viewModel.prepareShare() } } label: { Image(systemName: "square.and.arrow.up") }
                .buttonStyle(IconButtonStyle())
                .disabled(viewModel.isSaving)
                .accessibilityLabel(Text("editor.share"))

            Button { Task { await viewModel.save() } } label: {
                Group {
                    if viewModel.isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("editor.save")
                    }
                }
                .font(.headline)
                .frame(minWidth: 56)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Theme.brandGradient, in: Capsule())
                .foregroundStyle(Color.white)
            }
            .disabled(viewModel.isSaving)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 8)
    }
}
