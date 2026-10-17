import React from 'react';
import { View, ViewProps } from 'react-native';
import { useTheme } from '../theme/ThemeProvider';
import { radius, spacing } from '../theme/tokens';

type CardVariant = 'card' | 'feature' | 'panel' | 'row';

interface Props extends ViewProps {
  /** Semantic silhouette for content surfaces. Compact controls use Button/Badge instead. */
  variant?: CardVariant;
}

const cardRadius: Record<CardVariant, number> = {
  card: radius.card,
  feature: radius.panel,
  panel: radius.panel,
  row: radius.lg,
};

export function Card({ variant = 'card', style, ...rest }: Props) {
  const { theme } = useTheme();
  return (
    <View
      {...rest}
      style={[
        {
          backgroundColor: theme.surface,
          borderColor: theme.border,
          borderWidth: 1,
          borderRadius: cardRadius[variant],
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
