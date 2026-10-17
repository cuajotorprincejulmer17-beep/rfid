import { createNavigationContainerRef } from '@react-navigation/native';
import type { Dest, RootStackParamList } from './types';

export const navigationRef = createNavigationContainerRef<RootStackParamList>();

export function goTo(dest: Dest): void {
  if (!navigationRef.isReady()) return;
  if ('tab' in dest) navigationRef.navigate('Tabs', { screen: dest.tab });
  else navigationRef.navigate(dest.stack);
}
