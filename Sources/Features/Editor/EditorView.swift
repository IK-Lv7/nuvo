import NuvoCore
import PhotosUI
import SwiftUI

/// 編集画面。写真を主役にし、下部のツールバーで「カテゴリ → ツール → 値」の順に絞り込む。
struct EditorView: View {
    @State private var viewModel = EditorViewModel()
    @State private var pickerItem: PhotosPickerItem?
    @State private var categoryID = EditorCatalog.categories[0].id
    @State private var toolID = EditorCatalog.categories[0].tools[0].id
    @State private var isHealing = false
    @State private var cutoutMode: MaskStroke.Mode = .keep
    @State private var cutoutBrushRadius: Double = 0.05
    @State private var showsHint = false
    @State private var showsSettings = false
    @State private var lookStore = LookStore()

    /// 「加工する人」は、2 人以上が写っているときだけ出す。
    private var categories: [ToolCategory] {
        EditorCatalog.categories.filter { $0.id != "people" || viewModel.hasSeveralFaces }
    }

    private var category: ToolCategory {
        categories.first { $0.id == categoryID } ?? categories[0]
    }

    /// 顔の目印を出して、タップ・囲みで加工する人を選べる状態。構図を変えていると、顔の位置が合わないので使えない。
    private var isSelectingPeople: Bool {
        tool.id == "people" && viewModel.hasSeveralFaces && !viewModel.hasComposition
    }

    private var tool: EditorTool {
        category.tools.first { $0.id == toolID } ?? category.tools[0]
    }

    /// 文字の編集中は、写真の上のドラッグで文字を動かす。
    private var isEditingText: Bool {
        if case .text = tool.kind { return viewModel.selectedText != nil }
        return false
    }

    /// スタンプの編集中は、写真の上のドラッグでスタンプを動かす。
    private var isEditingStamp: Bool {
        if case .stamp = tool.kind { return viewModel.selectedStamp != nil }
        return false
    }

    /// 構図のズームを選んでいて、1 倍より大きいとき、写真の上のドラッグで切り出す範囲を動かす。
    private var isMovingCrop: Bool {
        tool.id == "cropZoom" && viewModel.parameters.cropZoom > 1
    }

    /// 「切り抜きを直す」ペンを、写真の上で使っている状態。
    private var isFixingCutout: Bool {
        tool.id == "backgroundCutout" && viewModel.canFixCutout
    }

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            if viewModel.hasImage {
                editor
            } else {
                EmptyStateView(pickerItem: $pickerItem)
                    .overlay(alignment: .topTrailing) {
                        Button { showsSettings = true } label: { Image(systemName: "gearshape") }
                            .buttonStyle(IconButtonStyle())
                            .padding(Theme.Spacing.m)
                            .accessibilityLabel(Text("editor.settings"))
                    }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showsSettings) { SettingsView() }
        .sheet(item: Binding(get: { viewModel.shareItem }, set: { if $0 == nil { viewModel.clearShare() } })) { item in
            ShareSheet(url: item.url).presentationDetents([.medium, .large])
        }
        .sensoryFeedback(.selection, trigger: toolID)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                viewModel.load(data: data)
            }
        }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            EditorTopBar(viewModel: viewModel, pickerItem: $pickerItem, onSettings: { showsSettings = true })
            CanvasView(viewModel: viewModel, isHealing: isHealing, isEditingText: isEditingText, isEditingStamp: isEditingStamp,
                       isMovingCrop: isMovingCrop, isSelectingPeople: isSelectingPeople,
                       isFixingCutout: isFixingCutout, cutoutMode: cutoutMode, cutoutBrushRadius: cutoutBrushRadius,
                       showsHint: showsHint)
                .id(viewModel.imageRevision)
            controls
        }
        .overlay(alignment: .top) { toast }
        .animation(.spring(duration: 0.3), value: viewModel.saveResult)
        .task(id: viewModel.imageRevision) {
            showsHint = true
            try? await Task.sleep(for: .seconds(3))
            showsHint = false
        }
        .task(id: viewModel.saveResult) {
            guard viewModel.saveResult != nil else { return }
            try? await Task.sleep(for: .seconds(2.5))
            viewModel.dismissSaveResult()
        }
        .onChange(of: categoryID) { _, _ in
            toolID = category.tools[0].id
        }
        .onChange(of: viewModel.hasSeveralFaces) { _, hasSeveral in
            // 別の写真に替えて 1 人だけになったとき、消えたカテゴリを開いたままにしない。
            if !hasSeveral && categoryID == "people" { categoryID = EditorCatalog.categories[0].id }
        }
        .onChange(of: toolID) { _, _ in
            isHealing = false
        }
    }

    /// 選んだツールの操作部の高さはツールごとに固定し、ツールを切り替えても写真が上下に動かないようにする。
    private var controls: some View {
        VStack(spacing: 14) {
            ToolPanel(tool: tool, viewModel: viewModel, lookStore: lookStore, isHealing: $isHealing,
                      cutoutMode: $cutoutMode, cutoutBrushRadius: $cutoutBrushRadius)
                .frame(height: tool.panelHeight, alignment: .top)
                .padding(.horizontal, Theme.Spacing.l)
            ToolStrip(tools: category.tools, selectedID: $toolID,
                      isModified: { $0.isModified(viewModel.parameters) })
            CategoryBar(categories: categories, selectedID: $categoryID)
        }
        .padding(.top, 14)
        .background(.ultraThinMaterial, ignoresSafeAreaEdges: .bottom)
    }

    @ViewBuilder
    private var toast: some View {
        if let result = viewModel.saveResult {
            Text(result.message)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
