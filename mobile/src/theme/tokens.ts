export type ThemeName = 'dark' | 'light' | 'mono' | 'midnight';
export type ThemePreference = ThemeName | 'system';

export interface Palette {
  name: ThemeName;
  isDark: boolean;
  bg: string;
  surface: string;
  surfaceAlt: string;
  border: string;
  text: string;
  textMuted: string;
  primary: string;
  onPrimary: string;
  accent: string;
  success: string;
  warning: string;
  danger: string;
}

export const palettes: Record<ThemeName, Palette> = {
  dark: {
    name: 'dark', isDark: true,
    bg: '#080B17', surface: '#111526', surfaceAlt: '#191D34', border: '#2D3150',
    text: '#F4F2FF', textMuted: '#B4AFD0',
    primary: '#7C3AED', onPrimary: '#FFFFFF', accent: '#B69AFF',
    success: '#34D399', warning: '#FBBF24', danger: '#F87171',
  },
  light: {
    name: 'light', isDark: false,
    bg: '#F7F5FF', surface: '#FFFFFF', surfaceAlt: '#EEEAFB', border: '#D9D2F2',
    text: '#1A1530', textMuted: '#5B5675',
    primary: '#6D28D9', onPrimary: '#FFFFFF', accent: '#7C3AED',
    success: '#047857', warning: '#92400E', danger: '#B91C1C',
  },
  mono: {
    name: 'mono', isDark: true,
    bg: '#0A0A0A', surface: '#141414', surfaceAlt: '#1F1F1F', border: '#333333',
    text: '#F5F5F5', textMuted: '#B3B3B3',
    primary: '#E5E5E5', onPrimary: '#0A0A0A', accent: '#A3A3A3',
    success: '#86EFAC', warning: '#FDE68A', danger: '#FCA5A5',
  },
  midnight: {
    name: 'midnight', isDark: true,
    bg: '#060A18', surface: '#0D1430', surfaceAlt: '#151E42', border: '#29366F',
    text: '#EEF2FF', textMuted: '#AAB6E0',
    primary: '#7C3AED', onPrimary: '#FFFFFF', accent: '#A78BFA',
    success: '#34D399', warning: '#FBBF24', danger: '#F87171',
  },
};

export const spacing = { xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32, xxxl: 40 } as const;
export const radius = { sm: 8, md: 12, lg: 16, xl: 24, pill: 999 } as const;
export const minTouch = 48;
