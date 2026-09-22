import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// SF Symbols(Apple 標準のアイコン)を、指定した色・大きさの画像にする。
/// スタンプは独自の画像素材を同梱しないため(AGENTS.md)、SF Symbols だけを使う。
/// この Core Package は Mac 上でも `swift test` できるよう macOS もターゲットにしているため(Package.swift)、
/// UIKit(iOS)だけでなく AppKit(macOS)にも対応させる。どちらも SF Symbols を持つため、同じ結果になる。
enum SymbolRenderer {
    static func image(symbolName: String, pointSize: CGFloat, color: CGColor) -> CGImage? {
        guard pointSize >= 1, let base = rawSymbolImage(symbolName: symbolName, pointSize: pointSize) else { return nil }
        return tinted(base, color: color)
    }

    /// 元の画像の不透明度(アルファ)だけを使って、指定した色で塗りつぶす。
    /// UIKit・AppKit それぞれの「テンプレート画像を着色する」機能に頼らず、
    /// Core Graphics だけで行うことで、両プラットフォームで同じ結果にする。
    private static func tinted(_ source: CGImage, color: CGColor) -> CGImage? {
        let width = source.width, height = source.height
        guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(color)
        context.fill(rect)
        context.setBlendMode(.destinationIn)
        context.draw(source, in: rect)
        return context.makeImage()
    }

    #if canImport(UIKit)
    private static func rawSymbolImage(symbolName: String, pointSize: CGFloat) -> CGImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        return UIImage(systemName: symbolName, withConfiguration: configuration)?.cgImage
    }
    #elseif canImport(AppKit)
    private static func rawSymbolImage(symbolName: String, pointSize: CGFloat) -> CGImage? {
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else { return nil }
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        let configured = symbol.withSymbolConfiguration(configuration) ?? symbol
        var rect = NSRect(origin: .zero, size: configured.size)
        return configured.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
    #else
    private static func rawSymbolImage(symbolName: String, pointSize: CGFloat) -> CGImage? { nil }
    #endif
}
