import type { Ionicons } from '@expo/vector-icons';
import type { Dest } from './types';

type Icon = keyof typeof Ionicons.glyphMap;
export interface CoreItem {
  label: string;
  icon: Icon;
  /** 'more' opens the More overlay (a separate interaction); otherwise navigate. */
  action: Dest | 'more';
}

export const CORE_ITEMS: CoreItem[] = [
  { label: 'Home', icon: 'home-outline', action: { tab: 'Home' } },
  { label: 'Schedule', icon: 'calendar-outline', action: { tab: 'Schedule' } },
  { label: 'Attendance', icon: 'card-outline', action: { stack: 'Attendance' } },
  { label: 'Tasks', icon: 'checkbox-outline', action: { tab: 'Tasks' } },
  { label: 'Updates', icon: 'megaphone-outline', action: { stack: 'Updates' } },
  { label: 'More', icon: 'ellipsis-horizontal', action: 'more' },
];

// Tab bar geometry shared by the bar and the fan so they line up.
export const BAR_H = 64;
export const BTN = 72;
export const BTN_TOP = -30;
export const ITEM_W = 72;
/** Distance from the screen bottom to the centre of the Pulse Core button. */
export const coreCenterFromBottom = (bottomInset: number) => BAR_H + bottomInset - (BTN_TOP + BTN / 2);

/** Arc positions: x offset from the button centre, h height above it. */
export function fanPositions(count: number, radius = 118, startDeg = 145, endDeg = 35) {
  return Array.from({ length: count }, (_, i) => {
    const deg = count === 1 ? 90 : startDeg - (i * (startDeg - endDeg)) / (count - 1);
    const rad = (deg * Math.PI) / 180;
    return { x: radius * Math.cos(rad), h: radius * Math.sin(rad) };
  });
}
