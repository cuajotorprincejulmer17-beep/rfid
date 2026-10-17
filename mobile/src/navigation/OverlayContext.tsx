import React, { createContext, useCallback, useContext, useEffect, useMemo, useReducer } from 'react';
import { BackHandler } from 'react-native';
import { Overlay, handleBack, overlayReducer } from './overlay';

interface Ctx {
  overlay: Overlay;
  openMore: () => void;
  toggleCore: () => void;
  close: () => void;
}
const C = createContext<Ctx | null>(null);

export function OverlayProvider({ children }: { children: React.ReactNode }) {
  const [overlay, dispatch] = useReducer(overlayReducer, 'none' as Overlay);

  // One Back handler for every overlay: Back closes the overlay before any navigation happens.
  useEffect(() => {
    if (overlay === 'none') return;
    const sub = BackHandler.addEventListener('hardwareBackPress', () => {
      const r = handleBack(overlay);
      if (r.handled) dispatch({ type: 'close' });
      return r.handled;
    });
    return () => sub.remove();
  }, [overlay]);

  const openMore = useCallback(() => dispatch({ type: 'openMore' }), []);
  const toggleCore = useCallback(() => dispatch({ type: 'toggleCore' }), []);
  const close = useCallback(() => dispatch({ type: 'close' }), []);
  const value = useMemo(() => ({ overlay, openMore, toggleCore, close }), [overlay, openMore, toggleCore, close]);
  return <C.Provider value={value}>{children}</C.Provider>;
}

export function useOverlay(): Ctx {
  const v = useContext(C);
  if (!v) throw new Error('useOverlay must be used inside OverlayProvider');
  return v;
}
