import { useCallback, useState } from 'react';
import { sliderDefault, type Tool } from './catalog';

export type TextItem = {
  id: string; text: string; x: number; y: number; size: number;
  color: string; style: string; bold: boolean; shadow: boolean;
};

/** AdjustmentParameters.swift に対応する。画面はこれを書き換えるだけにする。 */
export type Params = {
  values: Record<string, number>;
  filter: string | null;
  filterIntensity: number;
  bgColor: string | null;
  idPhoto: string | null;
  autoEnhance: boolean;
  spots: number;
  /** 時計回りに 90° の回数(0...3)。 */
  rotation: number;
  flip: boolean;
  cropAspect: string | null;
  /** ズーム(アップ)の中心。構図を決めた枠に対する相対位置(0...1、左上原点)。 */
  cropCenter: { x: number; y: number };
  texts: TextItem[];
  /** 加工の対象から外した顔の番号。空なら全員が対象。 */
  unselected: number[];
  /** リップの色(16進コード)。null は既定の色(lipstickPresets の rose)。 */
  lipstickColor: string | null;
};

export const initialParams: Params = {
  values: {}, filter: null, filterIntensity: 1, bgColor: null, idPhoto: null, autoEnhance: false, spots: 0,
  rotation: 0, flip: false, cropAspect: null, cropCenter: { x: 0.5, y: 0.5 }, texts: [], unselected: [], lipstickColor: null,
};

export function isModified(tool: Tool, p: Params): boolean {
  switch (tool.kind.type) {
    case 'slider': return (p.values[tool.id] ?? sliderDefault(tool.kind)) !== sliderDefault(tool.kind);
    case 'filters': return p.filter !== null;
    case 'backgroundColor': return p.bgColor !== null;
    case 'idPhoto': return p.idPhoto !== null;
    case 'blemish': return p.spots > 0;
    case 'autoEnhance': return p.autoEnhance;
    case 'orientation': return p.rotation !== 0 || p.flip;
    case 'aspect': return p.cropAspect !== null;
    case 'text': return p.texts.length > 0;
    case 'looks': return false;
    case 'people': return p.unselected.length > 0;
    case 'lipstick': return (p.values[tool.id] ?? sliderDefault({ min: 0, max: 1 })) !== 0 || p.lipstickColor !== null;
  }
}

/** UndoHistory.swift と同じ考え方。スライダー操作中は live だけを動かし、指を離したときに履歴へ積む。 */
export function useEditorState() {
  const [live, setLive] = useState<Params>(initialParams);
  const [past, setPast] = useState<Params[]>([]);
  const [future, setFuture] = useState<Params[]>([]);
  const [committed, setCommitted] = useState<Params>(initialParams);

  const change = useCallback((next: (p: Params) => Params) => setLive(next), []);

  const commit = useCallback((next?: (p: Params) => Params) => {
    const value = next ? next(live) : live;
    if (JSON.stringify(value) === JSON.stringify(committed)) { setLive(value); return; }
    setPast((h) => [...h, committed]);
    setFuture([]);
    setCommitted(value);
    setLive(value);
  }, [live, committed]);

  const undo = useCallback(() => {
    const previous = past[past.length - 1];
    if (!previous) return;
    setPast(past.slice(0, -1));
    setFuture((f) => [...f, committed]);
    setCommitted(previous);
    setLive(previous);
  }, [past, committed]);

  const redo = useCallback(() => {
    const next = future[future.length - 1];
    if (!next) return;
    setFuture(future.slice(0, -1));
    setPast((h) => [...h, committed]);
    setCommitted(next);
    setLive(next);
  }, [future, committed]);

  const reset = useCallback(() => {
    setLive(initialParams); setCommitted(initialParams); setPast([]); setFuture([]);
  }, []);

  return { params: live, change, commit, undo, redo, reset, canUndo: past.length > 0, canRedo: future.length > 0 };
}

/** 構図を変えているか。変えている間は、タップでの修復位置が最終画像の座標とずれるため使えない。 */
export function hasComposition(p: Params): boolean {
  return p.rotation !== 0 || p.flip || (p.values.straighten ?? 0) !== 0 || p.cropAspect !== null
    || (p.values.cropZoom ?? 1) !== 1 || p.idPhoto !== null;
}

/** ルックとして保存する範囲。写真ごとの内容(修復・構図・文字・証明写真・加工する人)は含めない(AdjustmentParameters.lookOnly と同じ)。 */
export function lookOf(p: Params): Params {
  const { straighten: _straighten, cropZoom: _cropZoom, ...values } = p.values;
  return { ...p, values, spots: 0, texts: [], rotation: 0, flip: false, cropAspect: null, cropCenter: { x: 0.5, y: 0.5 }, idPhoto: null, unselected: [] }; // lipstickColor はスタイルなので残す(look に含める)
}

/** ルックを当てる。この写真の修復・構図・文字・証明写真は保つ(AdjustmentParameters.applyingLook と同じ)。 */
export function applyingLook(current: Params, look: Params): Params {
  const values = { ...look.values };
  if (current.values.straighten !== undefined) values.straighten = current.values.straighten;
  if (current.values.cropZoom !== undefined) values.cropZoom = current.values.cropZoom;
  return {
    ...look, values, spots: current.spots, texts: current.texts, rotation: current.rotation,
    flip: current.flip, cropAspect: current.cropAspect, cropCenter: current.cropCenter, idPhoto: current.idPhoto,
    unselected: current.unselected,
  };
}
