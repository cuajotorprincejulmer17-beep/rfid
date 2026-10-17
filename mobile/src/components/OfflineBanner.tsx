import React from 'react';
import { View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useOnline } from '../hooks/useOnline';
import { useTheme } from '../theme/ThemeProvider';
import { spacing } from '../theme/tokens';
import { AppText } from './AppText';

export function OfflineBanner() {
  const online = useOnline();
  const { theme } = useTheme();
  const insets = useSafeAreaInsets();
  if (online !== false) return null;
  return (
    <View
      accessibilityLiveRegion="polite"
      style={{ backgroundColor: theme.surfaceAlt, paddingTop: insets.top + spacing.xs, paddingBottom: spacing.xs, paddingHorizontal: spacing.lg }}
    >
      <AppText variant="caption" color={theme.warning} style={{ fontWeight: '600' }}>
        Offline. Showing saved data where available; it may be out of date.
      </AppText>
    </View>
  );
}
