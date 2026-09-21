import CoreImage
import CoreImage.CIFilterBuiltins

/// 調整パラメータを受け取り、加工済みの画像を返す。UI の知識は持たない。
/// 適用順: 肌補正・メイク → 背景 → 顔立ちの変形 → スポット修復 → 自動補正 → フィルター → 色調整
///        → 仕上げ → 証明写真の切り出し → 構図(反転・回転・傾き・縦横比) → 文字。
/// 肌補正とメイクのキャッシュは元画像の座標で作っているため、画像を動かす変形より先に適用する。
/// そうすると唇や頬の色も変形に追従する。背景は肌補正の後(補正パッチが元の背景を戻さないため)、
/// 変形の前(変形で動いた輪郭の隙間に新しい背景が入るため)。スポット修復はタップ位置が最終画像基準のため変形の後。
public struct RenderPipeline: Sendable {
    // スライダー ±1 に対応する実効値。以下は実機で見て調整する前提の初期値。
    // CIColorControls の brightness は加算値のため、±1 だと白飛び・黒つぶれで使い物にならない。
    // 極端な値でも写真として成立するよう ±0.25 に抑える。
    private static let brightnessScale = 0.25
    // contrast は 1 が無変化の乗算値。0.5〜1.5 の範囲なら階調が潰れきらない。
    private static let contrastScale = 0.5
    // saturation は 1 が無変化。1.6 を超えると肌が不自然な色になり安っぽく見える。
    private static let saturationScale = 0.6

    public init() {}

    func apply(_ parameters: AdjustmentParameters, to source: RenderSource, context: CIContext) -> CIImage {
        let p = parameters.clamped()
        var image = source.image

        if let retouch = source.retouch, p.hasSkinOrMakeup {
            image = retouch.apply(p, to: image)
        }
        if let color = p.backgroundColor, let mask = source.subjectMask {
            image = BackgroundFilter.apply(blur: 0, color: color, mask: mask, to: image)
        } else if p.backgroundBlur > 0, let mask = source.depthMask ?? source.subjectMask {
            // ポートレート写真では、深度から作ったマスクのほうが奥行きに沿った自然なぼけ方になる。
            image = BackgroundFilter.apply(blur: p.backgroundBlur, color: nil, mask: mask, to: image)
        }
        let faces = FaceSelection.selected(source.faces, excluding: p.excludedFaces)
        if !faces.isEmpty {
            image = FaceReshape.apply(faces: faces, parameters: p, to: image, context: context)
        }
        if !p.spots.isEmpty {
            image = SpotHealer.apply(p.spots, to: image, context: context)
        }
        if p.autoEnhance {
            image = ToneAdjustments.autoEnhance(image)
        }
        if let preset = p.filter {
            image = LUTFilter.apply(preset, intensity: p.filterIntensity, to: image)
        }
        image = ToneAdjustments.apply(p, to: applyColor(p, to: image))
        image = cropForIDPhoto(p, source: source, image: image)
        image = GeometryAdjust.apply(p, to: image)
        // 文字は最後に、完成した構図の上に置く(位置は最終画像に対する相対値)。
        return TextRenderer.apply(p.texts, to: image)
    }

    /// 規格に合う範囲へ切り出し、原点を (0, 0) に戻す。範囲が求まらなければ切り出さない。
    private func cropForIDPhoto(_ p: AdjustmentParameters, source: RenderSource, image: CIImage) -> CIImage {
        guard let spec = p.idPhoto, let rect = source.idPhotoCropRect(spec, unselectedFaces: p.excludedFaces) else { return image }
        let extent = image.extent
        let ciRect = CGRect(x: extent.minX + rect.minX, y: extent.maxY - rect.maxY,
                            width: rect.width, height: rect.height)
        return image.cropped(to: ciRect)
            .transformed(by: CGAffineTransform(translationX: -ciRect.minX, y: -ciRect.minY))
    }

    private func applyColor(_ p: AdjustmentParameters, to image: CIImage) -> CIImage {
        guard p.brightness != 0 || p.contrast != 0 || p.saturation != 0 else { return image }
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.brightness = Float(p.brightness * Self.brightnessScale)
        filter.contrast = Float(1 + p.contrast * Self.contrastScale)
        filter.saturation = Float(1 + p.saturation * Self.saturationScale)
        return filter.outputImage ?? image
    }
}
