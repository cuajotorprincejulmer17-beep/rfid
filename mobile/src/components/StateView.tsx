import { Ionicons } from '@expo/vector-icons';
import React from 'react';
import { ActivityIndicator, View } from 'react-native';
import { useTheme } from '../theme/ThemeProvider';
import { spacing } from '../theme/tokens';
import { AppText } from './AppText';
import { Button } from './Button';

type Kind = 'loading' | 'empty' | 'offline' | 'error';
interface Props {
  kind: Kind;
  title?: string;
  message?: string;
  onRetry?: () => void;
}

const ICON: Record<Exclude<Kind, 'loading'>, keyof typeof Ionicons.glyphMap> = {
  empty: 'document-text-outline',
  offline: 'wifi-outline',
  error: 'alert-circle-outline',
};
const DEFAULT_TITLE: Record<Kind, string> = {
  loading: 'Loading…',
  empty: 'Nothing here yet',
  offline: "You're offline",
  error: 'Something went wrong',
};

/** One component for loading / empty / offline / error. A failure is never shown as "empty". */
export function StateView({ kind, title, message, onRetry }: Props) {
  const { theme } = useTheme();
  const tone = kind === 'error' ? theme.danger : theme.accent;
  return (
    <View
      accessibilityRole={kind === 'error' ? 'alert' : undefined}
      accessibilityLiveRegion="polite"
      style={{ alignItems: 'center', padding: spacing.xl, gap: spacing.md }}
    >
      {kind === 'loading' ? (
        <ActivityIndicator color={theme.accent} size="large" />
      ) : (
        <Ionicons name={ICON[kind]} size={40} color={tone} />
      )}
      <AppText variant="heading">{title ?? DEFAULT_TITLE[kind]}</AppText>
      {message ? (
        <AppText muted style={{ textAlign: 'center' }}>
          {message}
        </AppText>
      ) : null}
      {onRetry && kind !== 'loading' && kind !== 'empty' ? <Button label="Retry" onPress={onRetry} variant="secondary" /> : null}
    </View>
  );
}
