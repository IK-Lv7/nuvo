import NuvoCore
import SwiftUI

/// ツールの操作方法。スライダー1本で足りるものは `slider`、それ以外は専用のパネルを持つ。
enum EditorToolKind {
    case slider(WritableKeyPath<AdjustmentParameters, Double>, ClosedRange<Double>)
    case filters
    case backgroundColor
    case idPhoto
    case blemish
    case autoEnhance
    case orientation
    case aspect
    case text
    case looks
    case people
    case lipstick
    case cutout
}

struct EditorTool: Identifiable {
    let id: String
    let icon: String
    let kind: EditorToolKind

    var title: LocalizedStringKey { LocalizedStringKey.dynamic("tool." + id) }

    /// 操作部の高さ。ツールを切り替えても写真が上下に動かないよう、ツールごとに固定する。
    var panelHeight: CGFloat {
        switch kind {
        case .text: 252
        case .looks: 140
        case .lipstick: 176
        case .cutout: 176
        default: 108
        }
    }

    /// 初期値から変更されているか。ツールのアイコンに印を付けるために使う。
    func isModified(_ p: AdjustmentParameters) -> Bool {
        switch kind {
        // 既定値との比較。ズームのように、既定値が 0 ではないスライダーがあるため。
        case .slider(let keyPath, _): p[keyPath: keyPath] != AdjustmentParameters()[keyPath: keyPath]
        case .filters: p.filter != nil
        case .backgroundColor: p.backgroundColor != nil
        case .idPhoto: p.idPhoto != nil
        case .blemish: !p.spots.isEmpty
        case .autoEnhance: p.autoEnhance
        case .orientation: p.rotationQuarterTurns != 0 || p.flipHorizontal
        case .aspect: p.cropAspect != nil
        case .text: !p.texts.isEmpty
        case .looks: false
        case .people: !p.excludedFaces.isEmpty
        case .lipstick: p.lipstick != 0 || p.lipstickColor != nil
        case .cutout: p.maskStrokes?.isEmpty == false
        }
    }
}

struct ToolCategory: Identifiable {
    let id: String
    let icon: String
    let tools: [EditorTool]

    var title: LocalizedStringKey { LocalizedStringKey.dynamic("category." + id) }
}

/// 編集ツールの一覧。画面はここを描くだけで、項目の追加・並べ替えはここだけで済む。
enum EditorCatalog {
    private static let both = AdjustmentParameters.range
    private static let intensity = AdjustmentParameters.intensityRange
    private static let zoom = AdjustmentParameters.zoomRange

    static let categories: [ToolCategory] = [
        ToolCategory(id: "skin", icon: "face.smiling", tools: [
            EditorTool(id: "skinSmoothing", icon: "sparkles", kind: .slider(\.skinSmoothing, both)),
            EditorTool(id: "skinBrightness", icon: "sun.max", kind: .slider(\.skinBrightness, both)),
            EditorTool(id: "skinFlush", icon: "heart.fill", kind: .slider(\.skinFlush, both)),
            EditorTool(id: "darkCircles", icon: "eye", kind: .slider(\.darkCircles, intensity)),
            EditorTool(id: "blemish", icon: "bandage", kind: .blemish),
        ]),
        // 2 人以上が写っている写真のときだけ、画面に出る(EditorView)。
        ToolCategory(id: "people", icon: "person.2", tools: [
            EditorTool(id: "people", icon: "person.crop.circle.badge.checkmark", kind: .people),
        ]),
        ToolCategory(id: "face", icon: "person.crop.circle", tools: [
            EditorTool(id: "faceSlim", icon: "arrow.left.and.right", kind: .slider(\.faceSlim, both)),
            EditorTool(id: "eyeEnlarge", icon: "eye.circle", kind: .slider(\.eyeEnlarge, both)),
            EditorTool(id: "chin", icon: "arrow.up.and.down", kind: .slider(\.chin, both)),
            EditorTool(id: "noseSlim", icon: "arrow.left.and.right.circle", kind: .slider(\.noseSlim, both)),
            EditorTool(id: "noseBridge", icon: "highlighter", kind: .slider(\.noseBridge, intensity)),
        ]),
        ToolCategory(id: "makeup", icon: "paintbrush.pointed", tools: [
            EditorTool(id: "lipstick", icon: "mouth", kind: .lipstick),
            EditorTool(id: "blush", icon: "circle.dotted", kind: .slider(\.blush, intensity)),
            EditorTool(id: "eyebrow", icon: "eyebrow", kind: .slider(\.eyebrow, intensity)),
            EditorTool(id: "teethWhitening", icon: "sparkle", kind: .slider(\.teethWhitening, intensity)),
        ]),
        ToolCategory(id: "background", icon: "person.and.background.dotted", tools: [
            EditorTool(id: "backgroundBlur", icon: "aperture", kind: .slider(\.backgroundBlur, intensity)),
            EditorTool(id: "backgroundColor", icon: "paintpalette", kind: .backgroundColor),
            EditorTool(id: "backgroundCutout", icon: "paintbrush.pointed.fill", kind: .cutout),
            EditorTool(id: "idPhoto", icon: "person.text.rectangle", kind: .idPhoto),
        ]),
        ToolCategory(id: "crop", icon: "crop", tools: [
            EditorTool(id: "orientation", icon: "rotate.right", kind: .orientation),
            EditorTool(id: "straighten", icon: "level", kind: .slider(\.straighten, both)),
            EditorTool(id: "aspect", icon: "aspectratio", kind: .aspect),
            EditorTool(id: "cropZoom", icon: "plus.magnifyingglass", kind: .slider(\.cropZoom, zoom)),
        ]),
        ToolCategory(id: "text", icon: "textformat", tools: [
            EditorTool(id: "text", icon: "textformat", kind: .text),
        ]),
        ToolCategory(id: "filter", icon: "camera.filters", tools: [
            EditorTool(id: "filter", icon: "camera.filters", kind: .filters),
            EditorTool(id: "filmGrain", icon: "circle.grid.3x3", kind: .slider(\.filmGrain, intensity)),
            EditorTool(id: "lightLeak", icon: "rays", kind: .slider(\.lightLeak, intensity)),
        ]),
        ToolCategory(id: "adjust", icon: "slider.horizontal.3", tools: [
            EditorTool(id: "brightness", icon: "sun.max.fill", kind: .slider(\.brightness, both)),
            EditorTool(id: "contrast", icon: "circle.lefthalf.filled", kind: .slider(\.contrast, both)),
            EditorTool(id: "saturation", icon: "drop.fill", kind: .slider(\.saturation, both)),
            EditorTool(id: "warmth", icon: "thermometer.medium", kind: .slider(\.warmth, both)),
        ]),
        ToolCategory(id: "finish", icon: "wand.and.stars", tools: [
            EditorTool(id: "autoEnhance", icon: "wand.and.stars", kind: .autoEnhance),
            EditorTool(id: "shadows", icon: "moon", kind: .slider(\.shadows, both)),
            EditorTool(id: "highlightRecovery", icon: "sun.haze", kind: .slider(\.highlightRecovery, intensity)),
            EditorTool(id: "sharpness", icon: "triangle", kind: .slider(\.sharpness, intensity)),
            EditorTool(id: "vignette", icon: "circle.dashed", kind: .slider(\.vignette, intensity)),
        ]),
        ToolCategory(id: "look", icon: "bookmark", tools: [
            EditorTool(id: "looks", icon: "bookmark", kind: .looks),
        ]),
    ]
}
