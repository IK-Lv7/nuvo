import CoreGraphics
import NuvoCore

/// 「切り抜きを直す」ペン。自動検出したマスクの上に、ドラッグで「足す」「消す」を描き足す。
/// 描いている間は Undo に積まず、指を離した時点で1回分の操作にする(moveSelectedText と同じ考え方)。
extension EditorViewModel {
    /// 描いた線の、直前の点からの最小間隔(正規化座標)。これより細かく点を足さない(データ量と計算量を抑える)。
    private static let minStrokePointSpacing = 0.004

    /// 自動検出したマスクがあり、構図を変えていないときだけ使える(座標が最終画像とずれるため)。
    var canFixCutout: Bool { hasSubjectMask && !hasComposition }

    /// `unit` は表示中の画像に対する相対位置(0...1、左上原点)。
    func beginMaskStroke(at unit: CGPoint, mode: MaskStroke.Mode, radius: Double) {
        guard canFixCutout else { return }
        let point = clampedUnit(unit)
        mutateWithoutCommitting { p in
            p.maskStrokes = (p.maskStrokes ?? []) + [MaskStroke(points: [point], radius: radius, mode: mode)]
        }
    }

    func extendMaskStroke(to unit: CGPoint) {
        let point = clampedUnit(unit)
        mutateWithoutCommitting { p in
            guard var strokes = p.maskStrokes, var last = strokes.last else { return }
            if let previous = last.points.last,
               hypot(previous.x - point.x, previous.y - point.y) < Self.minStrokePointSpacing { return }
            last.points.append(point)
            strokes[strokes.count - 1] = last
            p.maskStrokes = strokes
        }
    }

    func endMaskStroke() {
        guard parameters.maskStrokes?.isEmpty == false else { return }
        commitEdit()
    }

    /// 描いた線をすべて消し、自動検出の結果に戻す。
    func clearMaskStrokes() {
        guard parameters.maskStrokes?.isEmpty == false else { return }
        update { $0.maskStrokes = nil }
    }

    private func clampedUnit(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, 0), 1), y: min(max(point.y, 0), 1))
    }
}
