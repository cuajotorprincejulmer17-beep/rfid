/** Which full-screen overlay is open. Overlays never touch navigation history. */
export type Overlay = 'none' | 'more' | 'core';
export type OverlayAction =
  | { type: 'openMore' }
  | { type: 'openCore' }
  | { type: 'toggleCore' }
  | { type: 'close' };

export function overlayReducer(state: Overlay, action: OverlayAction): Overlay {
  switch (action.type) {
    case 'openMore':
      return 'more';
    case 'openCore':
      return 'core';
    // Pulse Core is the close control while any overlay is open (as in the design).
    case 'toggleCore':
      return state === 'none' ? 'core' : 'none';
    case 'close':
      return 'none';
  }
}

/** Android Back: close an open overlay first; otherwise let normal navigation handle it. */
export function handleBack(state: Overlay): { state: Overlay; handled: boolean } {
  return state === 'none' ? { state, handled: false } : { state: 'none', handled: true };
}
