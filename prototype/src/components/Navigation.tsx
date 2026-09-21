import { Ionicons } from '@expo/vector-icons';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import type { Category, Tool } from '../catalog';
import { theme } from '../theme';

/** 選択中のカテゴリに属するツール。変更済みのツールには印を付ける(ToolNavigation.swift に対応)。 */
export function ToolStrip({ tools, selectedId, isModified, onSelect }: {
  tools: Tool[]; selectedId: string; isModified: (t: Tool) => boolean; onSelect: (id: string) => void;
}) {
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.tools}>
      {tools.map((tool) => {
        const isSelected = tool.id === selectedId;
        return (
          <Pressable key={tool.id} style={styles.tool} onPress={() => { Haptics.selectionAsync(); onSelect(tool.id); }}>
            <View>
              {isSelected ? (
                <LinearGradient colors={theme.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.circle}>
                  <Ionicons name={tool.icon} size={22} color="#fff" />
                </LinearGradient>
              ) : (
                <View style={[styles.circle, { backgroundColor: theme.surface }]}>
                  <Ionicons name={tool.icon} size={22} color="#fff" />
                </View>
              )}
              {isModified(tool) && <View style={styles.dot} />}
            </View>
            <Text style={[styles.caption, { color: isSelected ? theme.text : theme.textSecondary }]}>{tool.title}</Text>
          </Pressable>
        );
      })}
    </ScrollView>
  );
}

export function CategoryBar({ categories, selectedId, onSelect }: {
  categories: Category[]; selectedId: string; onSelect: (id: string) => void;
}) {
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.categories}>
      {categories.map((c) => {
        const color = c.id === selectedId ? theme.accent : theme.textSecondary;
        return (
          <Pressable key={c.id} style={styles.category} onPress={() => onSelect(c.id)}>
            <Ionicons name={c.icon} size={21} color={color} />
            <Text style={[styles.categoryText, { color }]}>{c.title}</Text>
          </Pressable>
        );
      })}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  tools: { gap: 18, paddingHorizontal: theme.spacing.l },
  tool: { alignItems: 'center', gap: 6 },
  circle: { width: 52, height: 52, borderRadius: 26, alignItems: 'center', justifyContent: 'center' },
  dot: {
    position: 'absolute', top: 0, right: 0, width: 10, height: 10, borderRadius: 5,
    backgroundColor: theme.accent, borderWidth: 2, borderColor: theme.canvas,
  },
  caption: { fontSize: 11 },
  categories: { paddingHorizontal: theme.spacing.m, gap: 6 },
  category: { width: 64, height: 48, alignItems: 'center', justifyContent: 'center', gap: 3 },
  categoryText: { fontSize: 11 },
});
