import CoreGraphics
import Foundation

/// メイクや部分補正を乗せる領域のマスク(0...255)。ランドマーク追従で、顔ごとに1回だけ作る。
struct MakeupMasks: Sendable {
    var lips: [UInt8]
    var brows: [UInt8]
    var blush: [UInt8]
    var teeth: [UInt8] = []
    var darkCircles: [UInt8] = []
    var noseBridge: [UInt8] = []

    static func make(face: FaceLandmarks, skinMask: [UInt8], rgba: [UInt8], imageSize: CGSize,
                     roiOrigin: CGPoint, width: Int, height: Int) -> MakeupMasks {
        let toROI = { (points: [CGPoint]) in
            FaceGeometry.scaled(points, to: imageSize).map { CGPoint(x: $0.x - roiOrigin.x, y: $0.y - roiOrigin.y) }
        }
        let empty = [UInt8](repeating: 0, count: width * height)
        let faceWidth = face.boundingBox.width * imageSize.width
        // 輪郭の段差をなくす程度の、ごく小さなぼかし。
        let softRadius = max(1, Int((faceWidth * 0.006).rounded()))
        func polygon(_ points: [CGPoint], holes: [[CGPoint]] = []) -> [UInt8] {
            SkinMask.boxBlur(
                SkinMask.polygonMask(width: width, height: height, skin: toROI(points), holes: holes.map(toROI)),
                width: width, height: height, radius: softRadius)
        }

        var lips = empty
        if face.outerLips.count >= 3 {
            // 口を開けたときの内側(歯・口内)には色を乗せない。
            lips = polygon(face.outerLips, holes: face.innerLips.count >= 3 ? [face.innerLips] : [])
        }

        var brows = empty
        for brow in [face.leftEyebrow, face.rightEyebrow] where brow.count >= 3 {
            let mask = polygon(brow)
            for i in brows.indices { brows[i] = max(brows[i], mask[i]) }
        }

        // 歯は唇の内側のうち、明るく色味の少ない画素だけ。舌・口内の暗がりや唇には掛けない。
        var teeth = empty
        if face.innerLips.count >= 3 {
            let inside = polygon(FaceGeometry.expanded(face.innerLips, by: 0.9))
            for i in teeth.indices where inside[i] > 0 {
                let score = toothScore(r: Float(rgba[i * 4]), g: Float(rgba[i * 4 + 1]), b: Float(rgba[i * 4 + 2]))
                teeth[i] = UInt8(Float(inside[i]) * score)
            }
        }

        // チークは境界のない丸いぼかし。標準偏差は顔幅の 9%(頬全体に薄く広がる大きさ)。
        var blush = empty
        let sigma = Double(faceWidth) * 0.09
        for center in toROI(FaceGeometry.cheekCenters(face)) {
            addGaussian(to: &blush, width: width, height: height, center: center, sigmaX: sigma, sigmaY: sigma)
        }

        // くまは下まぶたの直下。目の幅を基準に、横に広く縦に薄い楕円で乗せる。
        var darkCircles = empty
        for eye in [face.leftEye, face.rightEye] where eye.count >= 3 {
            let rect = FaceGeometry.boundingRect(of: toROI(eye))
            let eyeWidth = Double(rect.width)
            guard eyeWidth > 0 else { continue }
            let center = CGPoint(x: rect.midX, y: rect.maxY + 0.18 * eyeWidth)
            addGaussian(to: &darkCircles, width: width, height: height, center: center,
                        sigmaX: 0.35 * eyeWidth, sigmaY: 0.18 * eyeWidth)
        }

        // 鼻筋は、鼻根から鼻先へ通る線に沿った細いハイライト。線の太さは鼻の幅の 22%(細いと線に見え、太いと頬まで明るくなる)。
        var noseBridge = empty
        if face.noseCrest.count >= 2 {
            let crest = toROI(face.noseCrest)
            let noseWidth = FaceGeometry.boundingRect(of: toROI(face.nose.isEmpty ? face.noseCrest : face.nose)).width
            let lineWidth = max(2, noseWidth * 0.22)
            noseBridge = SkinMask.boxBlur(SkinMask.strokeMask(width: width, height: height, points: crest, lineWidth: lineWidth),
                                          width: width, height: height, radius: max(1, Int(lineWidth * 0.4)))
        }

        // 目・髪・背景に色が乗らないよう、肌の領域内に限る。
        for i in empty.indices {
            let skin = Float(skinMask[i]) / 255
            blush[i] = UInt8(Float(blush[i]) * skin)
            darkCircles[i] = UInt8(Float(darkCircles[i]) * skin)
            noseBridge[i] = UInt8(Float(noseBridge[i]) * skin)
        }
        return MakeupMasks(lips: lips, brows: brows, blush: blush, teeth: teeth, darkCircles: darkCircles, noseBridge: noseBridge)
    }

    /// 歯らしさ(0...1)。輝度 90〜140 で明るさを、色の幅 70〜110 で無彩色に近いかを見る。
    /// 唇(赤く色の幅が大きい)や口内(暗い)は低くなる。
    static func toothScore(r: Float, g: Float, b: Float) -> Float {
        let luma = 0.299 * r + 0.587 * g + 0.114 * b
        let spread = max(r, g, b) - min(r, g, b)
        let bright = min(max((luma - 90) / 50, 0), 1)
        let neutral = min(max((110 - spread) / 40, 0), 1)
        return bright * neutral
    }

    private static func addGaussian(to plane: inout [UInt8], width: Int, height: Int, center: CGPoint,
                                    sigmaX: Double, sigmaY: Double) {
        guard sigmaX > 0, sigmaY > 0 else { return }
        let minX = max(0, Int((Double(center.x) - sigmaX * 2.5).rounded(.down)))
        let maxX = min(width - 1, Int((Double(center.x) + sigmaX * 2.5).rounded(.up)))
        let minY = max(0, Int((Double(center.y) - sigmaY * 2.5).rounded(.down)))
        let maxY = min(height - 1, Int((Double(center.y) + sigmaY * 2.5).rounded(.up)))
        guard minX <= maxX, minY <= maxY else { return }
        for y in minY...maxY {
            for x in minX...maxX {
                let dx = Double(x) + 0.5 - Double(center.x)
                let dy = Double(y) + 0.5 - Double(center.y)
                let exponent = dx * dx / (2 * sigmaX * sigmaX) + dy * dy / (2 * sigmaY * sigmaY)
                let value = UInt8(min(255 * exp(-exponent), 255))
                plane[y * width + x] = max(plane[y * width + x], value)
            }
        }
    }
}
