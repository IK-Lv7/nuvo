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
    /// 目もと。アイライン・まつげ・アイシャドウは上まぶた、涙袋は下まぶた、カラコンは虹彩。
    var eyeliner: [UInt8] = []
    var lashes: [UInt8] = []
    var eyeshadow: [UInt8] = []
    var iris: [UInt8] = []
    var tearBags: [UInt8] = []

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

        let eyes = eyeMasks(face: face, rgba: rgba, toROI: toROI, width: width, height: height)

        // 目・髪・背景に色が乗らないよう、肌の領域内に限る。
        // 目もとのマスクは、肌マスクが目の周りを除いているため対象にしない(代わりに目の輪郭で抜く)。
        for i in empty.indices {
            let skin = Float(skinMask[i]) / 255
            blush[i] = UInt8(Float(blush[i]) * skin)
            darkCircles[i] = UInt8(Float(darkCircles[i]) * skin)
            noseBridge[i] = UInt8(Float(noseBridge[i]) * skin)
        }
        return MakeupMasks(lips: lips, brows: brows, blush: blush, teeth: teeth, darkCircles: darkCircles,
                           noseBridge: noseBridge, eyeliner: eyes.eyeliner, lashes: eyes.lashes,
                           eyeshadow: eyes.eyeshadow, iris: eyes.iris, tearBags: eyes.tearBags)
    }

    /// 目もとのマスク。上まぶた・下まぶたの線と、瞳の位置から作る。
    /// アイシャドウ・涙袋は、最後に目の輪郭を抜いて、白目や黒目に色が乗らないようにする。
    private static func eyeMasks(face: FaceLandmarks, rgba: [UInt8], toROI: ([CGPoint]) -> [CGPoint],
                                 width: Int, height: Int)
        -> (eyeliner: [UInt8], lashes: [UInt8], eyeshadow: [UInt8], iris: [UInt8], tearBags: [UInt8]) {
        let empty = [UInt8](repeating: 0, count: width * height)
        var eyeliner = empty, lashes = empty, eyeshadow = empty, iris = empty, tearBags = empty

        /// 折れ線を太さのある線として塗り、境目をぼかす。
        func stroke(_ points: [CGPoint], lineWidth: CGFloat) -> [UInt8] {
            SkinMask.boxBlur(SkinMask.strokeMask(width: width, height: height, points: points, lineWidth: lineWidth),
                             width: width, height: height, radius: max(1, Int(lineWidth * 0.35)))
        }

        func addMax(_ plane: inout [UInt8], _ other: [UInt8]) {
            for i in plane.indices { plane[i] = max(plane[i], other[i]) }
        }

        func luma(_ index: Int) -> Float {
            0.299 * Float(rgba[index * 4]) + 0.587 * Float(rgba[index * 4 + 1]) + 0.114 * Float(rgba[index * 4 + 2])
        }

        let pupils = toROI(face.leftPupil + face.rightPupil)
        for eye in [face.leftEye, face.rightEye] where eye.count >= 4 {
            let points = toROI(eye)
            let rect = FaceGeometry.boundingRect(of: points)
            guard rect.width > 1, rect.height > 0, let lids = FaceGeometry.eyelids(points) else { continue }
            let eyeHeight = rect.height

            // アイラインは、上まぶたの縁に沿った細い線。線の太さの 1/4 だけ上に寄せて、白目に掛かりにくくする。
            let linerWidth = max(2, eyeHeight * 0.30)
            addMax(&eyeliner, stroke(FaceGeometry.offset(lids.upper, dy: -linerWidth * 0.25), lineWidth: linerWidth))

            // まつげは、アイラインより広い範囲。元から暗い画素だけを濃くするので、
            // 線を描き足したようにならず、実際のまつげが太く見える。
            let lashWidth = max(2, eyeHeight * 0.5)
            var lash = stroke(FaceGeometry.offset(lids.upper, dy: -lashWidth * 0.3), lineWidth: lashWidth)
            for i in lash.indices where lash[i] > 0 {
                // 輝度 60 以下で最大、150 以上で 0。白目や肌は動かさない。
                let weight = min(max((150 - luma(i)) / 90, 0), 1)
                lash[i] = UInt8(Float(lash[i]) * weight)
            }
            addMax(&lashes, lash)

            // アイシャドウは、上まぶたから眉へ向かって薄くなる帯。太い線を大きくぼかして作る。
            let shadowWidth = max(3, eyeHeight * 2.2)
            addMax(&eyeshadow, stroke(FaceGeometry.offset(lids.upper, dy: -shadowWidth * 0.45), lineWidth: shadowWidth))

            // カラコンは、瞳の中心から虹彩の大きさの円。まぶたで隠れる部分には乗せない。
            // 虹彩の直径は目の横幅の 4 割ほど(初期値。実機で見て調整する)。
            if let center = FaceGeometry.pupilCenter(for: points, pupils: pupils) {
                let radius = Double(rect.width) * 0.21
                let inside = SkinMask.polygonMask(width: width, height: height, skin: points, holes: [])
                addMax(&iris, circle(center: center, radius: radius, inside: inside,
                                     width: width, height: height, luma: luma))
            }

            // 涙袋は、下まぶたの少し下に入れる細いハイライト。
            let tearWidth = max(2, eyeHeight * 0.55)
            addMax(&tearBags, stroke(FaceGeometry.offset(lids.lower, dy: tearWidth * 0.8), lineWidth: tearWidth))
        }

        // 白目・黒目にアイシャドウや涙袋が乗らないよう、目の輪郭を抜く。
        for eye in [face.leftEye, face.rightEye] where eye.count >= 3 {
            let inside = SkinMask.polygonMask(width: width, height: height, skin: toROI(eye), holes: [])
            for i in inside.indices where inside[i] > 0 {
                let keep = 1 - Float(inside[i]) / 255
                eyeshadow[i] = UInt8(Float(eyeshadow[i]) * keep)
                tearBags[i] = UInt8(Float(tearBags[i]) * keep)
            }
        }
        return (eyeliner, lashes, eyeshadow, iris, tearBags)
    }

    /// 虹彩の円。縁はなじませ、瞳孔(暗い)と映り込み(明るい)は避けて、黒目らしさを保つ。
    private static func circle(center: CGPoint, radius: Double, inside: [UInt8], width: Int, height: Int,
                               luma: (Int) -> Float) -> [UInt8] {
        var plane = [UInt8](repeating: 0, count: width * height)
        guard radius >= 1 else { return plane }
        let minX = max(0, Int((Double(center.x) - radius).rounded(.down)))
        let maxX = min(width - 1, Int((Double(center.x) + radius).rounded(.up)))
        let minY = max(0, Int((Double(center.y) - radius).rounded(.down)))
        let maxY = min(height - 1, Int((Double(center.y) + radius).rounded(.up)))
        guard minX <= maxX, minY <= maxY else { return plane }

        for y in minY...maxY {
            for x in minX...maxX {
                let index = y * width + x
                guard inside[index] > 0 else { continue }
                let distance = hypot(Double(x) + 0.5 - Double(center.x), Double(y) + 0.5 - Double(center.y))
                guard distance <= radius else { continue }
                // 縁の 35% でなじませる。
                let edge = Float(min(max((radius - distance) / (radius * 0.35), 0), 1))
                let value = luma(index)
                // 輝度 30 以下(瞳孔)と 215 以上(映り込み)は避ける。
                let midtone = min(max((value - 30) / 30, 0), 1) * min(max((215 - value) / 35, 0), 1)
                plane[index] = UInt8(min(Float(inside[index]) / 255 * edge * midtone * 255, 255))
            }
        }
        return plane
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
