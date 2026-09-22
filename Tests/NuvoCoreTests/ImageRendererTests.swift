import CoreGraphics
import CoreImage
import XCTest
@testable import NuvoCore

final class ImageRendererTests: XCTestCase {
    private let renderer = ImageRenderer()

    private func solidImage(red: CGFloat, green: CGFloat, blue: CGFloat,
                            width: CGFloat = 4, height: CGFloat = 4) -> CIImage {
        CIImage(color: CIColor(red: red, green: green, blue: blue))
            .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    }

    /// 画像を 1x1 に描画して RGB を読む。色管理の丸めがあるため比較は許容誤差付きで行う。
    private func rgb(of image: CGImage) -> [Int]? {
        var pixel = [UInt8](repeating: 0, count: 4)
        let drawn: Bool = pixel.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard drawn else { return nil }
        return pixel.prefix(3).map { Int($0) }
    }

    private func renderedRGB(_ parameters: AdjustmentParameters,
                             red: CGFloat = 0.5, green: CGFloat = 0.5, blue: CGFloat = 0.5) -> [Int]? {
        let source = solidImage(red: red, green: green, blue: blue)
        guard let image = renderer.render(renderer.makeSource(image: source), parameters: parameters) else { return nil }
        return rgb(of: image)
    }

    func testIdentityKeepsMidGray() throws {
        let pixel = try XCTUnwrap(renderedRGB(AdjustmentParameters()))
        XCTAssertEqual(pixel[0], 128, accuracy: 4)
    }

    func testBrightnessMovesInExpectedDirection() throws {
        var brighter = AdjustmentParameters()
        brighter.brightness = 1
        var darker = AdjustmentParameters()
        darker.brightness = -1
        let base = try XCTUnwrap(renderedRGB(AdjustmentParameters()))[0]
        XCTAssertGreaterThan(try XCTUnwrap(renderedRGB(brighter))[0], base)
        XCTAssertLessThan(try XCTUnwrap(renderedRGB(darker))[0], base)
    }

    func testSaturationChangesColorSpread() throws {
        var vivid = AdjustmentParameters()
        vivid.saturation = 1
        var muted = AdjustmentParameters()
        muted.saturation = -1
        let vividPixel = try XCTUnwrap(renderedRGB(vivid, red: 0.8, green: 0.4, blue: 0.4))
        let mutedPixel = try XCTUnwrap(renderedRGB(muted, red: 0.8, green: 0.4, blue: 0.4))
        XCTAssertGreaterThan(vividPixel[0] - vividPixel[1], mutedPixel[0] - mutedPixel[1])
    }

    func testDownscaleLimitsLongEdge() {
        let large = solidImage(red: 0, green: 0, blue: 0, width: 4000, height: 2000)
        let scaled = renderer.downscaled(large, longEdge: 1536)
        XCTAssertEqual(scaled.extent.width, 1536, accuracy: 2)
    }

    func testDownscaleDoesNotUpscale() {
        let small = solidImage(red: 0, green: 0, blue: 0, width: 100, height: 50)
        XCTAssertEqual(renderer.downscaled(small).extent.width, 100)
    }

    func testJPEGExportProducesData() {
        let source = renderer.makeSource(image: solidImage(red: 0.2, green: 0.4, blue: 0.6))
        let data = renderer.jpegData(source, parameters: AdjustmentParameters())
        XCTAssertNotNil(data)
    }
}

final class BackgroundAndToneTests: XCTestCase {
    private let renderer = ImageRenderer()
    private let side = 8

    private func solid(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CIImage {
        CIImage(color: CIColor(red: red, green: green, blue: blue))
            .cropped(to: CGRect(x: 0, y: 0, width: side, height: side))
    }

    /// 左半分が人物(白)、右半分が背景(黒)のマスク。
    private func leftHalfMask() throws -> SubjectMask {
        let white = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: side / 2, height: side))
        let black = CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: side, height: side))
        return try XCTUnwrap(SubjectMask(image: white.composited(over: black), context: CIContext()))
    }

    private func pixels(_ parameters: AdjustmentParameters, source: CIImage,
                        mask: SubjectMask? = nil) throws -> [UInt8] {
        let rendered = renderer.makeSource(image: source, subjectMask: mask)
        let cgImage = try XCTUnwrap(renderer.render(rendered, parameters: parameters))
        return try XCTUnwrap(BitmapIO.rgba(from: cgImage))
    }

    private func pixel(_ data: [UInt8], x: Int, y: Int) -> [Int] {
        let i = (y * side + x) * 4
        return [Int(data[i]), Int(data[i + 1]), Int(data[i + 2])]
    }

    func testColorBackgroundReplacesOnlyOutsideTheSubject() throws {
        var p = AdjustmentParameters()
        p.backgroundColor = .white
        let data = try pixels(p, source: solid(1, 0, 0), mask: try leftHalfMask())
        let subject = pixel(data, x: 1, y: 4)
        let background = pixel(data, x: 6, y: 4)
        XCTAssertEqual(subject[1], 0, accuracy: 8)
        XCTAssertEqual(subject[0], 255, accuracy: 8)
        XCTAssertEqual(background[1], 255, accuracy: 8)
    }

    func testBackgroundEffectNeedsAMask() throws {
        var p = AdjustmentParameters()
        p.backgroundColor = .white
        let data = try pixels(p, source: solid(1, 0, 0))
        XCTAssertEqual(pixel(data, x: 6, y: 4)[1], 0, accuracy: 8)
    }

    /// 左半分が人物(白)、右半分が背景(黒)の、大きめのマスクと画像(ペンの半径を確かめやすくするため)。
    private func wideLeftHalfMask(width: Int = 200, height: Int = 100) throws -> SubjectMask {
        let white = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: width / 2, height: height))
        let black = CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        return try XCTUnwrap(SubjectMask(image: white.composited(over: black), context: CIContext()))
    }

    private func widePixels(_ parameters: AdjustmentParameters, mask: SubjectMask,
                            width: Int = 200, height: Int = 100) throws -> [UInt8] {
        let source = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        let rendered = renderer.makeSource(image: source, subjectMask: mask)
        let cgImage = try XCTUnwrap(renderer.render(rendered, parameters: parameters))
        return try XCTUnwrap(BitmapIO.rgba(from: cgImage))
    }

    private func widePixel(_ data: [UInt8], x: Int, y: Int, width: Int = 200) -> [Int] {
        let i = (y * width + x) * 4
        return [Int(data[i]), Int(data[i + 1]), Int(data[i + 2])]
    }

    func testEraseStrokeExtendsTheBackgroundIntoTheSubjectSide() throws {
        // マスクは左半分(x < 100)が人物。人物側の内側 (70, 50) を「消す」ペンで背景に変える。
        var p = AdjustmentParameters()
        p.backgroundColor = .white
        p.maskStrokes = [MaskStroke(points: [CGPoint(x: 0.35, y: 0.5)], radius: 0.15, mode: .erase)]
        let data = try widePixels(p, mask: try wideLeftHalfMask())
        // もともと人物側だった場所が、消したことで背景色(白)になる。
        XCTAssertEqual(widePixel(data, x: 70, y: 50)[1], 255, accuracy: 8)
        // 遠く離れた人物側は、消しゴムの外なので影響を受けない(赤いまま)。
        XCTAssertEqual(widePixel(data, x: 5, y: 50)[0], 255, accuracy: 8)
        XCTAssertEqual(widePixel(data, x: 5, y: 50)[1], 0, accuracy: 8)
    }

    func testKeepStrokeProtectsPartOfTheBackgroundSide() throws {
        // マスクは右半分(x >= 100)が背景。背景側の内側 (130, 50) を「足す」ペンで人物として残す。
        var p = AdjustmentParameters()
        p.backgroundColor = .white
        p.maskStrokes = [MaskStroke(points: [CGPoint(x: 0.65, y: 0.5)], radius: 0.15, mode: .keep)]
        let data = try widePixels(p, mask: try wideLeftHalfMask())
        XCTAssertEqual(widePixel(data, x: 130, y: 50)[0], 255, accuracy: 8)
        XCTAssertEqual(widePixel(data, x: 130, y: 50)[1], 0, accuracy: 8)
    }

    func testSubjectMaskFindsTheTopEdge() throws {
        // 白い矩形が下から 7 行分 → 上から 3 行目(0.3)で人物が始まる。
        let white = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 10, height: 7))
        let black = CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: 10, height: 10))
        let mask = try XCTUnwrap(SubjectMask(image: white.composited(over: black), context: CIContext()))
        XCTAssertEqual(try XCTUnwrap(mask.topEdge(columns: 0...1)), 0.3, accuracy: 0.05)
    }

    func testWarmthTurnsGrayTowardRed() throws {
        var p = AdjustmentParameters()
        p.warmth = 1
        let warm = pixel(try pixels(p, source: solid(0.5, 0.5, 0.5)), x: 4, y: 4)
        XCTAssertGreaterThan(warm[0], warm[2])
        p.warmth = -1
        let cool = pixel(try pixels(p, source: solid(0.5, 0.5, 0.5)), x: 4, y: 4)
        XCTAssertLessThan(cool[0], cool[2])
    }

    func testFinishingToolsKeepTheImageSize() throws {
        var p = AdjustmentParameters()
        p.autoEnhance = true
        p.sharpness = 1
        p.vignette = 1
        p.shadows = 0.5
        p.highlightRecovery = 0.5
        let source = renderer.makeSource(image: solid(0.4, 0.5, 0.6))
        let cgImage = try XCTUnwrap(renderer.render(source, parameters: p))
        XCTAssertEqual(cgImage.width, side)
        XCTAssertEqual(cgImage.height, side)
    }

    func testHighResolutionDoublesTheExportedSize() throws {
        var p = AdjustmentParameters()
        p.highResolution = true
        let source = renderer.makeSource(image: solid(0.4, 0.5, 0.6))
        let cgImage = try XCTUnwrap(renderer.render(source, parameters: p))
        XCTAssertEqual(cgImage.width, side * 2)
        XCTAssertEqual(cgImage.height, side * 2)
    }

    func testHighResolutionOffKeepsTheOriginalSize() throws {
        // 既定(nil)は「しない」。以前のバージョンで保存したルックと同じ大きさで書き出す。
        let source = renderer.makeSource(image: solid(0.4, 0.5, 0.6))
        let cgImage = try XCTUnwrap(renderer.render(source, parameters: AdjustmentParameters()))
        XCTAssertEqual(cgImage.width, side)
        XCTAssertEqual(cgImage.height, side)
    }

    func testVignetteDarkensTheCornersMoreThanTheCenter() throws {
        var p = AdjustmentParameters()
        p.vignette = 1
        let big = CIImage(color: CIColor(red: 0.8, green: 0.8, blue: 0.8))
            .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
        let source = renderer.makeSource(image: big)
        let cgImage = try XCTUnwrap(renderer.render(source, parameters: p))
        let data = try XCTUnwrap(BitmapIO.rgba(from: cgImage))
        let corner = Int(data[0])
        let center = Int(data[(32 * 64 + 32) * 4])
        XCTAssertLessThan(corner, center)
    }

    // MARK: 質感

    func testGrainAddsVariationToAFlatImage() throws {
        var p = AdjustmentParameters()
        p.filmGrain = 1
        let big = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
        let cgImage = try XCTUnwrap(renderer.render(renderer.makeSource(image: big), parameters: p))
        let data = try XCTUnwrap(BitmapIO.rgba(from: cgImage))
        let values = stride(from: 0, to: data.count, by: 4).map { Int(data[$0]) }
        XCTAssertGreaterThan((values.max() ?? 0) - (values.min() ?? 0), 4)
    }

    func testGrainIsRepeatable() throws {
        var p = AdjustmentParameters()
        p.filmGrain = 0.8
        let big = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: CGRect(x: 0, y: 0, width: 32, height: 32))
        let first = try XCTUnwrap(BitmapIO.rgba(from: try XCTUnwrap(renderer.render(renderer.makeSource(image: big), parameters: p))))
        let second = try XCTUnwrap(BitmapIO.rgba(from: try XCTUnwrap(renderer.render(renderer.makeSource(image: big), parameters: p))))
        XCTAssertEqual(first, second)
    }

    func testLightLeakBrightensTheTopRightMoreThanTheBottomLeft() throws {
        var p = AdjustmentParameters()
        p.lightLeak = 1
        let dark = CIImage(color: CIColor(red: 0.1, green: 0.1, blue: 0.1)).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
        let cgImage = try XCTUnwrap(renderer.render(renderer.makeSource(image: dark), parameters: p))
        let data = try XCTUnwrap(BitmapIO.rgba(from: cgImage))
        let topRight = Int(data[(2 * 64 + 61) * 4])     // 上端・右端(画像の上は行 0)
        let center = Int(data[(32 * 64 + 32) * 4])
        XCTAssertGreaterThan(topRight, center)
        XCTAssertGreaterThan(topRight, 40)               // 元の暗さ(約 26)より明確に明るい
    }

    func testTextureKeepsTheImageSize() throws {
        var p = AdjustmentParameters()
        p.filmGrain = 1
        p.lightLeak = 1
        let image = CIImage(color: CIColor(red: 0.4, green: 0.4, blue: 0.4)).cropped(to: CGRect(x: 0, y: 0, width: 40, height: 30))
        let cgImage = try XCTUnwrap(renderer.render(renderer.makeSource(image: image), parameters: p))
        XCTAssertEqual(cgImage.width, 40)
        XCTAssertEqual(cgImage.height, 30)
    }
}

