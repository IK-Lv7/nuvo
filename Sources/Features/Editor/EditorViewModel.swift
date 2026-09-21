import CoreImage
import NuvoCore
import Observation
import PhotosUI
import SwiftUI

/// 調整パラメータと元画像を保持する。元画像は破壊せず、常にここから再生成する。
@MainActor
@Observable
final class EditorViewModel {
    enum SaveResult {
        case saved, denied, failed

        var message: LocalizedStringKey {
            switch self {
            case .saved: "editor.saved"
            case .denied: "editor.saveDenied"
            case .failed: "editor.saveFailed"
            }
        }
    }

    struct ShareItem: Identifiable { let id = UUID(); let url: URL }
    struct BatchProgress { var done: Int; var total: Int }
    struct BatchSummary { var saved: Int; var total: Int }

    private(set) var previewImage: CGImage?
    private(set) var originalPreview: CGImage?
    private(set) var parameters = AdjustmentParameters()
    private(set) var saveResult: SaveResult?
    private(set) var isSaving = false
    /// 写真を読み込むたびに増える。読み込み直後のヒント表示や、拡大状態のリセットのきっかけに使う。
    private(set) var imageRevision = 0
    /// 自動検出で見つかった件数。まだ実行していなければ nil。
    private(set) var autoHealCount: Int?
    /// 証明写真の規格に収まらない(顔が見つからない・余白が足りない)とき true。
    private(set) var idPhotoUnavailable = false
    /// 人物の切り抜きができているか。背景の効果はこれが true のときだけ効く。
    private(set) var hasSubjectMask = false
    /// ポートレート写真の深度が使えるか。使えると、背景のぼかしが奥行きに沿う。
    private(set) var hasDepthMask = false
    private(set) var selectedTextID: UUID?
    private(set) var batchProgress: BatchProgress?
    private(set) var lastBatch: BatchSummary?
    private(set) var shareItem: ShareItem?
    var isComparing = false

    private var history = UndoHistory(initial: AdjustmentParameters())
    private var fullImage: CIImage?
    private var previewSource: RenderSource?
    private var analysis: PhotoAnalysis?
    private var sourceMetadata: [String: Any] = [:]
    private var renderTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private let renderer = ImageRenderer()

    var hasImage: Bool { fullImage != nil }
    var canUndo: Bool { history.canUndo }
    var canRedo: Bool { history.canRedo }
    /// 比較中は元画像を、それ以外は加工結果を表示する。
    var displayedImage: CGImage? { isComparing ? originalPreview : previewImage }

    /// 構図を変えている間は、タップでの修復位置が最終画像の座標とずれるため使えない。
    var hasComposition: Bool {
        let p = parameters
        return p.rotationQuarterTurns != 0 || p.flipHorizontal || p.straighten != 0 || p.cropAspect != nil
            || p.cropZoom != 1 || p.idPhoto != nil
    }

    var selectedText: TextOverlay? {
        parameters.texts.first { $0.id == selectedTextID } ?? parameters.texts.first
    }

    func load(data: Data) {
        guard let image = renderer.loadImage(from: data) else { return }
        let preview = renderer.downscaled(image)
        fullImage = image
        analysis = nil
        sourceMetadata = renderer.readMetadata(from: data)
        previewSource = renderer.makeSource(image: preview)
        originalPreview = renderer.cgImage(from: preview)
        history = UndoHistory(initial: AdjustmentParameters())
        parameters = AdjustmentParameters()
        selectedTextID = nil
        saveResult = nil
        hasSubjectMask = false
        hasDepthMask = false
        autoHealCount = nil
        idPhotoUnavailable = false
        imageRevision += 1
        scheduleRender()

        // 顔検出・切り抜き・深度・肌の事前計算は重いため、画像を先に表示してから裏で行う。
        analysisTask?.cancel()
        analysisTask = Task { await analyze(preview: preview, data: data) }
    }

    func value(for keyPath: WritableKeyPath<AdjustmentParameters, Double>) -> Double {
        parameters[keyPath: keyPath]
    }

    /// スライダー操作中に呼ぶ。履歴には積まず、プレビューだけ更新する。
    func setValue(_ value: Double, for keyPath: WritableKeyPath<AdjustmentParameters, Double>) {
        parameters[keyPath: keyPath] = value
        scheduleRender()
    }

    /// 指を離した時点で呼ぶ。1回の操作を1つの Undo 単位にする。
    func commitEdit() {
        history.commit(parameters)
    }

    /// フィルターや背景色のような、1回の操作で確定する変更。
    func update(_ change: (inout AdjustmentParameters) -> Void) {
        change(&parameters)
        scheduleRender()
        commitEdit()
        refreshIDPhotoAvailability()
    }

    func setFilter(_ preset: FilterPreset?) {
        update { $0.filter = preset }
    }

    /// 証明写真を選ぶ。背景が無地でなければ、規格で一般的な白にする。
    func setIDPhoto(_ spec: IDPhotoSpec?) {
        update {
            $0.idPhoto = spec
            if spec != nil, $0.backgroundColor == nil { $0.backgroundColor = .white }
        }
    }

    /// 保存したルックを当てる。この写真の修復位置・構図・文字は保つ。
    func applyLook(_ look: AdjustmentParameters) {
        update { $0 = $0.applyingLook(look) }
    }

    // MARK: 修復

    /// `unit` は表示中の画像に対する相対位置(0...1、左上原点)。
    func addSpot(at unit: CGPoint) {
        guard hasImage, !hasComposition else { return }
        parameters.spots.append(HealSpot(center: unit))
        scheduleRender()
        commitEdit()
    }

    /// 肌の中のニキビ・シミらしい箇所を見つけて、まとめて修復する(1回の Undo で戻せる)。
    func autoRemoveBlemishes() {
        let found = previewSource?.detectBlemishes() ?? []
        // すでに修復済みの近くは重複して追加しない。
        let added = found.filter { candidate in
            !parameters.spots.contains { hypot($0.center.x - candidate.center.x, $0.center.y - candidate.center.y) < 0.01 }
        }
        autoHealCount = added.count
        guard !added.isEmpty else { return }
        parameters.spots.append(contentsOf: added)
        scheduleRender()
        commitEdit()
    }

    // MARK: 構図

    /// ズーム中の切り出し範囲を動かす。`delta` は表示中の画像の大きさに対する、指の移動量(0...1)。
    /// 指を右へ動かすと、写真が右へ動いて見えるので、切り出す範囲の中心は左へ動く。
    /// 表示は範囲(1/ズーム)を画面いっぱいに拡大しているため、動く量も 1/ズーム になる。
    func moveCrop(byUnit delta: CGSize) {
        let zoom = max(parameters.cropZoom, 1)
        let half = 0.5 / zoom
        var center = parameters.cropCenter
        center.x = min(max(center.x - delta.width / zoom, half), 1 - half)
        center.y = min(max(center.y - delta.height / zoom, half), 1 - half)
        parameters.cropCenter = center
        scheduleRender()
    }

    // MARK: 文字

    func addText() {
        let text = TextOverlay()
        parameters.texts.append(text)
        selectedTextID = text.id
        scheduleRender()
        commitEdit()
    }

    func selectText(_ id: UUID) {
        selectedTextID = id
    }

    func removeSelectedText() {
        guard let id = selectedText?.id else { return }
        parameters.texts.removeAll { $0.id == id }
        selectedTextID = parameters.texts.first?.id
        scheduleRender()
        commitEdit()
    }

    /// 入力中・ドラッグ中は `commit: false` で履歴に積まず、確定のときに `commitEdit()` を呼ぶ。
    func updateSelectedText(commit: Bool = true, _ change: (inout TextOverlay) -> Void) {
        guard let id = selectedText?.id, let index = parameters.texts.firstIndex(where: { $0.id == id }) else { return }
        change(&parameters.texts[index])
        scheduleRender()
        if commit { commitEdit() }
    }

    /// `unit` は表示中の画像に対する相対位置(0...1、左上原点)。
    func moveSelectedText(to unit: CGPoint) {
        let clamped = CGPoint(x: min(max(unit.x, 0), 1), y: min(max(unit.y, 0), 1))
        updateSelectedText(commit: false) { $0.center = clamped }
    }

    // MARK: 履歴

    func undo() {
        history.undo()
        parameters = history.current
        scheduleRender()
        refreshIDPhotoAvailability()
    }

    func redo() {
        history.redo()
        parameters = history.current
        scheduleRender()
        refreshIDPhotoAvailability()
    }

    func dismissSaveResult() {
        saveResult = nil
    }

    // MARK: 書き出し

    /// フル解像度で再処理して写真ライブラリに保存する。
    func save() async {
        // 処理中の再入は失敗ではなく、単に無視する。
        guard !isSaving else { return }
        guard let exported = await export() else {
            saveResult = .failed
            return
        }
        do {
            try await PhotoExporter.save(imageData: exported.data, format: exported.format)
            saveResult = .saved
        } catch PhotoExporterError.notAuthorized {
            saveResult = .denied
        } catch {
            saveResult = .failed
        }
    }

    /// 書き出した写真を一時ファイルにして、共有シートへ渡す。送信は OS の共有シートが行う。
    func prepareShare() async {
        guard !isSaving else { return }
        guard let exported = await export() else {
            saveResult = .failed
            return
        }
        let name = "Nuvo-\(Int(Date().timeIntervalSince1970)).\(exported.format.fileExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try exported.data.write(to: url, options: .atomic)
            shareItem = ShareItem(url: url)
        } catch {
            saveResult = .failed
        }
    }

    /// 共有シートを閉じたら、一時ファイルを消す。
    func clearShare() {
        if let url = shareItem?.url { try? FileManager.default.removeItem(at: url) }
        shareItem = nil
    }

    /// 設定の形式・画質・位置情報の扱いで、フル解像度の写真を書き出す。
    private func export() async -> (data: Data, format: ExportFormat)? {
        guard let fullImage, !isSaving else { return nil }
        isSaving = true
        defer { isSaving = false }
        let parameters = parameters
        let analysis = analysis
        let metadata = sourceMetadata
        let strip = AppSettings.stripLocation
        let format = AppSettings.exportFormat
        let quality = AppSettings.exportQuality
        let renderer = renderer
        return await Task.detached(priority: .userInitiated) { () -> (data: Data, format: ExportFormat)? in
            let source = renderer.makeSource(image: fullImage, faces: analysis?.faces ?? [],
                                             subjectMask: analysis?.subjectMask, depthMask: analysis?.depthMask)
            return renderer.encodedData(source, parameters: parameters, format: format, quality: quality,
                                        metadata: metadata, stripLocation: strip)
        }.value
    }

    /// 選んだ複数の写真に、ルックを当てて保存する。写真ごとに解析するので時間がかかる。
    func applyToPhotos(_ items: [PhotosPickerItem], look: AdjustmentParameters) async {
        guard !items.isEmpty, batchProgress == nil else { return }
        let renderer = renderer
        let strip = AppSettings.stripLocation
        let format = AppSettings.exportFormat
        let quality = AppSettings.exportQuality
        let parameters = AdjustmentParameters().applyingLook(look)
        var saved = 0
        batchProgress = BatchProgress(done: 0, total: items.count)

        for (index, item) in items.enumerated() {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let exported = await Task.detached(priority: .userInitiated) { () -> (data: Data, format: ExportFormat)? in
                    guard let image = renderer.loadImage(from: data) else { return nil }
                    let analysis = PhotoAnalyzer.analyze(preview: renderer.downscaled(image), data: data, renderer: renderer)
                    let source = renderer.makeSource(image: image, faces: analysis.faces,
                                                     subjectMask: analysis.subjectMask, depthMask: analysis.depthMask)
                    return renderer.encodedData(source, parameters: parameters, format: format, quality: quality,
                                                metadata: renderer.readMetadata(from: data), stripLocation: strip)
                }.value
                if let exported, (try? await PhotoExporter.save(imageData: exported.data, format: exported.format)) != nil {
                    saved += 1
                }
            }
            batchProgress = BatchProgress(done: index + 1, total: items.count)
        }
        batchProgress = nil
        lastBatch = BatchSummary(saved: saved, total: items.count)
    }

    // MARK: 内部

    private func analyze(preview: CIImage, data: Data) async {
        let renderer = renderer
        let result = await Task.detached(priority: .userInitiated) { () -> (PhotoAnalysis, RenderSource) in
            let analysis = PhotoAnalyzer.analyze(preview: preview, data: data, renderer: renderer)
            let source = renderer.makeSource(image: preview, faces: analysis.faces,
                                             subjectMask: analysis.subjectMask, depthMask: analysis.depthMask)
            return (analysis, source)
        }.value
        guard !Task.isCancelled else { return }
        analysis = result.0
        hasSubjectMask = result.0.subjectMask != nil
        hasDepthMask = result.0.depthMask != nil
        previewSource = result.1
        scheduleRender()
        refreshIDPhotoAvailability()
    }

    private func refreshIDPhotoAvailability() {
        guard let spec = parameters.idPhoto else {
            idPhotoUnavailable = false
            return
        }
        idPhotoUnavailable = previewSource?.idPhotoCropRect(spec) == nil
    }

    /// 連続操作では前のレンダリングを捨て、最新のパラメータだけを描画する。
    private func scheduleRender() {
        renderTask?.cancel()
        guard let previewSource else { return }
        let parameters = parameters
        let renderer = renderer
        renderTask = Task {
            let image = await Task.detached(priority: .userInitiated) {
                renderer.render(previewSource, parameters: parameters)
            }.value
            guard !Task.isCancelled else { return }
            previewImage = image
        }
    }
}
