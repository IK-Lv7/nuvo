import { useEffect, useMemo, useRef, useState } from 'react';
import {
  GestureResponderEvent, Image, PanResponder, PanResponderGestureState, StyleSheet, Text, View,
} from 'react-native';
import { cropOptions, textStyles } from '../catalog';
import type { Params, TextItem } from '../state';
import { theme } from '../theme';

/** GeometryAdjust.inscribedScale と同じ式。傾けたときに余白が出ない最大の倍率。 */
export function inscribedScale(width: number, height: number, radians: number): number {
  const longer = Math.max(width / height, height / width);
  return 1 / (Math.cos(radians) + longer * Math.sin(radians));
}

/** 試作では、明るさ・色温度などは重ね塗りで近似する(値が動く手応えの確認用)。回転・反転・傾き・切り抜き・文字は本物の動き。 */
function overlays(p: Params) {
  const v = (id: string) => p.values[id] ?? 0;
  const brightness = v('brightness') + v('skinBrightness') * 0.5;
  const warmth = v('warmth');
  return [
    brightness > 0 && { color: '#fff', opacity: brightness * 0.35 },
    brightness < 0 && { color: '#000', opacity: -brightness * 0.35 },
    warmth > 0 && { color: '#ff9d3c', opacity: warmth * 0.25 },
    warmth < 0 && { color: '#3c8bff', opacity: -warmth * 0.25 },
  ].filter(Boolean) as { color: string; opacity: number }[];
}

/** 書体と太字の指定から、フォント名と太さを決める。太字の専用フォントが無ければ、通常のフォントに太字を指定する。 */
function fontFor(style: string, bold: boolean): { fontFamily?: string; fontWeight: '400' | '700' } {
  const entry = textStyles.find((t) => t.id === style);
  if (!entry?.regular) return { fontWeight: bold ? '700' : '400' };
  if (bold && entry.bold) return { fontFamily: entry.bold, fontWeight: '400' };
  return { fontFamily: entry.regular, fontWeight: bold ? '700' : '400' };
}

/** 文字は、完成した構図(外枠)の上に、相対位置と短辺に対する大きさで置く。 */
function TextLayer({ item, width, height }: { item: TextItem; width: number; height: number }) {
  const fontSize = item.size * Math.min(width, height);
  return (
    // 中心が (x, y) になるよう、外枠の2倍の大きさの箱の中央に置く。
    <View pointerEvents="none" style={{
      position: 'absolute', left: item.x * width - width, top: item.y * height - height,
      width: width * 2, height: height * 2, alignItems: 'center', justifyContent: 'center',
    }}>
      <Text style={{
        color: item.color, fontSize, ...fontFor(item.style, item.bold), textAlign: 'center',
        ...(item.shadow ? { textShadowColor: 'rgba(0,0,0,0.5)', textShadowRadius: fontSize * 0.12, textShadowOffset: { width: 0, height: fontSize * 0.05 } } : {}),
      }}>{item.text}</Text>
    </View>
  );
}

type Props = {
  uri: string; params: Params; isHealing: boolean; isEditingText: boolean; selectedTextId: string | null;
  isMovingCrop: boolean; showsHint: boolean; resetKey: number;
  onTapPhoto: () => void; onMoveCrop: (dx: number, dy: number) => void; onMoveCropEnd: () => void; onMoveText: (id: string, x: number, y: number) => void; onMoveTextEnd: () => void;
};

const MAX_SCALE = 6;

/** ピンチで拡大、ドラッグで移動、ダブルタップで元に戻る。長押しで元の写真に切り替わる(CanvasView.swift に対応)。 */
export function Canvas({ uri, params, isHealing, isEditingText, isMovingCrop, selectedTextId, showsHint, resetKey, onTapPhoto, onMoveCrop, onMoveCropEnd, onMoveText, onMoveTextEnd }: Props) {
  const [image, setImage] = useState<{ w: number; h: number } | null>(null);
  const [area, setArea] = useState({ w: 0, h: 0 });
  const [isComparing, setIsComparing] = useState(false);
  const [zoom, setZoom] = useState({ scale: 1, x: 0, y: 0 });
  const outerRef = useRef<View>(null);
  const outerOrigin = useRef({ x: 0, y: 0 });

  useEffect(() => { Image.getSize(uri, (w, h) => setImage({ w, h })); }, [uri]);
  useEffect(() => setZoom({ scale: 1, x: 0, y: 0 }), [resetKey]);

  // 外枠(最終的な構図)の大きさ: 縦横比を満たす最大の枠を、表示領域に収める。
  const turns = ((params.rotation % 4) + 4) % 4;
  const odd = turns % 2 === 1;
  const rotatedAspect = image ? (odd ? image.h / image.w : image.w / image.h) : 1;
  const cropRatio = cropOptions.find((c) => c.id === params.cropAspect)?.ratio;
  const frameAspect = cropRatio ?? rotatedAspect;
  const frame = useMemo(() => {
    if (area.w === 0 || area.h === 0) return { w: 0, h: 0 };
    return area.w / area.h > frameAspect ? { w: area.h * frameAspect, h: area.h } : { w: area.w, h: area.w / frameAspect };
  }, [area, frameAspect]);

  // 内側の写真: 外枠を覆う大きさ(回転後の向きで)。90° 単位の回転では、要素自体の幅と高さを入れ替える。
  const cover = rotatedAspect >= frameAspect ? { w: frame.h * rotatedAspect, h: frame.h } : { w: frame.w, h: frame.w / rotatedAspect };
  const element = odd ? { w: cover.h, h: cover.w } : cover;
  const straightenDeg = (params.values.straighten ?? 0) * 30;
  const inner = straightenDeg === 0 ? 1 : 1 / inscribedScale(cover.w, cover.h, Math.abs(straightenDeg) * Math.PI / 180);
  // ズーム(アップ): 枠の 1/zoom の範囲を切り出して枠いっぱいに拡大する。中心は範囲が枠の外に出ないよう内側へ寄せる。
  const cropZoom = params.values.cropZoom ?? 1;
  const halfWindow = 0.5 / cropZoom;
  const center = { x: Math.min(Math.max(params.cropCenter.x, halfWindow), 1 - halfWindow), y: Math.min(Math.max(params.cropCenter.y, halfWindow), 1 - halfWindow) };

  // ジェスチャー。PanResponder は一度だけ作るため、最新の値は ref 経由で読む。
  const latest = useRef({ params, isHealing, isEditingText, isMovingCrop, selectedTextId, area, zoom, onTapPhoto, onMoveCrop, onMoveCropEnd, onMoveText, onMoveTextEnd });
  latest.current = { params, isHealing, isEditingText, isMovingCrop, selectedTextId, area, zoom, onTapPhoto, onMoveCrop, onMoveCropEnd, onMoveText, onMoveTextEnd };
  const frameRef = useRef(frame);
  frameRef.current = frame;
  const gesture = useRef({ lastDx: 0, lastDy: 0, moved: false, timer: null as ReturnType<typeof setTimeout> | null, startDist: 0, startScale: 1, base: { x: 0, y: 0 }, lastTap: 0 });

  const responder = useMemo(() => {
    const cancelTimer = () => { if (gesture.current.timer) clearTimeout(gesture.current.timer); gesture.current.timer = null; };
    return PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponder: () => true,
      onPanResponderGrant: (e: GestureResponderEvent) => {
        const g = gesture.current;
        g.moved = false; g.lastDx = 0; g.lastDy = 0; g.startDist = 0; g.startScale = latest.current.zoom.scale;
        g.base = { x: latest.current.zoom.x, y: latest.current.zoom.y };
        cancelTimer();
        if (e.nativeEvent.touches.length === 1) g.timer = setTimeout(() => { if (!g.moved) setIsComparing(true); }, 300);
        outerRef.current?.measureInWindow((x, y) => { outerOrigin.current = { x, y }; });
      },
      onPanResponderMove: (e: GestureResponderEvent, s: PanResponderGestureState) => {
        const g = gesture.current, c = latest.current, touches = e.nativeEvent.touches;
        if (touches.length >= 2) {
          g.moved = true; cancelTimer();
          const dist = Math.hypot(touches[0].pageX - touches[1].pageX, touches[0].pageY - touches[1].pageY);
          if (g.startDist === 0) { g.startDist = dist; g.startScale = c.zoom.scale; return; }
          const scale = Math.min(Math.max(g.startScale * dist / g.startDist, 1), MAX_SCALE);
          setZoom((z) => ({ ...z, scale }));
          return;
        }
        if (Math.hypot(s.dx, s.dy) > 8) { g.moved = true; cancelTimer(); }
        if (c.isEditingText && c.selectedTextId) {
          // 文字の編集中は、ドラッグで文字を動かす(拡大は使わない)。
          const f = frameRef.current;
          if (f.w > 0) c.onMoveText(c.selectedTextId, (e.nativeEvent.pageX - outerOrigin.current.x) / f.w, (e.nativeEvent.pageY - outerOrigin.current.y) / f.h);
        } else if (c.isMovingCrop) {
          // ズームの範囲を動かす。指の移動量は、表示中の大きさに対する割合で渡す(1/ズームは受け取る側で掛ける)。
          const f = frameRef.current;
          if (f.w > 0) c.onMoveCrop((s.dx - g.lastDx) / f.w, (s.dy - g.lastDy) / f.h);
          g.lastDx = s.dx; g.lastDy = s.dy;
        } else if (c.zoom.scale > 1 && !c.isHealing) {
          const limitX = (c.zoom.scale - 1) * c.area.w / 2, limitY = (c.zoom.scale - 1) * c.area.h / 2;
          setZoom((z) => ({ ...z, x: Math.min(Math.max(g.base.x + s.dx, -limitX), limitX), y: Math.min(Math.max(g.base.y + s.dy, -limitY), limitY) }));
        }
      },
      onPanResponderRelease: () => {
        const g = gesture.current, c = latest.current;
        cancelTimer(); setIsComparing(false);
        if (c.isEditingText) c.onMoveTextEnd();
        if (c.isMovingCrop) c.onMoveCropEnd();
        if (!g.moved) {
          if (c.isHealing) c.onTapPhoto();
          else if (Date.now() - g.lastTap < 300) setZoom({ scale: 1, x: 0, y: 0 });
          g.lastTap = Date.now();
        }
        setZoom((z) => (z.scale <= 1 ? { scale: 1, x: 0, y: 0 } : z));
      },
      onPanResponderTerminate: () => { cancelTimer(); setIsComparing(false); },
    });
  }, []);

  return (
    <View style={styles.root} onLayout={(e) => setArea({ w: e.nativeEvent.layout.width, h: e.nativeEvent.layout.height })} {...responder.panHandlers}>
      <View style={{ width: frame.w, height: frame.h, transform: [{ translateX: zoom.x }, { translateY: zoom.y }, { scale: zoom.scale }] }}>
        {isComparing ? (
          // 比較中は、編集前の元の写真をそのまま見せる。
          <Image source={{ uri }} style={styles.compare} resizeMode="contain" />
        ) : (
          <View ref={outerRef} collapsable={false} style={[styles.frame, { width: frame.w, height: frame.h }]}>
            <View pointerEvents="none" style={{
              width: frame.w, height: frame.h,
              transform: [{ translateX: -(center.x - 0.5) * frame.w * cropZoom }, { translateY: -(center.y - 0.5) * frame.h * cropZoom }, { scale: cropZoom }],
            }}>
              <Image source={{ uri }} resizeMode="stretch" style={{
                width: element.w, height: element.h, position: 'absolute', left: (frame.w - element.w) / 2, top: (frame.h - element.h) / 2,
                transform: [{ rotate: `${turns * 90 + straightenDeg}deg` }, { scaleX: params.flip ? -1 : 1 }, { scale: inner }],
              }} />
            </View>
            {overlays(params).map((o, i) => (
              <View key={i} pointerEvents="none" style={[StyleSheet.absoluteFill, { backgroundColor: o.color, opacity: o.opacity }]} />
            ))}
            {params.texts.map((t) => <TextLayer key={t.id} item={t} width={frame.w} height={frame.h} />)}
          </View>
        )}
      </View>
      {(isComparing || showsHint) && (
        <View style={styles.caption} pointerEvents="none">
          <Text style={styles.captionText}>{isComparing ? '元の写真' : '長押しで元の写真を表示'}</Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, paddingHorizontal: 12, alignItems: 'center', justifyContent: 'center', overflow: 'hidden' },
  frame: { borderRadius: 12, overflow: 'hidden', backgroundColor: '#000' },
  compare: { width: '100%', height: '100%' },
  caption: { position: 'absolute', bottom: 8, alignSelf: 'center', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 16, backgroundColor: 'rgba(40,40,44,0.85)' },
  captionText: { color: theme.text, fontSize: 13, fontWeight: '500' },
});
