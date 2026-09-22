import CoreGraphics
import CoreImage
import CoreText
import Foundation

/// 文字を画像に焼き込む。システムのフォントだけを使い、フォントファイルは同梱しない
/// (追加のライセンス整理を避けるため)。文字の大きさは画像の短辺に対する比で決まる。
enum TextRenderer {
    /// 影や字形のはみ出しで切れないよう、文字の高さに対してこの比だけ余白を取る。
    private static let paddingRatio: CGFloat = 0.4
    private static let lineSpacing: CGFloat = 1.1

    static func apply(_ overlays: [TextOverlay], to image: CIImage) -> CIImage {
        // 文字が写真の端をはみ出しても、書き出す画像の大きさは変えない。
        // `composited(over:)` は範囲を両方の和にするため、放っておくと出力が広がってしまう。
        let extent = image.extent
        var result = image
        for overlay in overlays where !overlay.text.isEmpty {
            guard let patch = render(overlay, imageSize: extent.size) else { continue }
            let cx = extent.minX + overlay.center.x * extent.width
            let cy = extent.maxY - overlay.center.y * extent.height
            let moved = CIImage(cgImage: patch).transformed(by: CGAffineTransform(
                translationX: cx - CGFloat(patch.width) / 2, y: cy - CGFloat(patch.height) / 2))
            result = moved.composited(over: result).cropped(to: extent)
        }
        return result
    }

    /// 文字だけを描いた透明な画像を作る。
    static func render(_ overlay: TextOverlay, imageSize: CGSize) -> CGImage? {
        let fontSize = CGFloat(min(max(overlay.size, 0.01), 1)) * min(imageSize.width, imageSize.height)
        guard fontSize >= 4, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        let font = makeFont(overlay, size: fontSize)
        let lines = overlay.text.components(separatedBy: "\n").map { line -> (CTLine, CGFloat) in
            let attributes: [CFString: Any] = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: overlay.color.cgColor]
            let attributed = CFAttributedStringCreate(nil, line as CFString, attributes as CFDictionary)
            let ctLine = CTLineCreateWithAttributedString(attributed ?? NSAttributedString(string: line) as CFAttributedString)
            return (ctLine, CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil)))
        }
        let ascent = CTFontGetAscent(font), descent = CTFontGetDescent(font)
        let lineHeight = (ascent + descent) * lineSpacing
        let padding = fontSize * paddingRatio
        let textWidth = lines.map(\.1).max() ?? 0
        let width = Int((textWidth + padding * 2).rounded(.up))
        let height = Int((lineHeight * CGFloat(lines.count) + padding * 2).rounded(.up))
        guard width > 0, height > 0, width * height < 64_000_000,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

        if overlay.hasShadow {
            context.setShadow(offset: CGSize(width: 0, height: -fontSize * 0.05), blur: fontSize * 0.12,
                              color: CGColor(gray: 0, alpha: 0.5))
        }
        for (index, entry) in lines.enumerated() {
            // 行は中央揃え。原点は左下なので、上の行ほど大きな y に置く。
            let x = padding + (textWidth - entry.1) / 2
            let y = CGFloat(height) - padding - CGFloat(index + 1) * lineHeight + descent + (lineHeight - ascent - descent) / 2
            context.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(entry.0, context)
        }
        return context.makeImage()
    }

    private static func makeFont(_ overlay: TextOverlay, size: CGFloat) -> CTFont {
        guard let names = overlay.style.fontNames else { return systemFont(size: size, bold: overlay.isBold) }
        if overlay.isBold, let boldName = names.bold, let bold = font(named: boldName, size: size) { return bold }
        guard let base = font(named: names.regular, size: size) else { return systemFont(size: size, bold: overlay.isBold) }
        guard overlay.isBold else { return base }
        return CTFontCreateCopyWithSymbolicTraits(base, size, nil, .traitBold, .traitBold) ?? base
    }

    /// 名前のフォントを返す。端末に無いと別のフォントが黙って返るため、名前が一致するかを確かめ、
    /// 一致しなければ nil にして、システムフォントへ戻す。
    private static func font(named name: String, size: CGFloat) -> CTFont? {
        let font = CTFontCreateWithName(name as CFString, size, nil)
        return (CTFontCopyPostScriptName(font) as String) == name ? font : nil
    }

    private static func systemFont(size: CGFloat, bold: Bool) -> CTFont {
        let base = CTFontCreateUIFontForLanguage(.system, size, nil) ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        guard bold else { return base }
        return CTFontCreateCopyWithSymbolicTraits(base, size, nil, .traitBold, .traitBold) ?? base
    }
}
