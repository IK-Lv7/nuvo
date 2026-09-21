/** Sources/Core/FaceAnalysis/FaceSelection.swift に対応する。試作では顔検出をしないので、顔は決め打ちの位置に置く。 */
export type FaceBox = { x: number; y: number; w: number; h: number };
export type Point = { x: number; y: number };

/** 写真に対する相対位置(0...1、左上原点)。実際の写真の顔とは一致しない。目印の見た目と操作を確かめるためのもの。 */
export const mockFaces: FaceBox[] = [
  { x: 0.1, y: 0.35, w: 0.22, h: 0.2 },
  { x: 0.38, y: 0.28, w: 0.26, h: 0.24 },
  { x: 0.7, y: 0.38, w: 0.2, h: 0.18 },
];

const TAP_PADDING = 0.15;
const area = (f: FaceBox) => f.w * f.h;
const center = (f: FaceBox): Point => ({ x: f.x + f.w / 2, y: f.y + f.h / 2 });

/** タップした位置にある顔の番号。重なっているときは小さい顔を優先する。 */
export function faceIndexAt(p: Point, faces: FaceBox[] = mockFaces): number | null {
  let best: number | null = null;
  faces.forEach((f, i) => {
    const padX = f.w * TAP_PADDING, padY = f.h * TAP_PADDING;
    const hit = p.x >= f.x - padX && p.x <= f.x + f.w + padX && p.y >= f.y - padY && p.y <= f.y + f.h + padY;
    if (hit && (best === null || area(f) < area(faces[best]))) best = i;
  });
  return best;
}

/** 偶奇規則による点の内外判定。 */
function contains(polygon: Point[], p: Point): boolean {
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const a = polygon[i], b = polygon[j];
    if ((a.y > p.y) !== (b.y > p.y) && p.x < ((b.x - a.x) * (p.y - a.y)) / (b.y - a.y) + a.x) inside = !inside;
  }
  return inside;
}

/** 指で囲んだ線の内側に、顔の中心が入っている顔の番号。3 点未満は囲みにならない。 */
export function indicesInsideLasso(lasso: Point[], faces: FaceBox[] = mockFaces): number[] {
  if (lasso.length < 3) return [];
  return faces.map((f, i) => (contains(lasso, center(f)) ? i : -1)).filter((i) => i >= 0);
}

/** 選ばれていない顔の番号(昇順)から、選ばれている顔の集合を求める。 */
export const selectedFaces = (unselected: number[], count = mockFaces.length): number[] =>
  Array.from({ length: count }, (_, i) => i).filter((i) => !unselected.includes(i));

export const unselectedFrom = (kept: number[], count = mockFaces.length): number[] =>
  Array.from({ length: count }, (_, i) => i).filter((i) => !kept.includes(i));
