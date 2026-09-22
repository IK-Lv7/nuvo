import CoreImage
import CoreImage.CIFilterBuiltins

/// 切り抜きマスクを、薄いピンクの半透明画像にする。「切り抜きを直す」ペンで、
/// 今どこが人物として扱われているかを、写真の上に重ねて見せるために使う。
public enum MaskOverlay {
    /// 完全に人物の場所でも、下の写真が透けて見える濃さに抑える。
    private static let maxOpacity: CGFloat = 0.45
    /// アプリの UI と同じローズ色(Sources/App/Theme.swift の accent と同じ値)。
    /// この階層(Core)は UI の色定義を参照しないため、同じ値を書いておく。
    private static let tint = CIVector(x: 1.0, y: 0.54, z: 0.62, w: 0)

    public static func tinted(_ mask: SubjectMask) -> CIImage {
        let filter = CIFilter.colorMatrix()
        filter.inputImage = mask.image
        let zero = CIVector(x: 0, y: 0, z: 0, w: 0)
        filter.rVector = zero
        filter.gVector = zero
        filter.bVector = zero
        // 出力の不透明度は、マスクの明るさ(人物なら白)に比例させる。
        filter.aVector = CIVector(x: maxOpacity, y: 0, z: 0, w: 0)
        filter.biasVector = tint
        return filter.outputImage ?? mask.image
    }
}
