import { Platform } from 'react-native';

// Prelude Typography System
// Three typefaces only. Each has a specific role.

// 1. New York (serif) — emotionally significant content
//    Brief cards, insight content, agent's spoken words
// 2. SF Pro / system sans — UI and informational content
//    Navigation, settings, timestamps, metadata
// 3. SF Mono — live transcript only (0.7 opacity)

export const Fonts = {
  // New York serif — only available on iOS
  newYorkSerif: Platform.OS === 'ios' ? 'NewYork' : 'Georgia',
  
  // SF system font (automatically uses correct weight on iOS)
  system: Platform.select({ ios: 'System', default: 'sans-serif' }),
  
  // Monospace
  mono: Platform.select({ ios: 'Menlo-Regular', android: 'monospace', default: 'monospace' }),
};

// Type scale — all values in sp for Dynamic Type compatibility
export const TypeScale = {
  hero: { fontSize: 34, lineHeight: 42 },
  title: { fontSize: 24, lineHeight: 32 },
  cardTitle: { fontSize: 19, lineHeight: 26 },
  cardBody: { fontSize: 16, lineHeight: 26 }, // 1.625 line height
  label: { fontSize: 13, lineHeight: 18 },
  caption: { fontSize: 11, lineHeight: 15 },
  transcript: { fontSize: 14, lineHeight: 21 },
};
