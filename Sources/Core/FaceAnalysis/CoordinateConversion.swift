import CoreGraphics

/// 座標系の変換を一箇所に集約する。
/// Vision は左下原点の正規化座標、UIKit / SwiftUI は左上原点のピクセル座標で、
/// 混在させると上下反転バグになりやすいため、変換は必ずこの型を通す。
public enum CoordinateConversion {
    /// Vision の正規化座標(左下原点, 0...1)を、左上原点のピクセル座標へ変換する。
    public static func visionNormalizedToTopLeft(_ point: CGPoint, imageSize: CGSize) -> CGPoint {
        CGPoint(x: point.x * imageSize.width,
                y: (1 - point.y) * imageSize.height)
    }

    /// 左上原点のピクセル座標を、Vision の正規化座標(左下原点)へ変換する。
    public static func topLeftToVisionNormalized(_ point: CGPoint, imageSize: CGSize) -> CGPoint {
        CGPoint(x: point.x / imageSize.width,
                y: 1 - point.y / imageSize.height)
    }

    /// Vision の正規化矩形(左下原点)を、左上原点のピクセル矩形へ変換する。
    public static func visionNormalizedToTopLeft(_ rect: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(x: rect.minX * imageSize.width,
               y: (1 - rect.maxY) * imageSize.height,
               width: rect.width * imageSize.width,
               height: rect.height * imageSize.height)
    }

    /// 顔のバウンディングボックス内の相対座標(Vision のランドマーク, 左下原点)を、
    /// 画像全体に対する正規化座標(左上原点)へ変換する。
    public static func visionLandmarkToTopLeftUnit(_ point: CGPoint, boundingBox: CGRect) -> CGPoint {
        CGPoint(x: boundingBox.minX + point.x * boundingBox.width,
                y: 1 - (boundingBox.minY + point.y * boundingBox.height))
    }
}
