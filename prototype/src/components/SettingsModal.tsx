import { Modal, Pressable, StyleSheet, Switch, Text, View } from 'react-native';
import { exportFormats } from '../catalog';
import { theme } from '../theme';
import { Chips } from './Chips';
import { TrackSlider } from './TrackSlider';

type Props = {
  visible: boolean; onClose: () => void; stripLocation: boolean; onChangeStripLocation: (v: boolean) => void;
  format: string; onChangeFormat: (v: string) => void; quality: number; onChangeQuality: (v: number) => void;
};

/** 設定。書き出しの扱いと、プライバシーの説明(SettingsView.swift に対応。試作では保存しない)。 */
export function SettingsModal({ visible, onClose, stripLocation, onChangeStripLocation, format, onChangeFormat, quality, onChangeQuality }: Props) {
  return (
    <Modal visible={visible} animationType="slide" presentationStyle="pageSheet" onRequestClose={onClose}>
      <View style={styles.root}>
        <View style={styles.header}>
          <Text style={styles.title}>設定</Text>
          <Pressable onPress={onClose}><Text style={styles.done}>完了</Text></Pressable>
        </View>
        <Text style={styles.section}>書き出し</Text>
        <View style={[styles.card, { gap: 14 }]}>
          <Chips options={exportFormats} selected={format} noneTitle="" showsNone={false} onSelect={(id) => id && onChangeFormat(id)} />
          {format !== 'png' && (
            <View>
              <View style={styles.row}><Text style={styles.label}>画質</Text><Text style={styles.value}>{Math.round(quality * 100)}</Text></View>
              <TrackSlider value={quality} min={0.5} max={1} onChange={onChangeQuality} onEnd={() => undefined} />
            </View>
          )}
          <View style={styles.row}>
            <Text style={styles.label}>位置情報を削除</Text>
            <Switch value={stripLocation} onValueChange={onChangeStripLocation} trackColor={{ true: theme.accent }} />
          </View>
        </View>
        <Text style={styles.footer}>JPEG は最も互換性が高く、HEIC は同じ画質でファイルが小さくなります。PNG は劣化がありませんが、ファイルが大きくなります。「位置情報を削除」がオンのときは、撮影場所の情報を取り除きます。</Text>
        <Text style={styles.section}>プライバシー</Text>
        <View style={styles.card}>
          <Text style={styles.body}>写真の加工はすべて端末の中で行います。Nuvo は通信を行わず、写真も個人情報も、開発者を含む誰にも送られません。</Text>
        </View>
        <Text style={styles.section}>このアプリについて</Text>
        <View style={styles.card}>
          <View style={styles.row}><Text style={styles.label}>バージョン</Text><Text style={styles.value}>1.0.0 (試作)</Text></View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#1c1c1e', padding: theme.spacing.m },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 },
  title: { color: theme.text, fontSize: 17, fontWeight: '600' },
  done: { color: theme.accent, fontSize: 17, fontWeight: '600' },
  section: { color: theme.textSecondary, fontSize: 13, marginTop: 20, marginBottom: 6, marginLeft: 4 },
  card: { backgroundColor: '#2c2c2e', borderRadius: 12, padding: 14 },
  row: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  label: { color: theme.text, fontSize: 16 },
  value: { color: theme.textSecondary, fontSize: 16 },
  body: { color: theme.text, fontSize: 15, lineHeight: 22 },
  footer: { color: theme.textSecondary, fontSize: 12, marginTop: 6, marginLeft: 4 },
});
