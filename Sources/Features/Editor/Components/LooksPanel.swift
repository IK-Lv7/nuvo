import NuvoCore
import PhotosUI
import SwiftUI

/// ルック(調整値のまとまり)の保存・適用。複数の写真へまとめて当てて保存もできる。
struct LooksPanel: View {
    let viewModel: EditorViewModel
    let store: LookStore
    @State private var isNaming = false
    @State private var newName = ""
    @State private var selectedID: UUID?
    @State private var pickedItems: [PhotosPickerItem] = []

    private var selectedLook: LookStore.Look? {
        store.looks.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { newName = ""; isNaming = true } label: { Label("editor.saveLook", systemImage: "plus") }
                    .buttonStyle(PillButtonStyle())
                PhotosPicker(selection: $pickedItems, maxSelectionCount: 20, matching: .images) {
                    Label("editor.applyToPhotos", systemImage: "photo.stack")
                }
                .buttonStyle(PillButtonStyle())
                .disabled(selectedLook == nil || viewModel.batchProgress != nil)
                .opacity(selectedLook == nil ? 0.5 : 1)
            }
            looksRow
            status
        }
        .alert("editor.lookName", isPresented: $isNaming) {
            TextField("editor.lookNamePlaceholder", text: $newName)
            Button("editor.saveLook") { store.save(name: newName, parameters: viewModel.parameters) }
            Button("editor.cancel", role: .cancel) {}
        }
        .onChange(of: pickedItems) { _, items in
            guard !items.isEmpty, let look = selectedLook else { return }
            pickedItems = []
            Task { await viewModel.applyToPhotos(items, look: look.parameters) }
        }
    }

    @ViewBuilder
    private var looksRow: some View {
        if store.looks.isEmpty {
            Text("editor.noLooks").font(.footnote).foregroundStyle(.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.looks) { look in
                        Button {
                            selectedID = look.id
                            viewModel.applyLook(look.parameters)
                        } label: { Text(look.name) }
                            .buttonStyle(PillButtonStyle(isOn: look.id == selectedID))
                            .contextMenu {
                                Button(role: .destructive) { store.delete(look) } label: {
                                    Label("editor.deleteLook", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        if let progress = viewModel.batchProgress {
            HStack(spacing: 8) {
                ProgressView().tint(.white)
                Text("editor.batchProgress \(progress.done) \(progress.total)").font(.footnote)
            }
        } else if let summary = viewModel.lastBatch {
            Text("editor.batchDone \(summary.saved) \(summary.total)").font(.footnote).foregroundStyle(.secondary)
        }
    }
}
