import CoreGraphics
import NuvoCore

/// 複数人が写る写真で、加工する人を選ぶ。選んだ結果は調整値に入るので、元に戻す・やり直すの対象になる。
extension EditorViewModel {
    var hasSeveralFaces: Bool { detectedFaces.count >= 2 }

    /// 加工する人として選ばれている顔の番号。
    var selectedFaces: Set<Int> {
        Set(detectedFaces.indices).subtracting(parameters.excludedFaces)
    }

    func isFaceSelected(_ index: Int) -> Bool { selectedFaces.contains(index) }

    /// `unit` は表示中の画像に対する相対位置(0...1、左上原点)。顔の外をタップしても何もしない。
    func toggleFace(at unit: CGPoint) {
        guard let index = FaceSelection.faceIndex(at: unit, in: detectedFaces) else { return }
        toggleFace(index)
    }

    func toggleFace(_ index: Int) {
        guard detectedFaces.indices.contains(index) else { return }
        var kept = selectedFaces
        if kept.contains(index) { kept.remove(index) } else { kept.insert(index) }
        setSelectedFaces(kept)
    }

    /// 指で囲んだ人だけを、加工する人にする。誰も囲めていないときは、今の選択を変えない。
    func selectFaces(insideLasso lasso: [CGPoint]) {
        let inside = Set(FaceSelection.indices(insideLasso: lasso, in: detectedFaces))
        guard !inside.isEmpty else { return }
        setSelectedFaces(inside)
    }

    func selectAllFaces() {
        setSelectedFaces(Set(detectedFaces.indices))
    }

    /// 全員を選んでいる状態は、「未設定」(nil)に戻す。ルックや初期状態との比較を、同じ値にそろえるため。
    private func setSelectedFaces(_ kept: Set<Int>) {
        let unselected = FaceSelection.unselected(keeping: kept, faceCount: detectedFaces.count)
        update { $0.unselectedFaces = unselected.isEmpty ? nil : unselected }
    }
}
