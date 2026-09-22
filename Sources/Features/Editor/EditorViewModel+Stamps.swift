import CoreGraphics
import NuvoCore

/// スタンプ(SF Symbols)の追加・選択・移動。文字入れ(TextOverlay)と同じ考え方で、
/// 位置のドラッグ中は Undo に積まず、指を離した時点で1回分の操作にする。
extension EditorViewModel {
    var selectedStamp: StampOverlay? {
        parameters.stamps?.first { $0.id == selectedStampID } ?? parameters.stamps?.first
    }

    /// `symbolName` は SF Symbols の名前("heart.fill" など)。新しいスタンプとして追加し、選択状態にする。
    func addStamp(_ symbolName: String) {
        let stamp = StampOverlay(symbolName: symbolName)
        mutateWithoutCommitting { p in p.stamps = (p.stamps ?? []) + [stamp] }
        selectStamp(stamp.id)
        commitEdit()
    }

    func selectStamp(_ id: UUID) {
        selectedStampID = id
    }

    func removeSelectedStamp() {
        guard let id = selectedStamp?.id else { return }
        mutateWithoutCommitting { p in p.stamps?.removeAll { $0.id == id } }
        selectedStampID = parameters.stamps?.first?.id
        commitEdit()
    }

    /// 入力中・ドラッグ中は `commit: false` で履歴に積まず、確定のときに `commitEdit()` を呼ぶ。
    func updateSelectedStamp(commit: Bool = true, _ change: (inout StampOverlay) -> Void) {
        guard let id = selectedStamp?.id else { return }
        mutateWithoutCommitting { p in
            guard var stamps = p.stamps, let index = stamps.firstIndex(where: { $0.id == id }) else { return }
            change(&stamps[index])
            p.stamps = stamps
        }
        if commit { commitEdit() }
    }

    /// `unit` は表示中の画像に対する相対位置(0...1、左上原点)。
    func moveSelectedStamp(to unit: CGPoint) {
        let clamped = CGPoint(x: min(max(unit.x, 0), 1), y: min(max(unit.y, 0), 1))
        updateSelectedStamp(commit: false) { $0.center = clamped }
    }
}
