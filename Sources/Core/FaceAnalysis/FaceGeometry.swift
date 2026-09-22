import CoreGraphics

/// ランドマークから領域(多角形)を作る。すべて正規化座標(左上原点)で扱い、UI・Vision に依存しない。
public enum FaceGeometry {
    /// Vision の輪郭は顎のラインしか取れず額を含まない。
    /// 額まで肌として扱うため、輪郭の両端を顔の高さの 35% だけ上に持ち上げて領域を閉じる。
    static let foreheadLiftRatio: CGFloat = 0.35

    /// 目・眉・唇は、まつ毛や輪郭のにじみまで含めて避けられるよう少し広げて除外する。
    static let eyeExpansion: CGFloat = 1.5
    static let eyebrowExpansion: CGFloat = 1.3
    static let lipsExpansion: CGFloat = 1.15

    public static func skinPolygon(_ face: FaceLandmarks) -> [CGPoint] {
        let contour = face.faceContour
        guard contour.count >= 3, let first = contour.first, let last = contour.last else {
            return rectangle(face.boundingBox)
        }
        let lift = face.boundingBox.height * foreheadLiftRatio
        let top = CGPoint(x: (first.x + last.x) / 2, y: min(first.y, last.y) - lift * 1.15)
        return contour + [CGPoint(x: last.x, y: last.y - lift), top, CGPoint(x: first.x, y: first.y - lift)]
    }

    /// 肌補正を掛けない領域(目・眉・唇)。
    public static func exclusionPolygons(_ face: FaceLandmarks) -> [[CGPoint]] {
        let regions: [([CGPoint], CGFloat)] = [
            (face.leftEye, eyeExpansion), (face.rightEye, eyeExpansion),
            (face.leftEyebrow, eyebrowExpansion), (face.rightEyebrow, eyebrowExpansion),
            (face.outerLips, lipsExpansion),
        ]
        return regions.filter { $0.0.count >= 3 }.map { expanded($0.0, by: $0.1) }
    }

    /// 重心を中心に多角形を拡大・縮小する。
    public static func expanded(_ polygon: [CGPoint], by scale: CGFloat) -> [CGPoint] {
        guard !polygon.isEmpty else { return polygon }
        let center = centroid(polygon)
        return polygon.map { CGPoint(x: center.x + ($0.x - center.x) * scale,
                                     y: center.y + ($0.y - center.y) * scale) }
    }

    public static func centroid(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }

    /// 正規化座標をピクセル座標へ。
    public static func scaled(_ points: [CGPoint], to size: CGSize) -> [CGPoint] {
        points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
    }

    public static func boundingRect(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func rectangle(_ rect: CGRect) -> [CGPoint] {
        [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
         CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
    }

    /// 目の輪郭を、上まぶた側と下まぶた側の折れ線に分ける。
    /// 点の並び順は Vision の仕様に依存しないため、目頭と目尻(左右の端)を結んだ線より
    /// 上にあるか下にあるかで振り分ける。どちらの折れ線も、両端の角を含めて左から右へ並べる。
    /// 点が少ない・左右の端が重なるなど、線にならない場合は nil。
    public static func eyelids(_ eye: [CGPoint]) -> (upper: [CGPoint], lower: [CGPoint])? {
        guard eye.count >= 4 else { return nil }
        let sorted = eye.sorted { $0.x < $1.x }
        guard let inner = sorted.first, let outer = sorted.last, outer.x > inner.x else { return nil }
        let slope = (outer.y - inner.y) / (outer.x - inner.x)
        var upper: [CGPoint] = []
        var lower: [CGPoint] = []
        for point in sorted.dropFirst().dropLast() {
            // 画像座標は下へ行くほど y が大きいので、線より小さい y が上まぶた。
            if point.y < inner.y + (point.x - inner.x) * slope {
                upper.append(point)
            } else {
                lower.append(point)
            }
        }
        guard !upper.isEmpty, !lower.isEmpty else { return nil }
        return ([inner] + upper + [outer], [inner] + lower + [outer])
    }

    /// 折れ線を縦にずらす(正で下へ)。まぶたの線から、アイシャドウや涙袋の位置を作るのに使う。
    /// 入力と同じ座標系のまま動かすだけなので、正規化座標でもピクセル座標でも使える。
    public static func offset(_ points: [CGPoint], dy: CGFloat) -> [CGPoint] {
        points.map { CGPoint(x: $0.x, y: $0.y + dy) }
    }

    /// 瞳の中心。Vision の瞳の点が取れていればそれを、取れていなければ目の輪郭の重心を使う。
    /// Vision の left / right の付け方に依存しないよう、その目の枠に入っている点を選ぶ。
    public static func pupilCenter(for eye: [CGPoint], pupils: [CGPoint]) -> CGPoint? {
        guard eye.count >= 3 else { return nil }
        let box = boundingRect(of: eye)
        // まぶたが細いと瞳の点が枠の外に出ることがあるため、縦に広めに見る。
        let search = box.insetBy(dx: -box.width * 0.1, dy: -box.height * 0.6)
        return pupils.first { search.contains($0) } ?? centroid(eye)
    }

    /// チークを乗せる位置(両頬)。目の真下からやや外側、目と口の高さの中間。
    /// 頬の高い位置に乗せると顔が立体的に見える。目と口の x の中間まで寄せると鼻の脇になり不自然。
    /// 左右の判定は画像上の位置で行うため、Vision の left / right の定義に依存しない。
    public static func cheekCenters(_ face: FaceLandmarks) -> [CGPoint] {
        guard face.outerLips.count >= 3 else { return [] }
        let lips = centroid(face.outerLips)
        let eyes = [face.leftEye, face.rightEye].filter { $0.count >= 3 }.map(centroid)
        guard eyes.count == 2 else { return [] }
        let axisX = (eyes[0].x + eyes[1].x) / 2
        return eyes.map { eye in
            let outward: CGFloat = eye.x < axisX ? -1 : 1
            return CGPoint(x: eye.x + outward * face.boundingBox.width * 0.04,
                           y: eye.y + (lips.y - eye.y) * 0.5)
        }
    }
}
