/** Sources/App/Theme.swift と同じ値。試作で決めた値は SwiftUI 側へそのまま写す。 */
export const theme = {
  accent: '#FF8A9E',
  accentSoft: '#FFC494',
  canvas: '#121214',
  surface: 'rgba(255,255,255,0.09)',
  surfaceStrong: 'rgba(255,255,255,0.14)',
  text: '#FFFFFF',
  textSecondary: 'rgba(255,255,255,0.55)',
  gradient: ['#FF8A9E', '#FFC494'] as const,
  spacing: { s: 8, m: 16, l: 24 },
};
