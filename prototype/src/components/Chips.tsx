import { Pressable, ScrollView, StyleSheet, Text } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { theme } from '../theme';

type Option = { id: string; title: string; regular?: string };
type Props = { options: Option[]; selected: string | null; noneTitle: string; showsNone?: boolean; onSelect: (id: string | null) => void };

/** 横に並べた選択肢。先頭の「なし」で解除する(ChipStrip.swift に対応)。 */
export function Chips({ options, selected, noneTitle, showsNone = true, onSelect }: Props) {
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.row}>
      {showsNone && <Chip title={noneTitle} isOn={selected === null} onPress={() => onSelect(null)} />}
      {options.map((o) => (
        <Chip key={o.id} title={o.title} fontFamily={o.regular} isOn={selected === o.id} onPress={() => onSelect(o.id)} />
      ))}
    </ScrollView>
  );
}

export function Chip({ title, isOn, onPress, fontFamily }: { title: string; isOn: boolean; onPress: () => void; fontFamily?: string }) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => ({ opacity: pressed ? 0.7 : 1 })}>
      {isOn ? (
        <LinearGradient colors={theme.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.chip}>
          <Text style={[styles.text, { fontFamily }]}>{title}</Text>
        </LinearGradient>
      ) : (
        <Text style={[styles.chip, styles.off, styles.text, { fontFamily }]}>{title}</Text>
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: { gap: 8, paddingRight: 8 },
  chip: { paddingHorizontal: 14, paddingVertical: 9, borderRadius: 20, overflow: 'hidden' },
  off: { backgroundColor: theme.surfaceStrong },
  text: { color: theme.text, fontSize: 14, fontWeight: '600' },
});
