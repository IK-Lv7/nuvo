import CoreGraphics

/// 肌補正を掛ける領域のマスク(0...255)。
/// 「ランドマークによる顔領域(目・眉・唇を除く)」×「肌色らしさ」の積で作る。
/// 髪・背景・小物への誤適用を、片方だけでは防げないため両方を掛け合わせる。
enum SkinMask {
    static func make(face: FaceLandmarks, imageSize: CGSize, roiOrigin: CGPoint,
                     width: Int, height: Int, rgba: [UInt8]) -> [UInt8] {
        let toROI = { (p: CGPoint) in CGPoint(x: p.x - roiOrigin.x, y: p.y - roiOrigin.y) }
        let skin = FaceGeometry.scaled(FaceGeometry.skinPolygon(face), to: imageSize).map(toROI)
        let holes = FaceGeometry.exclusionPolygons(face).map {
            FaceGeometry.scaled($0, to: imageSize).map(toROI)
        }
        let plane = polygonMask(width: width, height: height, skin: skin, holes: holes)

        // 領域の境目が段差にならないよう、顔幅の 1.5% でぼかす。
        let faceWidth = face.boundingBox.width * imageSize.width
        let radius = max(1, Int((faceWidth * 0.015).rounded()))
        let feathered = boxBlur(boxBlur(plane, width: width, height: height, radius: radius),
                                width: width, height: height, radius: radius)

        var mask = feathered
        for i in 0..<(width * height) where mask[i] > 0 {
            let score = skinScore(r: Float(rgba[i * 4]), g: Float(rgba[i * 4 + 1]), b: Float(rgba[i * 4 + 2]))
            mask[i] = UInt8((Float(mask[i]) * score).rounded())
        }
        return mask
    }

    /// YCbCr(BT.601)での肌色判定。Cb 77...127 / Cr 133...173 は肌色検出で広く使われる範囲。
    /// 照明や肌の色の違いに耐えるよう、範囲の外側 10 も線形に減衰させて連続的に扱う。
    static func skinScore(r: Float, g: Float, b: Float) -> Float {
        let cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b
        let cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b
        return ramp(cb, lo: 77, hi: 127, margin: 10) * ramp(cr, lo: 133, hi: 173, margin: 10)
    }

    private static func ramp(_ x: Float, lo: Float, hi: Float, margin: Float) -> Float {
        if x >= lo && x <= hi { return 1 }
        let distance = x < lo ? lo - x : x - hi
        return max(0, 1 - distance / margin)
    }

    static func polygonMask(width: Int, height: Int, skin: [CGPoint], holes: [[CGPoint]]) -> [UInt8] {
        var plane = [UInt8](repeating: 0, count: width * height)
        plane.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            // 座標が左上原点で渡されるため、CGContext を上下反転して描く。
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            fill(context, points: skin, gray: 1)
            for hole in holes { fill(context, points: hole, gray: 0) }
        }
        return plane
    }

    /// 折れ線を太さのある線として塗ったマスク。鼻筋のような細長い領域に使う。
    static func strokeMask(width: Int, height: Int, points: [CGPoint], lineWidth: CGFloat) -> [UInt8] {
        var plane = [UInt8](repeating: 0, count: width * height)
        guard points.count >= 2, width > 0, height > 0 else { return plane }
        plane.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.setStrokeColor(gray: 1, alpha: 1)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.addLines(between: points)
            context.strokePath()
        }
        return plane
    }

    private static func fill(_ context: CGContext, points: [CGPoint], gray: CGFloat) {
        guard points.count >= 3 else { return }
        context.setFillColor(gray: gray, alpha: 1)
        context.addLines(between: points)
        context.closePath()
        context.fillPath()
    }

    static func boxBlur(_ plane: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8] {
        guard radius > 0, width > 0, height > 0 else { return plane }
        let span = Float(2 * radius + 1)
        var horizontal = plane
        for y in 0..<height {
            for x in 0..<width {
                var sum: Float = 0
                for d in -radius...radius { sum += Float(plane[y * width + min(max(x + d, 0), width - 1)]) }
                horizontal[y * width + x] = UInt8((sum / span).rounded())
            }
        }
        var result = horizontal
        for y in 0..<height {
            for x in 0..<width {
                var sum: Float = 0
                for d in -radius...radius { sum += Float(horizontal[min(max(y + d, 0), height - 1) * width + x]) }
                result[y * width + x] = UInt8((sum / span).rounded())
            }
        }
        return result
    }
}
