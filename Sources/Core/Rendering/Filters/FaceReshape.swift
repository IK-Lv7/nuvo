import CoreGraphics
import CoreImage
import Foundation

/// 出力画素ごとの「どこから色を持ってくるか」のずれ(ピクセル単位)。
/// 逆写像(出力から元を引く)で歪めるため、穴が空かず、ずれの大きさが滑らかなら破綻しない。
struct DisplacementField {
    let width: Int
    let height: Int
    var dx: [Float]
    var dy: [Float]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        dx = [Float](repeating: 0, count: width * height)
        dy = [Float](repeating: 0, count: width * height)
    }
}

/// 顔立ちの変形(小顔・目の拡大・あご)。ランドマーク基準で、影響は各部位の周囲に減衰させる。
/// 画像中心を基準にしないため、顔が端にあっても左右非対称でも成立し、背景の直線は歪みにくい。
enum FaceReshape {
    // 強度 ±1 のときの最大変化量。いずれも自然さの限界を見て決めた初期値で、実機で調整する。
    /// 目の拡大率。+1 で 35% 大きく(それ以上は目が浮いて不自然)。
    static let eyeMaxScale: Float = 0.35
    /// 輪郭を内側へ寄せる量(顔幅比)。
    static let slimMaxShift = 0.07
    /// あごを上下させる量(顔幅比)。
    static let chinMaxShift = 0.06
    /// 小鼻を内側へ寄せる量(鼻の幅比)。それ以上は鼻の穴の形が崩れる。
    static let noseMaxShift = 0.12

    static func apply(faces: [FaceLandmarks], parameters p: AdjustmentParameters,
                      to image: CIImage, context: CIContext) -> CIImage {
        guard p.faceSlim != 0 || p.eyeEnlarge != 0 || p.chin != 0 || p.noseSlim != 0 else { return image }
        let size = image.extent.size
        let bounds = CGRect(origin: .zero, size: size)
        var result = image

        for face in faces {
            let polygon = FaceGeometry.scaled(FaceGeometry.skinPolygon(face), to: size)
            // 輪郭の外側へも影響が及ぶため、顔幅の 25% の余白を取る。
            let margin = face.boundingBox.width * size.width * 0.25
            let rect = FaceGeometry.boundingRect(of: polygon)
                .insetBy(dx: -margin, dy: -margin).integral.intersection(bounds).integral
            guard rect.width >= 8, rect.height >= 8,
                  let patch = BitmapIO.crop(result, topLeftRect: rect, context: context),
                  let pixels = BitmapIO.rgba(from: patch),
                  let field = field(face: face, imageSize: size, roiOrigin: rect.origin,
                                    width: patch.width, height: patch.height,
                                    faceSlim: p.faceSlim, eyeEnlarge: p.eyeEnlarge, chin: p.chin,
                                    noseSlim: p.noseSlim),
                  let warped = BitmapIO.cgImage(fromRGBA: warp(rgba: pixels, field: field),
                                                width: patch.width, height: patch.height) else { continue }
            result = BitmapIO.overlay(warped, atTopLeft: rect.origin, on: result)
        }
        return result
    }

    static func field(face: FaceLandmarks, imageSize: CGSize, roiOrigin: CGPoint, width: Int, height: Int,
                      faceSlim: Double, eyeEnlarge: Double, chin: Double, noseSlim: Double = 0) -> DisplacementField? {
        guard faceSlim != 0 || eyeEnlarge != 0 || chin != 0 || noseSlim != 0 else { return nil }
        let toROI = { (points: [CGPoint]) in
            FaceGeometry.scaled(points, to: imageSize).map { CGPoint(x: $0.x - roiOrigin.x, y: $0.y - roiOrigin.y) }
        }
        var field = DisplacementField(width: width, height: height)
        let faceWidth = Double(face.boundingBox.width * imageSize.width)
        let faceHeight = Double(face.boundingBox.height * imageSize.height)
        let faceTop = Double(face.boundingBox.minY * imageSize.height) - Double(roiOrigin.y)
        let faceCenterX = Double(face.boundingBox.midX * imageSize.width) - Double(roiOrigin.x)
        let faceCenter = CGPoint(x: faceCenterX, y: faceTop + faceHeight / 2)

        // 顔の傾き(ロール)を反映した左右・上下の基準軸。以下の判定は元々「顔がまっすぐ立っている」
        // 前提(画像の x = 顔の左右、y = 顔の上下)で書かれているため、各点をこの軸で顔の中心まわりに
        // 回転させ、「まっすぐ立っているとしたときの位置」に直してから判定する(押し出す向きだけ、
        // 最後にこの軸で画像座標へ戻す)。傾きがなければ axes は画像そのままの軸になり、結果は変わらない。
        let axes = FaceGeometry.faceAxes(leftEye: face.leftEye.count >= 3 ? toROI(face.leftEye) : [],
                                         rightEye: face.rightEye.count >= 3 ? toROI(face.rightEye) : [],
                                         mouth: face.outerLips.count >= 3 ? toROI(face.outerLips) : [])
        let upright = { (point: CGPoint) -> CGPoint in
            let local = FaceGeometry.projected(point, origin: faceCenter, axes: axes)
            return CGPoint(x: faceCenter.x + local.x, y: faceCenter.y + local.y)
        }

        if eyeEnlarge != 0 {
            let scale = Float(min(max(eyeEnlarge, -1), 1)) * eyeMaxScale
            for eye in [face.leftEye, face.rightEye] where eye.count >= 3 {
                let points = toROI(eye)
                let center = FaceGeometry.centroid(points)
                let radius = Double(FaceGeometry.boundingRect(of: points).width) * 1.1
                // 目の中心から外へ向かう拡大。中心ほど強く、半径の縁で 0 になる。
                accumulate(&field, center: center, radius: radius) { offsetX, offsetY, weight in
                    (-offsetX * scale * weight, -offsetY * scale * weight)
                }
            }
        }

        let contour = toROI(face.faceContour)
        if faceSlim != 0, contour.count >= 3 {
            let strength = min(max(faceSlim, -1), 1) * slimMaxShift * faceWidth
            for point in contour {
                let u = upright(point)
                // 頬の下半分から顎にかけてだけ動かす(こめかみを動かすと耳や髪が崩れる)。
                let vertical = smoothStep((Double(u.y) - faceTop) / faceHeight, from: 0.35, to: 0.65)
                // 顎先(中心線付近)は左右どちらへも動かせないため、中心から離れるほど強くする。
                let side = min(max((Double(u.x) - faceCenterX) / (0.15 * faceWidth), -1), 1)
                let shift = Float(strength * vertical * side)
                accumulate(&field, center: point, radius: faceWidth * 0.22) { _, _, weight in
                    (shift * weight * Float(axes.horizontal.x), shift * weight * Float(axes.horizontal.y))
                }
            }
        }

        if chin != 0, let chinPoint = contour.max(by: { upright($0).y < upright($1).y }) {
            let shift = Float(min(max(chin, -1), 1) * chinMaxShift * faceWidth)
            accumulate(&field, center: chinPoint, radius: faceWidth * 0.28) { _, _, weight in
                (shift * weight * Float(axes.vertical.x), shift * weight * Float(axes.vertical.y))
            }
        }
        if noseSlim != 0, face.nose.count >= 3 {
            let nose = toROI(face.nose)
            let uprightNose = nose.map(upright)
            let noseWidth = Double(FaceGeometry.boundingRect(of: uprightNose).width)
            let centerX = face.noseCrest.count >= 2
                ? Double(upright(FaceGeometry.centroid(toROI(face.noseCrest))).x)
                : Double(FaceGeometry.boundingRect(of: uprightNose).midX)
            if noseWidth > 0 {
                let strength = min(max(noseSlim, -1), 1) * noseMaxShift * noseWidth
                for (index, point) in nose.enumerated() {
                    // 小鼻(中心線から離れた点)ほど強く、中心線上の点は動かさない。
                    let side = min(max((Double(uprightNose[index].x) - centerX) / (0.25 * noseWidth), -1), 1)
                    let shift = Float(strength * side)
                    accumulate(&field, center: point, radius: noseWidth * 0.5) { _, _, weight in
                        (shift * weight * Float(axes.horizontal.x), shift * weight * Float(axes.horizontal.y))
                    }
                }
            }
        }
        return field
    }

    /// 逆写像 + バイリニア補間で歪める。ずれのない画素はコピーする。
    static func warp(rgba: [UInt8], field: DisplacementField) -> [UInt8] {
        let width = field.width, height = field.height
        guard rgba.count == width * height * 4 else { return rgba }
        var output = rgba
        rgba.withUnsafeBufferPointer { src in
            field.dx.withUnsafeBufferPointer { dxs in
                field.dy.withUnsafeBufferPointer { dys in
                    output.withUnsafeMutableBufferPointer { out in
                        DispatchQueue.concurrentPerform(iterations: height) { y in
                            for x in 0..<width {
                                let i = y * width + x
                                guard abs(dxs[i]) > 0.001 || abs(dys[i]) > 0.001 else { continue }
                                let sx = min(max(Float(x) + dxs[i], 0), Float(width - 1))
                                let sy = min(max(Float(y) + dys[i], 0), Float(height - 1))
                                let x0 = Int(sx), y0 = Int(sy)
                                let x1 = min(x0 + 1, width - 1), y1 = min(y0 + 1, height - 1)
                                let fx = sx - Float(x0), fy = sy - Float(y0)
                                for c in 0..<4 {
                                    let top = Float(src[(y0 * width + x0) * 4 + c]) * (1 - fx)
                                        + Float(src[(y0 * width + x1) * 4 + c]) * fx
                                    let bottom = Float(src[(y1 * width + x0) * 4 + c]) * (1 - fx)
                                        + Float(src[(y1 * width + x1) * 4 + c]) * fx
                                    out[i * 4 + c] = UInt8(min(max(top * (1 - fy) + bottom * fy, 0), 255).rounded())
                                }
                            }
                        }
                    }
                }
            }
        }
        return output
    }

    /// 滑らかに 0 へ落ちる重み。縁で値も傾きも 0 なので、変形の境目が見えない。
    private static func falloff(_ t: Float) -> Float {
        guard t < 1 else { return 0 }
        let k = 1 - t * t
        return k * k
    }

    private static func smoothStep(_ x: Double, from lower: Double, to upper: Double) -> Double {
        let t = min(max((x - lower) / (upper - lower), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// `center` を中心とする半径 `radius` の円内の各画素に、ずれを加算する。
    private static func accumulate(_ field: inout DisplacementField, center: CGPoint, radius: Double,
                                   displacement: (_ offsetX: Float, _ offsetY: Float, _ weight: Float) -> (Float, Float)) {
        guard radius > 0 else { return }
        let minX = max(0, Int((Double(center.x) - radius).rounded(.down)))
        let maxX = min(field.width - 1, Int((Double(center.x) + radius).rounded(.up)))
        let minY = max(0, Int((Double(center.y) - radius).rounded(.down)))
        let maxY = min(field.height - 1, Int((Double(center.y) + radius).rounded(.up)))
        guard minX <= maxX, minY <= maxY else { return }
        for y in minY...maxY {
            for x in minX...maxX {
                let offsetX = Double(x) + 0.5 - Double(center.x)
                let offsetY = Double(y) + 0.5 - Double(center.y)
                let distance = (offsetX * offsetX + offsetY * offsetY).squareRoot()
                let weight = falloff(Float(distance / radius))
                guard weight > 0 else { continue }
                let (dx, dy) = displacement(Float(offsetX), Float(offsetY), weight)
                field.dx[y * field.width + x] += dx
                field.dy[y * field.width + x] += dy
            }
        }
    }
}
