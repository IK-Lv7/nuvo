import { Ionicons } from '@expo/vector-icons';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { theme } from '../theme';

/** 起動直後の画面。何ができるアプリかと、Nuvo の立場(無料・透かしなし・オフライン)を最初に伝える。 */
export function EmptyState({ onPick }: { onPick: () => void }) {
  return (
    <View style={styles.empty}>
      <LinearGradient colors={theme.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.logo}>
        <Text style={styles.logoText}>N</Text>
      </LinearGradient>
      <Text style={styles.title}>Nuvo</Text>
      <Text style={styles.tagline}>{'全機能無料。透かしなし。\n通信も不要です。'}</Text>
      <Pressable onPress={onPick} style={({ pressed }) => ({ opacity: pressed ? 0.8 : 1 })}>
        <LinearGradient colors={theme.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.cta}>
          <Ionicons name="images-outline" size={20} color="#fff" />
          <Text style={styles.ctaText}>写真を選ぶ</Text>
        </LinearGradient>
      </Pressable>
      <View style={styles.badges}>
        {[['gift-outline', '無料'], ['ribbon-outline', '透かしなし'], ['cloud-offline-outline', 'オフライン']].map(([icon, label]) => (
          <View key={label} style={styles.badge}>
            <Ionicons name={icon as 'gift-outline'} size={13} color={theme.text} />
            <Text style={styles.badgeText}>{label}</Text>
          </View>
        ))}
      </View>
    </View>
  );
}

type BarProps = {
  onPick: () => void; onUndo: () => void; onRedo: () => void; canUndo: boolean; canRedo: boolean; onSave: () => void; onSettings: () => void; onShare: () => void;
};

/** 写真の差し替え、Undo/Redo、保存(EditorTopBar.swift に対応)。 */
export function TopBar({ onPick, onUndo, onRedo, canUndo, canRedo, onSave, onSettings, onShare }: BarProps) {
  const icon = (name: 'images-outline' | 'arrow-undo-outline' | 'arrow-redo-outline', onPress: () => void, enabled = true) => (
    <Pressable onPress={onPress} disabled={!enabled} style={[styles.iconButton, { opacity: enabled ? 1 : 0.4 }]}>
      <Ionicons name={name} size={19} color="#fff" />
    </Pressable>
  );
  return (
    <View style={styles.bar}>
      {icon('images-outline', onPick)}
      {icon('arrow-undo-outline', onUndo, canUndo)}
      {icon('arrow-redo-outline', onRedo, canRedo)}
      <View style={styles.proto}><Text style={styles.protoText}>PROTOTYPE</Text></View>
      <Pressable onPress={onSettings} style={styles.iconButton}><Ionicons name="settings-outline" size={19} color="#fff" /></Pressable>
      <Pressable onPress={onShare} style={styles.iconButton}><Ionicons name="share-outline" size={19} color="#fff" /></Pressable>
      <Pressable onPress={onSave}>
        <LinearGradient colors={theme.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.save}>
          <Text style={styles.saveText}>保存</Text>
        </LinearGradient>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  empty: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 22, padding: theme.spacing.l },
  logo: { width: 104, height: 104, borderRadius: 26, alignItems: 'center', justifyContent: 'center', shadowColor: theme.accent, shadowOpacity: 0.35, shadowRadius: 24, shadowOffset: { width: 0, height: 10 } },
  logoText: { color: '#fff', fontSize: 56, fontWeight: '800' },
  title: { color: theme.text, fontSize: 42, fontWeight: '700' },
  tagline: { color: theme.textSecondary, fontSize: 15, textAlign: 'center', lineHeight: 22 },
  cta: { flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: 28, paddingVertical: 14, borderRadius: 28 },
  ctaText: { color: '#fff', fontSize: 17, fontWeight: '600' },
  badges: { flexDirection: 'row', gap: 8 },
  badge: { flexDirection: 'row', alignItems: 'center', gap: 5, paddingHorizontal: 10, paddingVertical: 6, borderRadius: 16, backgroundColor: 'rgba(255,255,255,0.08)' },
  badgeText: { color: theme.text, fontSize: 12, fontWeight: '500' },
  bar: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: theme.spacing.m, paddingVertical: 8 },
  iconButton: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surfaceStrong },
  proto: { flex: 1, alignItems: 'center' },
  protoText: { color: theme.textSecondary, fontSize: 10, letterSpacing: 2, fontWeight: '600' },
  save: { paddingHorizontal: 20, paddingVertical: 10, borderRadius: 20 },
  saveText: { color: '#fff', fontSize: 16, fontWeight: '600' },
});
