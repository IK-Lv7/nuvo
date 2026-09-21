import { StyleSheet, Text, View } from 'react-native';
import * as Haptics from 'expo-haptics';
import { Alert, Pressable } from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { useState } from 'react';
import { backgroundColors, cropOptions, filterOptions, idPhotoOptions, sliderDefault, type Tool } from '../catalog';
import { hasComposition, type Params, type TextItem } from '../state';
import { mockFaces, selectedFaces } from '../people';
import { TextPanel } from './TextPanel';
import { theme } from '../theme';
import { Chip, Chips } from './Chips';
import { TrackSlider } from './TrackSlider';

type Props = {
  tool: Tool;
  params: Params;
  isHealing: boolean;
  onToggleHealing: () => void;
  onChange: (next: (p: Params) => Params) => void;
  onCommit: (next?: (p: Params) => Params) => void;
  selectedText: TextItem | null;
  onAddText: () => void;
  onSelectText: (id: string) => void;
  onRemoveText: () => void;
  onChangeText: (change: Partial<TextItem>, commit: boolean) => void;
  looks: { id: string; name: string; params: Params }[];
  onSaveLook: (name: string) => void;
  onApplyLook: (id: string) => void;
  onDeleteLook: (id: string) => void;
};

/** 選択中のツールの操作部。スライダー1本で済むツールは値を大きく見せる(ToolPanel.swift に対応)。 */
export function ToolPanel(props: Props) {
  const { tool, params, isHealing, onToggleHealing, onChange, onCommit } = props;
  const [selectedLookId, setSelectedLookId] = useState<string | null>(null);
  const [batchMessage, setBatchMessage] = useState('');
  const kind = tool.kind;
  switch (kind.type) {
    case 'slider': {
      const fallback = sliderDefault(kind);
      const value = params.values[tool.id] ?? fallback;
      const percent = Math.round(value * 100);
      const setValue = (v: number) => (p: Params): Params => ({ ...p, values: { ...p.values, [tool.id]: v } });
      return (
        <View style={styles.box}>
          {/* 値をダブルタップでゼロに戻せる代わりに、試作ではタップで戻す。 */}
          <Text style={styles.value} onPress={() => onCommit(setValue(fallback))}>
            {kind.min < 0 && percent > 0 ? `+${percent}` : `${percent}`}
          </Text>
          <TrackSlider value={value} min={kind.min} max={kind.max}
            onChange={(v) => onChange(setValue(v))} onEnd={() => onCommit()} />
          {tool.id === 'cropZoom' && value > 1 && <Text style={styles.hint}>写真の上をドラッグして、拡大する範囲を動かせます</Text>}
        </View>
      );
    }
    case 'filters':
      return (
        <View style={styles.box}>
          <Chips options={filterOptions} selected={params.filter} noneTitle="なし"
            onSelect={(id) => onCommit((p) => ({ ...p, filter: id }))} />
          {params.filter !== null && (
            <TrackSlider value={params.filterIntensity} min={0} max={1}
              onChange={(v) => onChange((p) => ({ ...p, filterIntensity: v }))} onEnd={() => onCommit()} />
          )}
        </View>
      );
    case 'backgroundColor':
      return (
        <View style={styles.box}>
          <Chips options={backgroundColors} selected={params.bgColor} noneTitle="そのまま"
            onSelect={(id) => onCommit((p) => ({ ...p, bgColor: id }))} />
        </View>
      );
    case 'idPhoto':
      return (
        <View style={styles.box}>
          <Chips options={idPhotoOptions} selected={params.idPhoto} noneTitle="なし"
            onSelect={(id) => onCommit((p) => ({ ...p, idPhoto: id, bgColor: id && !p.bgColor ? 'white' : p.bgColor }))} />
        </View>
      );
    case 'blemish':
      return (
        <View style={styles.box}>
          <View style={styles.row}>
            <Chip title="タップで修復" isOn={isHealing} onPress={() => { if (!hasComposition(params)) onToggleHealing(); }} />
            <Chip title="自動で検出" isOn={false} onPress={() => {
              Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
              onCommit((p) => ({ ...p, spots: p.spots + 3 }));
            }} />
          </View>
          <Text style={hasComposition(params) ? styles.warn : styles.hint}>
            {hasComposition(params) ? '構図を変えている間は、タップでの修復は使えません。先に修復してください。' : isHealing ? '写真のニキビやシミをタップしてください' : ''}
          </Text>
        </View>
      );
    case 'orientation':
      return (
        <View style={styles.row}>
          <Chip title="左に回転" isOn={false} onPress={() => onCommit((p) => ({ ...p, rotation: (p.rotation + 3) % 4 }))} />
          <Chip title="右に回転" isOn={false} onPress={() => onCommit((p) => ({ ...p, rotation: (p.rotation + 1) % 4 }))} />
          <Chip title="反転" isOn={params.flip} onPress={() => onCommit((p) => ({ ...p, flip: !p.flip }))} />
        </View>
      );
    case 'aspect':
      return (
        <View style={styles.box}>
          <Chips options={cropOptions} selected={params.cropAspect} noneTitle="そのまま"
            onSelect={(id) => onCommit((p) => ({ ...p, cropAspect: id }))} />
        </View>
      );
    case 'text':
      return (
        <TextPanel texts={params.texts} selected={props.selectedText} onAdd={props.onAddText} onSelect={props.onSelectText}
          onRemove={props.onRemoveText} onChange={props.onChangeText} onCommit={() => onCommit()} />
      );
    case 'looks': {
      const pickPhotos = async () => {
        const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], allowsMultipleSelection: true, selectionLimit: 20 });
        if (!result.canceled) setBatchMessage(`${result.assets.length} 枚を選びました(試作では保存しません)`);
      };
      const look = props.looks.find((l) => l.id === selectedLookId);
      return (
        <View style={styles.box}>
          <View style={styles.row}>
            <Chip title="＋ 現在の設定を保存" isOn={false} onPress={() =>
              Alert.prompt('ルックの名前', undefined, (name) => { if (name?.trim()) props.onSaveLook(name.trim()); }, 'plain-text', '', 'default')} />
            <Chip title="複数の写真に適用" isOn={false} onPress={() => { if (look) pickPhotos(); }} />
          </View>
          {props.looks.length === 0 ? (
            <Text style={styles.hint}>保存したルックはまだありません</Text>
          ) : (
            <Chips options={props.looks.map((l) => ({ id: l.id, title: l.name }))} selected={selectedLookId} noneTitle="" showsNone={false}
              onSelect={(id) => { if (id) { setSelectedLookId(id); props.onApplyLook(id); } }} />
          )}
          {batchMessage !== '' && <Text style={styles.hint}>{batchMessage}</Text>}
        </View>
      );
    }
    case 'people': {
      const blocked = hasComposition(params);
      return (
        <View style={styles.box}>
          <View style={styles.row}>
            <Text style={styles.summary}>{`${selectedFaces(params.unselected).length} 人を加工(全 ${mockFaces.length} 人)`}</Text>
            <Chip title="全員" isOn={false} onPress={() => { if (params.unselected.length > 0) onCommit((p) => ({ ...p, unselected: [] })); }} />
          </View>
          <Text style={blocked ? styles.warn : styles.hint}>
            {blocked ? '切り抜きや回転を変えている間は、加工する人を選べません。先に選んでください。'
              : '顔をタップして入り切り。または、加工したい人を指で囲んでください。'}
          </Text>
        </View>
      );
    }
    case 'autoEnhance':
      return (
        <View style={styles.box}>
          <View style={styles.row}>
            <Chip title={params.autoEnhance ? 'オン' : 'オフ'} isOn={params.autoEnhance}
              onPress={() => onCommit((p) => ({ ...p, autoEnhance: !p.autoEnhance }))} />
          </View>
        </View>
      );
  }
}

const styles = StyleSheet.create({
  box: { gap: 8 },
  row: { flexDirection: 'row', gap: 10 },
  value: { color: theme.text, fontSize: 20, fontWeight: '600', textAlign: 'center', fontVariant: ['tabular-nums'] },
  summary: { color: theme.text, fontSize: 15, fontWeight: '600', alignSelf: 'center', fontVariant: ['tabular-nums'] },
  hint: { color: theme.textSecondary, fontSize: 13 },
  warn: { color: '#ff9f0a', fontSize: 13 },
});
