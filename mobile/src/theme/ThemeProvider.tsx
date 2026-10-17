import AsyncStorage from '@react-native-async-storage/async-storage';
import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { useColorScheme } from 'react-native';
import { Palette, ThemePreference, palettes } from './tokens';

const KEY = 'pulse.themePreference';
const VALID: ThemePreference[] = ['system', 'dark', 'light', 'mono', 'midnight'];

interface ThemeCtx {
  theme: Palette;
  preference: ThemePreference;
  setPreference: (p: ThemePreference) => void;
}

const Ctx = createContext<ThemeCtx | null>(null);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const system = useColorScheme();
  const [preference, setPref] = useState<ThemePreference>('system');

  useEffect(() => {
    AsyncStorage.getItem(KEY)
      .then((v) => {
        if (v && (VALID as string[]).includes(v)) setPref(v as ThemePreference);
      })
      .catch(() => {
        /* storage unavailable: keep the system default */
      });
  }, []);

  const setPreference = useCallback((p: ThemePreference) => {
    setPref(p);
    AsyncStorage.setItem(KEY, p).catch(() => {
      /* preference still applies for this session */
    });
  }, []);

  const value = useMemo<ThemeCtx>(() => {
    const name = preference === 'system' ? (system === 'light' ? 'light' : 'dark') : preference;
    return { theme: palettes[name], preference, setPreference };
  }, [preference, system, setPreference]);

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useTheme(): ThemeCtx {
  const v = useContext(Ctx);
  if (!v) throw new Error('useTheme must be used inside ThemeProvider');
  return v;
}
