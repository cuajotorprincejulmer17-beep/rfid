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
        },
        style,
      ]}
    />
  );
}
