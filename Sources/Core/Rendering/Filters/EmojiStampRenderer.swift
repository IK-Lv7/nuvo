import CoreGraphics
import Foundation
import ImageIO

/// 同梱の絵文字画像(OpenMoji。ライセンスは THIRD_PARTY_NOTICES.md 参照)を、指定した大きさの画像にする。
/// SF Symbols(SymbolRenderer)と違い、すでに色がついた絵なので着色はしない。
/// UI 側(一覧のサムネイルなど)からも使うため public にしている。
public enum EmojiStampRenderer {
    public static func image(assetName: String, pointSize: CGFloat) -> CGImage? {
        guard pointSize >= 1, let source = cache.source(for: assetName) else { return nil }
        return scaled(source, to: pointSize)
    }

    private static func scaled(_ source: CGImage, to pointSize: CGFloat) -> CGImage? {
        let size = Int(pointSize.rounded())
        guard size > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: size, height: size))
        return context.makeImage()
    }

    private static let cache = ImageCache()

    /// 同梱画像は毎回ディスクから読み直さなくていいよう、デコード結果を使い回す。
    /// スタンプの追加・移動のたびに `image(assetName:pointSize:)` が呼ばれるため。
    private final class ImageCache: @unchecked Sendable {
        private let lock = NSLock()
        private var images: [String: CGImage] = [:]

        func source(for assetName: String) -> CGImage? {
            lock.lock()
            defer { lock.unlock() }
            if let cached = images[assetName] { return cached }
            // Package.swift の `.copy("Resources/Stamps")` はフォルダ構造を保ったままコピーするため、
            // バンドル直下ではなく "Stamps" フォルダの中に入る。
            guard let url = Bundle.module.url(forResource: assetName, withExtension: "png", subdirectory: "Stamps"),
                  let provider = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(provider, 0, nil) else { return nil }
            images[assetName] = image
            return image
        }
    }
}
