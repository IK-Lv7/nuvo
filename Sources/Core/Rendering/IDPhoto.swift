import CoreGraphics

/// 証明写真の規格。
/// パスポートとマイナンバーカードの顔写真は、外務省・マイナンバーカード総合サイトの規格で
/// 35×45mm、顔(頭頂〜あご)32〜36mm、頭頂と上端の余白 2〜6mm。それぞれの中央値を使う。
/// 履歴書(30×40mm)には公的な規格がなく、同じ比率を用いる慣習的な設定。
public enum IDPhotoSpec: String, CaseIterable, Sendable, Codable {
    case passport
    case resume

    /// 幅 / 高さ。
    var aspect: CGFloat {
        switch self {
        case .passport: 35.0 / 45.0
        case .resume: 30.0 / 40.0
        }
    }

    /// 顔(頭頂〜あご)の高さ / 写真の高さ。規格 32〜36mm の中央 34mm。
    var headFraction: CGFloat { 34.0 / 45.0 }

    /// 頭頂から写真上端までの余白 / 写真の高さ。規格 2〜6mm の中央 4mm。
    var topMarginFraction: CGFloat { 4.0 / 45.0 }
}

enum IDPhotoLayout {
    /// 頭頂を実測できないときの推定。Vision の顔ボックスは髪を含まないため、
    /// ボックスの高さの 30% を髪の分として上に足す。
    private static let hairAboveFaceBox: CGFloat = 0.30

    /// 規格に合う切り出し範囲(左上原点のピクセル座標)。画像内に収まらなければ nil。
    /// - Parameter crown: 頭頂の位置(0...1、上が 0)。人物マスクから実測できたときに渡す。
    static func cropRect(face: FaceLandmarks, crown: CGFloat?, imageSize: CGSize, spec: IDPhotoSpec) -> CGRect? {
        let chin = face.faceContour.map(\.y).max() ?? face.boundingBox.maxY
        let crownY = crown ?? (face.boundingBox.minY - hairAboveFaceBox * face.boundingBox.height)
        let headHeight = (chin - crownY) * imageSize.height
        guard headHeight > 0 else { return nil }

        let height = headHeight / spec.headFraction
        let width = height * spec.aspect
        guard width <= imageSize.width, height <= imageSize.height else { return nil }

        // 顔を横方向の中央に置く。写真の端にはみ出す分は、範囲をずらして収める。
        let x = min(max(face.boundingBox.midX * imageSize.width - width / 2, 0), imageSize.width - width)
        let y = crownY * imageSize.height - spec.topMarginFraction * height
        // 上下は顔の位置が規格そのものなので、動かさずに収まるか確認する。
        guard y >= 0, y + height <= imageSize.height else { return nil }
        return CGRect(x: x.rounded(), y: y.rounded(), width: width.rounded(), height: height.rounded())
    }
}
