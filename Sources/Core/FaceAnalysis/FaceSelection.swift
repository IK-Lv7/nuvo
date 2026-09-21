import CoreGraphics

/// 複数人が写る写真で、加工する顔を選ぶ。顔は検出順の番号で指す(同じ写真の中では変わらない)。
/// 座標はすべて正規化座標(左上原点)で、UI・Vision に依存しない。
public enum FaceSelection {
    /// タップは指の太さの分だけ外れやすい。顔の枠を、この割合だけ広げて当たり判定にする。
    static let tapPadding: CGFloat = 0.15

    /// 選ばれていない顔を除いた顔の一覧。
    public static func selected(_ faces: [FaceLandmarks], excluding unselected: [Int]) -> [FaceLandmarks] {
        guard !unselected.isEmpty else { return faces }
        let excluded = Set(unselected)
        return faces.enumerated().filter { !excluded.contains($0.offset) }.map { $0.element }
    }

    /// タップした位置にある顔の番号。重なっているときは、小さい(奥に写っている)顔を優先する。
    public static func faceIndex(at point: CGPoint, in faces: [FaceLandmarks]) -> Int? {
        faces.enumerated()
            .filter { paddedBox($0.element.boundingBox).contains(point) }
            .min { area($0.element.boundingBox) < area($1.element.boundingBox) }?
            .offset
    }

    /// 指で囲んだ線の内側に、顔の中心が入っている顔の番号。線が閉じていなくても、始点と終点を結んで囲みとみなす。
    /// 3 点未満は囲みにならないので、何も選ばない。
    public static func indices(insideLasso lasso: [CGPoint], in faces: [FaceLandmarks]) -> [Int] {
        guard lasso.count >= 3 else { return [] }
        return faces.enumerated()
            .filter { contains(lasso, CGPoint(x: $0.element.boundingBox.midX, y: $0.element.boundingBox.midY)) }
            .map { $0.offset }
    }

    /// 選ばれている顔のうち、最も大きく写っている顔(証明写真の対象になる)。
    public static func primary(_ faces: [FaceLandmarks], excluding unselected: [Int]) -> FaceLandmarks? {
        selected(faces, excluding: unselected).max { area($0.boundingBox) < area($1.boundingBox) }
    }

    /// 選ばれていない顔の番号を、「選んだ顔の番号」から求める。並びは昇順にそろえる(同じ選択を同じ値にするため)。
    public static func unselected(keeping kept: Set<Int>, faceCount: Int) -> [Int] {
        (0..<faceCount).filter { !kept.contains($0) }
    }

    /// 偶奇規則による点の内外判定。自分と交差する線でも、囲んだ部分が内側になる。
    static func contains(_ polygon: [CGPoint], _ point: CGPoint) -> Bool {
        var inside = false
        var previous = polygon[polygon.count - 1]
        for current in polygon {
            if (current.y > point.y) != (previous.y > point.y),
               point.x < (previous.x - current.x) * (point.y - current.y) / (previous.y - current.y) + current.x {
                inside.toggle()
            }
            previous = current
        }
        return inside
    }

    private static func paddedBox(_ box: CGRect) -> CGRect {
        box.insetBy(dx: -box.width * tapPadding, dy: -box.height * tapPadding)
    }

    private static func area(_ box: CGRect) -> CGFloat { box.width * box.height }
}
