import type { ComponentProps } from 'react';
import type { Ionicons } from '@expo/vector-icons';

type IconName = ComponentProps<typeof Ionicons>['name'];

/** Sources/Features/Editor/EditorTool.swift の EditorCatalog に対応する。 */
export type ToolKind =
  | { type: 'slider'; min: number; max: number }
  | { type: 'filters' }
  | { type: 'backgroundColor' }
  | { type: 'idPhoto' }
  | { type: 'blemish' }
  | { type: 'autoEnhance' }
  | { type: 'orientation' }
  | { type: 'aspect' }
  | { type: 'text' }
  | { type: 'looks' };

export type Tool = { id: string; title: string; icon: IconName; kind: ToolKind };
/** 操作部の高さ。ツールを切り替えても写真が上下に動かないよう、ツールごとに固定する(EditorTool.panelHeight と同じ値)。 */
export function panelHeight(tool: Tool): number {
  switch (tool.kind.type) {
    case 'text': return 252;
    case 'looks': return 140;
    default: return 108;
  }
}

export type Category = { id: string; title: string; icon: IconName; tools: Tool[] };

const both = { type: 'slider', min: -1, max: 1 } as const;
const intensity = { type: 'slider', min: 0, max: 1 } as const;
const zoom = { type: 'slider', min: 1, max: 4 } as const;

export const categories: Category[] = [
  { id: 'skin', title: '美肌', icon: 'happy-outline', tools: [
    { id: 'skinSmoothing', title: 'なめらか', icon: 'sparkles-outline', kind: both },
    { id: 'skinBrightness', title: '明るさ', icon: 'sunny-outline', kind: both },
    { id: 'skinFlush', title: '血色', icon: 'heart-outline', kind: both },
    { id: 'darkCircles', title: 'くま', icon: 'eye-outline', kind: intensity },
    { id: 'blemish', title: 'ニキビ', icon: 'bandage-outline', kind: { type: 'blemish' } },
  ] },
  { id: 'face', title: '顔立ち', icon: 'person-circle-outline', tools: [
    { id: 'faceSlim', title: '小顔', icon: 'swap-horizontal-outline', kind: both },
    { id: 'eyeEnlarge', title: '目', icon: 'eye-outline', kind: both },
    { id: 'chin', title: 'あご', icon: 'swap-vertical-outline', kind: both },
    { id: 'noseSlim', title: '鼻', icon: 'triangle-outline', kind: both },
    { id: 'noseBridge', title: '鼻筋', icon: 'trending-up-outline', kind: intensity },
  ] },
  { id: 'makeup', title: 'メイク', icon: 'brush-outline', tools: [
    { id: 'lipstick', title: 'リップ', icon: 'heart-outline', kind: intensity },
    { id: 'blush', title: 'チーク', icon: 'ellipse-outline', kind: intensity },
    { id: 'eyebrow', title: '眉', icon: 'remove-outline', kind: intensity },
    { id: 'teethWhitening', title: '歯', icon: 'sparkles-outline', kind: intensity },
  ] },
  { id: 'background', title: '背景', icon: 'image-outline', tools: [
    { id: 'backgroundBlur', title: 'ぼかし', icon: 'aperture-outline', kind: intensity },
    { id: 'backgroundColor', title: '背景色', icon: 'color-palette-outline', kind: { type: 'backgroundColor' } },
    { id: 'idPhoto', title: '証明写真', icon: 'id-card-outline', kind: { type: 'idPhoto' } },
  ] },
  { id: 'crop', title: '構図', icon: 'crop-outline', tools: [
    { id: 'orientation', title: '回転・反転', icon: 'refresh-outline', kind: { type: 'orientation' } },
    { id: 'straighten', title: '傾き', icon: 'analytics-outline', kind: both },
    { id: 'aspect', title: '比率', icon: 'scan-outline', kind: { type: 'aspect' } },
    { id: 'cropZoom', title: 'ズーム', icon: 'search-outline', kind: zoom },
  ] },
  { id: 'text', title: '文字', icon: 'text-outline', tools: [
    { id: 'text', title: '文字', icon: 'text-outline', kind: { type: 'text' } },
  ] },
  { id: 'filter', title: 'フィルター', icon: 'color-filter-outline', tools: [
    { id: 'filter', title: 'フィルター', icon: 'color-filter-outline', kind: { type: 'filters' } },
    { id: 'filmGrain', title: '粒子', icon: 'grid-outline', kind: intensity },
    { id: 'lightLeak', title: '光漏れ', icon: 'flash-outline', kind: intensity },
  ] },
  { id: 'adjust', title: '調整', icon: 'options-outline', tools: [
    { id: 'brightness', title: '明るさ', icon: 'sunny-outline', kind: both },
    { id: 'contrast', title: 'コントラスト', icon: 'contrast-outline', kind: both },
    { id: 'saturation', title: '彩度', icon: 'water-outline', kind: both },
    { id: 'warmth', title: '色温度', icon: 'thermometer-outline', kind: both },
  ] },
  { id: 'finish', title: '仕上げ', icon: 'color-wand-outline', tools: [
    { id: 'autoEnhance', title: '自動補正', icon: 'color-wand-outline', kind: { type: 'autoEnhance' } },
    { id: 'shadows', title: 'シャドウ', icon: 'moon-outline', kind: both },
    { id: 'highlightRecovery', title: 'ハイライト', icon: 'sunny-outline', kind: intensity },
    { id: 'sharpness', title: 'シャープ', icon: 'triangle-outline', kind: intensity },
    { id: 'vignette', title: '周辺減光', icon: 'radio-button-off-outline', kind: intensity },
  ] },
  { id: 'look', title: 'ルック', icon: 'bookmark-outline', tools: [
    { id: 'looks', title: 'ルック', icon: 'bookmark-outline', kind: { type: 'looks' } },
  ] },
];

/** LUTFilter.swift の FilterPreset と同じ 18 種。 */
export const filterOptions = [
  { id: 'warm', title: 'ウォーム' }, { id: 'cool', title: 'クール' }, { id: 'film', title: 'フィルム' },
  { id: 'fade', title: 'フェード' }, { id: 'vivid', title: 'ビビッド' }, { id: 'mono', title: 'モノ' },
  { id: 'sunset', title: 'サンセット' }, { id: 'peach', title: 'ピーチ' }, { id: 'rose', title: 'ローズ' },
  { id: 'mint', title: 'ミント' }, { id: 'sky', title: 'スカイ' }, { id: 'matte', title: 'マット' },
  { id: 'cinematic', title: 'シネマ' }, { id: 'vintage', title: 'ヴィンテージ' }, { id: 'noir', title: 'ノワール' },
  { id: 'pastel', title: 'パステル' }, { id: 'polaroid', title: 'ポラロイド' }, { id: 'moody', title: 'ムーディ' },
];
export const backgroundColors = [
  { id: 'white', title: '白' }, { id: 'lightBlue', title: '水色' }, { id: 'lightGray', title: 'グレー' },
];
export const idPhotoOptions = [
  { id: 'passport', title: 'パスポート・マイナンバー 35×45' }, { id: 'resume', title: '履歴書 30×40' },
];

/** 縦横比プリセット(幅 / 高さ)。CropAspect.swift と同じ値。 */
export const cropOptions = [
  { id: 'square', title: '1:1', ratio: 1 }, { id: 'r4x5', title: '4:5', ratio: 4 / 5 },
  { id: 'r3x4', title: '3:4', ratio: 3 / 4 }, { id: 'r9x16', title: '9:16', ratio: 9 / 16 },
  { id: 'r16x9', title: '16:9', ratio: 16 / 9 }, { id: 'r4x3', title: '4:3', ratio: 4 / 3 },
];
export const textColors = [
  { id: '#FFFFFF', title: '白' }, { id: '#000000', title: '黒' }, { id: '#FF8A9E', title: 'ピンク' }, { id: '#FFDB4D', title: '黄' },
];
/** TextOverlay.swift の TextStyle と同じ書体。すべて端末に入っているフォントで、PostScript 名で呼ぶ。bold が無いものは太字指定で代用する。 */
export const textStyles = [
  { id: 'standard', title: '標準' },
  { id: 'serif', title: 'セリフ', regular: 'Georgia', bold: 'Georgia-Bold' },
  { id: 'rounded', title: '丸文字', regular: 'ArialRoundedMTBold' },
  { id: 'mono', title: '等幅', regular: 'Menlo-Regular', bold: 'Menlo-Bold' },
  { id: 'gothic', title: 'ゴシック', regular: 'HiraginoSans-W3', bold: 'HiraginoSans-W6' },
  { id: 'mincho', title: '明朝体', regular: 'HiraMinProN-W3', bold: 'HiraMinProN-W6' },
  { id: 'maru', title: '丸ゴ', regular: 'HiraMaruProN-W4' },
  { id: 'script', title: '筆記体', regular: 'SnellRoundhand', bold: 'SnellRoundhand-Bold' },
  { id: 'handwriting', title: '手書き', regular: 'Noteworthy-Light', bold: 'Noteworthy-Bold' },
  { id: 'marker', title: 'マーカー', regular: 'MarkerFelt-Thin', bold: 'MarkerFelt-Wide' },
  { id: 'condensed', title: 'コンデンス', regular: 'Futura-CondensedMedium', bold: 'Futura-CondensedExtraBold' },
  { id: 'didot', title: 'ディド', regular: 'Didot', bold: 'Didot-Bold' },
  { id: 'typewriter', title: 'タイプライター', regular: 'AmericanTypewriter', bold: 'AmericanTypewriter-Bold' },
] as { id: string; title: string; regular?: string; bold?: string }[];

export const exportFormats = [
  { id: 'jpeg', title: 'JPEG' }, { id: 'heic', title: 'HEIC' }, { id: 'png', title: 'PNG' },
];

/** スライダーの既定値。中央がゼロの範囲と、0 から始まる範囲は 0、ズームのように 0 を含まない範囲は下限(AdjustmentParameters の既定値と同じ)。 */
export function sliderDefault(kind: { min: number; max: number }): number {
  return kind.min <= 0 && kind.max >= 0 ? 0 : kind.min;
}
