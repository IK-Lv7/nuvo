import CoreGraphics
import CoreImage
import Foundation

/// CIImage と RGBA8 ビットマップの相互変換。
/// 矩形は左上原点のピクセル座標で受け渡す(Core Image の左下原点との差はここで吸収する)。
enum BitmapIO {
    static func rgba(from image: CGImage) -> [UInt8]? {
        let width = image.width, height = image.height
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? pixels : nil
    }

    static func cgImage(fromRGBA pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        guard pixels.count == width * height * 4,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    static func crop(_ image: CIImage, topLeftRect rect: CGRect, context: CIContext) -> CGImage? {
        let extent = image.extent
        let ciRect = CGRect(x: extent.minX + rect.minX, y: extent.maxY - rect.maxY,
                            width: rect.width, height: rect.height)
        return context.createCGImage(image, from: ciRect)
    }

    static func overlay(_ patch: CGImage, atTopLeft origin: CGPoint, on base: CIImage) -> CIImage {
        let extent = base.extent
        let shift = CGAffineTransform(translationX: extent.minX + origin.x,
                                      y: extent.maxY - origin.y - CGFloat(patch.height))
        return CIImage(cgImage: patch).transformed(by: shift).composited(over: base)
    }
}
