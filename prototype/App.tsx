import { useEffect, useState } from 'react';
import { Pressable, Share, StyleSheet, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { StatusBar } from 'expo-status-bar';
import * as ImagePicker from 'expo-image-picker';
import { SafeAreaProvider, useSafeAreaInsets } from 'react-native-safe-area-context';
import { categories, panelHeight } from './src/catalog';
import { Canvas } from './src/components/Canvas';
import { CategoryBar, ToolStrip } from './src/components/Navigation';
import { SettingsModal } from './src/components/SettingsModal';
import { EmptyState, TopBar } from './src/components/Screens';
import { ToolPanel } from './src/components/ToolPanel';
import { applyingLook, hasComposition, isModified, lookOf, useEditorState, type Params, type TextItem } from './src/state';
import { theme } from './src/theme';

/**
 * Nuvo の UI 試作。見た目・配置・操作感を Fast Refresh で素早く詰めるためのもので、製品ではない。
 * 決まった内容は Sources/ (SwiftUI) に写す。肌補正・顔の変形・メイクなどの画像処理は行わない。
 * 回転・反転・傾き・切り抜き・文字・ピンチ拡大は、本物の動きで確認できる。
 */
function Editor() {
  const insets = useSafeAreaInsets();
  const editor = useEditorState();
  const [uri, setUri] = useState<string | null>(null);
  const [imageRevision, setImageRevision] = useState(0);
  const [categoryId, setCategoryId] = useState(categories[0].id);
  const [toolId, setToolId] = useState(categories[0].tools[0].id);
  const [isHealing, setIsHealing] = useState(false);
  const [showsHint, setShowsHint] = useState(false);
  const [showsSettings, setShowsSettings] = useState(false);
  const [stripLocation, setStripLocation] = useState(true);
  const [format, setFormat] = useState('jpeg');
  const [quality, setQuality] = useState(0.95);
  const [selectedTextId, setSelectedTextId] = useState<string | null>(null);
  const [looks, setLooks] = useState<{ id: string; name: string; params: Params }[]>([]);

  const category = categories.find((c) => c.id === categoryId) ?? categories[0];
  const tool = category.tools.find((t) => t.id === toolId) ?? category.tools[0];
  const selectedText: TextItem | null = editor.params.texts.find((t) => t.id === selectedTextId) ?? editor.params.texts[0] ?? null;
  const isEditingText = tool.kind.type === 'text' && selectedText !== null;
  /** ズームを選んでいて 1 倍より大きいとき、写真の上のドラッグで切り出す範囲を動かす。 */
  const isMovingCrop = tool.id === 'cropZoom' && (editor.params.values.cropZoom ?? 1) > 1;

  useEffect(() => {
    if (!uri) return;
    setShowsHint(true);
    const timer = setTimeout(() => setShowsHint(false), 3000);
    return () => clearTimeout(timer);
  }, [uri]);

  const pick = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], quality: 1 });
    if (!result.canceled) {
      setUri(result.assets[0].uri);
      setImageRevision((r) => r + 1);
      setSelectedTextId(null);
      editor.reset();
    }
  };

  const selectCategory = (id: string) => {
    setCategoryId(id);
    setToolId((categories.find((c) => c.id === id) ?? categories[0]).tools[0].id);
    setIsHealing(false);
  };

  const addText = () => {
    const item: TextItem = { id: `${Date.now()}`, text: 'Nuvo', x: 0.5, y: 0.5, size: 0.08, color: '#FFFFFF', style: 'standard', bold: true, shadow: true };
    setSelectedTextId(item.id);
    editor.commit((p) => ({ ...p, texts: [...p.texts, item] }));
  };

  const changeText = (change: Partial<TextItem>, commit: boolean) => {
    if (!selectedText) return;
    const apply = (p: Params): Params => ({ ...p, texts: p.texts.map((t) => (t.id === selectedText.id ? { ...t, ...change } : t)) });
    if (commit) editor.commit(apply); else editor.change(apply);
  };

  const removeText = () => {
    if (!selectedText) return;
    const id = selectedText.id;
    setSelectedTextId(null);
    editor.commit((p) => ({ ...p, texts: p.texts.filter((t) => t.id !== id) }));
  };

  return (
    <View style={[styles.root, { paddingTop: insets.top }]}>
      <StatusBar style="light" />
      {uri === null ? (
        <>
          <EmptyState onPick={pick} />
          <Pressable onPress={() => setShowsSettings(true)} style={[styles.gear, { top: insets.top + 8 }]}>
            <Ionicons name="settings-outline" size={19} color="#fff" />
          </Pressable>
        </>
      ) : (
        <>
          <TopBar onPick={pick} onUndo={editor.undo} onRedo={editor.redo} canUndo={editor.canUndo}
            canRedo={editor.canRedo} onSave={() => undefined} onSettings={() => setShowsSettings(true)}
            onShare={() => { if (uri) Share.share({ url: uri }); }} />
          <Canvas uri={uri} params={editor.params} isHealing={isHealing && !hasComposition(editor.params)} isEditingText={isEditingText} isMovingCrop={isMovingCrop}
            selectedTextId={selectedText?.id ?? null} showsHint={showsHint} resetKey={imageRevision}
            onTapPhoto={() => editor.commit((p) => ({ ...p, spots: p.spots + 1 }))}
            onMoveCrop={(dx, dy) => editor.change((p) => {
              // 指を右へ動かすと写真が右へ動いて見えるので、範囲の中心は左へ動く。動く量は 1/ズーム(EditorViewModel.moveCrop と同じ)。
              const zoom = Math.max(p.values.cropZoom ?? 1, 1);
              const half = 0.5 / zoom;
              return { ...p, cropCenter: {
                x: Math.min(Math.max(p.cropCenter.x - dx / zoom, half), 1 - half),
                y: Math.min(Math.max(p.cropCenter.y - dy / zoom, half), 1 - half),
              } };
            })}
            onMoveCropEnd={() => editor.commit()}
            onMoveText={(id, x, y) => editor.change((p) => ({ ...p, texts: p.texts.map((t) => (t.id === id ? { ...t, x: Math.min(Math.max(x, 0), 1), y: Math.min(Math.max(y, 0), 1) } : t)) }))}
            onMoveTextEnd={() => editor.commit()} />
          <View style={[styles.controls, { paddingBottom: insets.bottom + 4 }]}>
            {/* 操作部の高さはツールごとに固定し、ツールを切り替えても写真が上下に動かないようにする。 */}
            <View style={[styles.panel, { height: panelHeight(tool) }]}>
              <ToolPanel tool={tool} params={editor.params} isHealing={isHealing}
                onToggleHealing={() => setIsHealing((v) => !v)} onChange={editor.change} onCommit={editor.commit}
                selectedText={selectedText} onAddText={addText} onSelectText={setSelectedTextId}
                onRemoveText={removeText} onChangeText={changeText}
                looks={looks}
                onSaveLook={(name) => setLooks((l) => [...l, { id: `${Date.now()}`, name, params: lookOf(editor.params) }])}
                onApplyLook={(id) => { const look = looks.find((l) => l.id === id); if (look) editor.commit((p) => applyingLook(p, look.params)); }}
                onDeleteLook={(id) => setLooks((l) => l.filter((x) => x.id !== id))} />
            </View>
            <ToolStrip tools={category.tools} selectedId={tool.id} isModified={(t) => isModified(t, editor.params)}
              onSelect={(id) => { setToolId(id); setIsHealing(false); }} />
            <CategoryBar categories={categories} selectedId={category.id} onSelect={selectCategory} />
          </View>
        </>
      )}
      <SettingsModal visible={showsSettings} onClose={() => setShowsSettings(false)}
        stripLocation={stripLocation} onChangeStripLocation={setStripLocation}
        format={format} onChangeFormat={setFormat} quality={quality} onChangeQuality={setQuality} />
    </View>
  );
}

export default function App() {
  return (
    <SafeAreaProvider>
      <Editor />
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.canvas },
  controls: { paddingTop: 14, gap: 14, backgroundColor: 'rgba(30,30,34,0.92)' },
  panel: { paddingHorizontal: theme.spacing.l },
  gear: { position: 'absolute', right: theme.spacing.m, width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surfaceStrong },
});
