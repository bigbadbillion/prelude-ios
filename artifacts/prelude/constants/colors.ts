// Prelude Design System — Warm Instrument Color Palette
// Built on warm earth tones with a single cool accent.
// The colors of parchment, aged wood, amber light, and deep forest shadow.

export const PreludeColors = {
  // Backgrounds
  depth: {
    dark: '#0F0D0A',
    light: '#FAF7F2',
  },
  surface: {
    dark: '#1C1813',
    light: '#F0EBE3',
  },
  raised: {
    dark: '#252018',
    light: '#E8E1D6',
  },

  // Text
  primary: {
    dark: '#F5F0E8',
    light: '#1A1612',
  },
  secondary: {
    dark: '#9E9485',
    light: '#6B6057',
  },
  tertiary: {
    dark: '#5C5448',
    light: '#9E9485',
  },

  // Accent — used sparingly, maximum two uses per screen
  amber: '#C8873A',
  sage: '#7A9E7E',

  // States — emotional state colors
  calm: '#4A7C8E',   // deep teal — listening state
  active: '#C8873A', // amber — speaking state
  processing: '#6B5E4E', // warm brown — thinking state

  // Utility
  border: {
    dark: 'rgba(255,255,255,0.07)',
    light: 'rgba(0,0,0,0.08)',
  },
  overlay: 'rgba(15,13,10,0.6)',
};

// Helper to get colors based on color scheme
export function getColors(isDark: boolean) {
  return {
    depth: isDark ? PreludeColors.depth.dark : PreludeColors.depth.light,
    surface: isDark ? PreludeColors.surface.dark : PreludeColors.surface.light,
    raised: isDark ? PreludeColors.raised.dark : PreludeColors.raised.light,
    primary: isDark ? PreludeColors.primary.dark : PreludeColors.primary.light,
    secondary: isDark ? PreludeColors.secondary.dark : PreludeColors.secondary.light,
    tertiary: isDark ? PreludeColors.tertiary.dark : PreludeColors.tertiary.light,
    border: isDark ? PreludeColors.border.dark : PreludeColors.border.light,
    amber: PreludeColors.amber,
    sage: PreludeColors.sage,
    calm: PreludeColors.calm,
    active: PreludeColors.active,
    processing: PreludeColors.processing,
    overlay: PreludeColors.overlay,
  };
}

export type PreludeTheme = ReturnType<typeof getColors>;

export default PreludeColors;
