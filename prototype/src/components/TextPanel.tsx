import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { textColors, textStyles } from '../catalog';
import type { TextItem } from '../state';
import { theme } from '../theme';
import { Chip, Chips } from './Chips';
import { TrackSlider } from './TrackSlider';

type Props = {
  texts: TextItem[];
  selected: TextItem | null;
  onAdd: () => void;
  onSelect: (id: string) => void;
  onRemove: () => void;
  /** commit=false は入力中・ドラッグ中(履歴に積まない)。 */
  onChange: (change: Partial<TextItem>, commit: boolean) => void;
  onCommit: () => void;
};

/** 文字の追加・編集。位置は、写真の上をドラッグして動かす(TextToolPanel.swift に対応)。 */
export function TextPanel({ texts, selected, onAdd, onSelect, onRemove, onChange, onCommit }: Props) {
  return (
    <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.box}>
      <View style={styles.row}>
        <Chip title="＋ 追加" isOn={false} onPress={onAdd} />
        {texts.map((t, i) => <Chip key={t.id} title={`${i + 1}`} isOn={t.id === selected?.id} onPress={() => onSelect(t.id)} />)}
        <View style={{ flex: 1 }} />
        {selected && (
          <Pressable onPress={onRemove} style={styles.trash}><Ionicons name="trash-outline" size={18} color="#fff" /></Pressable>
        )}
      </View>
      {selected && (
        <>
          <TextInput
            value={selected.text} multiline placeholder="文字を入力" placeholderTextColor={theme.textSecondary}
            onChangeText={(text) => onChange({ text }, false)} onBlur={onCommit} style={styles.input}
          />
          <Chips options={textColors} selected={selected.color} noneTitle="" showsNone={false}
            onSelect={(id) => id && onChange({ color: id }, true)} />
          <Chips options={textStyles} selected={selected.style} noneTitle="" showsNone={false}
            onSelect={(id) => id && onChange({ style: id }, true)} />
          <View style={styles.row}>
            <Chip title="太字" isOn={selected.bold} onPress={() => onChange({ bold: !selected.bold }, true)} />
            <Chip title="影" isOn={selected.shadow} onPress={() => onChange({ shadow: !selected.shadow }, true)} />
          </View>
          <TrackSlider value={selected.size} min={0.03} max={0.3} onChange={(size) => onChange({ size }, false)} onEnd={onCommit} />
          <Text style={styles.hint}>写真の上をドラッグして文字を動かせます</Text>
        </>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  box: { gap: 10 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  trash: { width: 36, height: 36, borderRadius: 18, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surfaceStrong },
  input: { color: theme.text, fontSize: 16, padding: 10, borderRadius: 10, backgroundColor: 'rgba(255,255,255,0.1)', maxHeight: 80 },
  hint: { color: theme.textSecondary, fontSize: 13 },
});
