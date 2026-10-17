import React from 'react';
import { View, ViewProps } from 'react-native';
import { useTheme } from '../theme/ThemeProvider';
import { radius, spacing } from '../theme/tokens';

export function Card({ style, ...rest }: ViewProps) {
  const { theme } = useTheme();
  return (
    <View
      {...rest}
      style={[
        {
          backgroundColor: theme.surface,
          borderColor: theme.border,
          borderWidth: 1,
          borderRadius: radius.lg,
          padding: spacing.lg,
          shadowColor: '#000000',
          shadowOpacity: theme.isDark ? 0.2 : 0.06,
          shadowRadius: 10,
          shadowOffset: { width: 0, height: 5 },
          elevation: theme.isDark ? 2 : 1,
        },
        style,
      ]}
    />
  );
}
