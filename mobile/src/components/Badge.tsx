import React from 'react';
import { View } from 'react-native';
import { useTheme } from '../theme/ThemeProvider';
import { radius, spacing } from '../theme/tokens';
import { AppText } from './AppText';

/** Small label, e.g. "Sample data" so demonstration content is never mistaken for real records. */
export function Badge({ label }: { label: string }) {
  const { theme } = useTheme();
  return (
    <View
      style={{
        alignSelf: 'flex-start',
        backgroundColor: theme.surfaceAlt,
        borderColor: theme.border,
        borderWidth: 1,
        borderRadius: radius.pill,
        paddingHorizontal: spacing.md,
        paddingVertical: spacing.xs,
      }}
    >
      <AppText variant="caption" color={theme.accent} style={{ fontWeight: '600' }}>
        {label}
      </AppText>
    </View>
  );
}
