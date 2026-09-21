import { useMemo, useRef, useState } from 'react';
import { PanResponder, StyleSheet, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { theme } from '../theme';

const THUMB = 28;
const TRACK = 4;
/** ゼロに吸い付く範囲(全体幅に対する割合)。TrackSlider.swift と同じ値。 */
const SNAP = 0.03;

type Props = { value: number; min: number; max: number; onChange: (v: number) => void; onEnd: () => void };

/** 中央がゼロの範囲では中央から値の方向へ色が伸び、ゼロ付近で吸着して触感を返す。 */
export function TrackSlider({ value, min, max, onChange, onEnd }: Props) {
  const [width, setWidth] = useState(0);
  const travel = Math.max(width - THUMB, 1);
  const span = max - min;
  const bidirectional = min < 0 && max > 0;

  // PanResponder は一度だけ作るため、最新の値は ref 経由で読む。
  const latest = useRef({ travel, min, span, bidirectional, onChange, onEnd });
  latest.current = { travel, min, span, bidirectional, onChange, onEnd };
  const wasZero = useRef(value === 0);

  const responder = useMemo(() => {
    const update = (x: number) => {
      const c = latest.current;
      const ratio = Math.min(Math.max((x - THUMB / 2) / c.travel, 0), 1);
      let next = c.min + ratio * c.span;
      if (c.bidirectional && Math.abs(next) < c.span * SNAP) next = 0;
      if (next === 0 && !wasZero.current) Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      wasZero.current = next === 0;
      c.onChange(next);
    };
    return PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponder: () => true,
      onPanResponderGrant: (e) => update(e.nativeEvent.locationX),
      onPanResponderMove: (e) => update(e.nativeEvent.locationX),
      onPanResponderRelease: () => latest.current.onEnd(),
      onPanResponderTerminate: () => latest.current.onEnd(),
    });
  }, []);

  const position = ((value - min) / span) * travel;
  const origin = bidirectional ? ((0 - min) / span) * travel : 0;

  return (
    <View style={styles.root} onLayout={(e) => setWidth(e.nativeEvent.layout.width)} {...responder.panHandlers}>
      {/* 子要素が触れを受けると locationX がずれるため、すべて触れを通す。 */}
      <View style={[styles.track, { left: THUMB / 2, right: THUMB / 2 }]} pointerEvents="none" />
      <LinearGradient
        colors={theme.gradient}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 0 }}
        pointerEvents="none"
        style={[styles.fill, { left: THUMB / 2 + Math.min(position, origin), width: Math.abs(position - origin) }]}
      />
      {bidirectional && <View pointerEvents="none" style={[styles.tick, { left: THUMB / 2 + origin - 1 }]} />}
      <View pointerEvents="none" style={[styles.thumb, { left: position }]} />
    </View>
  );
}

const styles = StyleSheet.create({
  root: { height: 36, justifyContent: 'center' },
  track: { position: 'absolute', height: TRACK, borderRadius: TRACK / 2, backgroundColor: 'rgba(255,255,255,0.18)' },
  fill: { position: 'absolute', height: TRACK, borderRadius: TRACK / 2 },
  tick: { position: 'absolute', width: 2, height: 12, borderRadius: 1, backgroundColor: 'rgba(255,255,255,0.6)' },
  thumb: {
    position: 'absolute', width: THUMB, height: THUMB, borderRadius: THUMB / 2, backgroundColor: '#fff',
    shadowColor: '#000', shadowOpacity: 0.35, shadowRadius: 4, shadowOffset: { width: 0, height: 2 },
  },
});
