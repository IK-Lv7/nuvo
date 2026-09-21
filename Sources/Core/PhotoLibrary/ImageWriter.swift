import CoreGraphics
import Foundation
import ImageIO

/// 画像の書き出し(JPEG / HEIC / PNG)とメタデータの扱い。
/// 位置情報を消すかどうかを自分で決めるため、`CIContext` の自動書き出しではなく ImageIO を直接使う。
/// 書き出しの形式。
public enum ExportFormat: String, CaseIterable, Sendable, Codable {
    case jpeg, heic, png

    public var utiIdentifier: String {
        switch self {
        case .jpeg: "public.jpeg"
        case .heic: "public.heic"
        case .png: "public.png"
        }
    }

    public var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        case .heic: "heic"
        case .png: "png"
        }
    }

    /// 画質の指定が効くか。PNG は可逆圧縮なので効かない。
    public var isLossy: Bool { self != .png }
}

enum ImageWriter {
    /// 元画像のメタデータ(Exif・GPS など)を読む。
    static func readMetadata(from data: Data) -> [String: Any] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return [:] }
        return properties
    }

    /// 書き出し用に整える。
    /// - 位置情報(GPS)は `stripLocation` のとき消す。
    /// - 画素は既に正しい向きに回してあるため、向きは 1(回転なし)にする。残すと二重に回って見える。
    /// - 切り出し・回転でサイズが変わるため、画素サイズの記述は新しい値にする。
    static func sanitized(_ metadata: [String: Any], stripLocation: Bool, width: Int, height: Int) -> [String: Any] {
        var result = metadata
        if stripLocation { result.removeValue(forKey: kCGImagePropertyGPSDictionary as String) }
        result[kCGImagePropertyOrientation as String] = 1
        result[kCGImagePropertyPixelWidth as String] = width
        result[kCGImagePropertyPixelHeight as String] = height

        if var tiff = result[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            tiff[kCGImagePropertyTIFFOrientation as String] = 1
            result[kCGImagePropertyTIFFDictionary as String] = tiff
        }
        if var exif = result[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            exif[kCGImagePropertyExifPixelXDimension as String] = width
            exif[kCGImagePropertyExifPixelYDimension as String] = height
            result[kCGImagePropertyExifDictionary as String] = exif
        }
        return result
    }

    /// 端末が HEIC を書き出せない場合は nil を返すので、呼び出し側で JPEG に戻すこと。
    static func data(from image: CGImage, properties: [String: Any], quality: Double,
                     format: ExportFormat = .jpeg) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output as CFMutableData, format.utiIdentifier as CFString, 1, nil) else { return nil }
        var options = properties
        if format.isLossy { options[kCGImageDestinationLossyCompressionQuality as String] = min(max(quality, 0.1), 1) }
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}
