import CoreGraphics

/// 画像を固定サイズの正方形タイルに分割するための計算。
/// Core ML など決まった大きさの入力しか受け付けないモデルを、任意の大きさの画像に適用するために使う。
/// モデルそのものへの依存はここには持たない(座標の計算だけ)。
///
/// 隣接タイルと重ねて処理し(`overlap`)、重なりの部分は結果から間引く。これにより、
/// タイルの境目にできがちな「そこだけ文脈が半分しかない」ことによる継ぎ目を避ける。
public enum TileLayout {
    /// 1枚ぶんのタイル。
    public struct Tile: Equatable {
        /// 元画像から切り出す範囲(左上原点のピクセル座標)。常に `tileSize` 四方で、画像の外に出ない。
        public let sourceRect: CGRect
        /// 結果として採用する範囲(左上原点)。`sourceRect` に含まれる。
        /// すべてのタイルの `keepRect` を合わせると、画像全体にちょうど一致する(隙間も重なりもない)。
        public let keepRect: CGRect
    }

    /// - Parameters:
    ///   - size: 分割したい画像の大きさ(px)。
    ///   - tileSize: モデルが要求する、正方形の入力の一辺(px)。
    ///   - overlap: 隣接タイルと重ねて処理する幅(px)。
    /// - Returns: 行優先(上から下、各行は左から右)に並んだタイルの一覧。
    ///   `tileSize` が画像よりも大きい、または `overlap` が `tileSize` の半分以上など、
    ///   タイルとして成立しない場合は空を返す。
    public static func tiles(for size: CGSize, tileSize: Int, overlap: Int) -> [Tile] {
        guard let xs = axis(extent: Int(size.width.rounded()), tileSize: tileSize, overlap: overlap),
              let ys = axis(extent: Int(size.height.rounded()), tileSize: tileSize, overlap: overlap) else {
            return []
        }
        var tiles: [Tile] = []
        for y in ys {
            for x in xs {
                let source = CGRect(x: x.source.lowerBound, y: y.source.lowerBound,
                                    width: x.source.count, height: y.source.count)
                let keep = CGRect(x: x.keep.lowerBound, y: y.keep.lowerBound,
                                  width: x.keep.count, height: y.keep.count)
                tiles.append(Tile(sourceRect: source, keepRect: keep))
            }
        }
        return tiles
    }

    /// 1軸(横または縦)ぶんの区間。
    struct Segment {
        /// 採用する範囲。同じ軸のすべての `Segment` を合わせると `[0, extent)` にちょうど一致する。
        let keep: Range<Int>
        /// モデルに渡すために元画像から切り出す範囲。常に `tileSize` の幅で `[0, extent)` に収まる。
        let source: Range<Int>
    }

    /// 1軸を `Segment` に分割する。
    /// `keep` はまず `stride`(= `tileSize` - `overlap` * 2)ごとに隙間なく敷き詰め、
    /// `source` はその前後に `overlap` を足した範囲(画像の端では、はみ出さないよう内側にずらす。
    /// パディングはしない)。
    static func axis(extent: Int, tileSize: Int, overlap: Int) -> [Segment]? {
        guard tileSize > overlap * 2, extent >= tileSize else { return nil }
        let stride = tileSize - overlap * 2
        var starts = Swift.stride(from: 0, to: extent, by: stride).map { $0 }
        if let last = starts.last, last >= extent { starts.removeLast() }
        guard !starts.isEmpty else { return nil }

        return starts.enumerated().map { index, start in
            let keepEnd = index == starts.count - 1 ? extent : start + stride
            let keep = start..<keepEnd

            var sourceStart = keep.lowerBound - overlap
            if sourceStart < 0 { sourceStart = 0 }
            var sourceEnd = sourceStart + tileSize
            if sourceEnd > extent {
                sourceEnd = extent
                sourceStart = sourceEnd - tileSize
            }
            return Segment(keep: keep, source: sourceStart..<sourceEnd)
        }
    }
}
