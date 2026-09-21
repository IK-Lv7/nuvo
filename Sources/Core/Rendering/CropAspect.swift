import CoreGraphics

/// トリミングの縦横比。幅 / 高さで表し、中央から切り出す。
public enum CropAspect: String, CaseIterable, Sendable, Codable {
    case square, r4x5, r3x4, r9x16, r16x9, r4x3

    var ratio: CGFloat {
        switch self {
        case .square: 1
        case .r4x5: 4.0 / 5.0
        case .r3x4: 3.0 / 4.0
        case .r9x16: 9.0 / 16.0
        case .r16x9: 16.0 / 9.0
        case .r4x3: 4.0 / 3.0
        }
    }
}
