import React from 'react';
import { Pressable, View } from 'react-native';
import { AppText } from '../components/AppText';
import { Card } from '../components/Card';
import { Screen } from '../components/Screen';
import { API_URL } from '../config';
import { useTheme } from '../theme/ThemeProvider';
import { minTouch, radius, spacing, ThemePreference } from '../theme/tokens';

const OPTIONS: { value: ThemePreference; label: string; hint: string }[] = [
  { value: 'system', label: 'System', hint: 'Follow your phone' },
  { value: 'dark', label: 'Dark', hint: 'Violet on dark surfaces' },
  { value: 'light', label: 'Light', hint: 'Clean light surfaces' },
  { value: 'mono', label: 'Mono', hint: 'Neutral grayscale' },
  { value: 'midnight', label: 'Midnight', hint: 'Deep navy and violet' },
];

export function SettingsScreen() {
  const { theme, preference, setPreference } = useTheme();
  return (
    <Screen inset={false}>
      <AppText variant="title">Settings</AppText>
      <AppText variant="heading">Appearance</AppText>
      <View accessibilityRole="radiogroup" style={{ gap: spacing.sm }}>
        {OPTIONS.map((o) => {
          const selected = preference === o.value;
          return (
            <Pressable
              key={o.value}
              accessibilityRole="radio"
              accessibilityState={{ selected }}
              accessibilityLabel={`${o.label}. ${o.hint}`}
              onPress={() => setPreference(o.value)}
              style={{
                minHeight: minTouch, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
                paddingHorizontal: spacing.lg, borderRadius: radius.card, backgroundColor: theme.surface,
                borderWidth: selected ? 2 : 1, borderColor: selected ? theme.accent : theme.border,
              }}
            >
              <View>
                <AppText style={{ fontWeight: '600' }}>{o.label}</AppText>
                <AppText variant="caption" muted>{o.hint}</AppText>
              </View>
              {selected ? <AppText color={theme.accent} style={{ fontWeight: '700' }}>Selected</AppText> : null}
            </Pressable>
          );
        })}
      </View>
      <AppText variant="heading">Connection</AppText>
      <Card>
        <AppText variant="caption" muted>School server (EXPO_PUBLIC_API_URL)</AppText>
        <AppText>{API_URL ?? 'Not configured yet. Login arrives in Stage 2.'}</AppText>
      </Card>
    </Screen>
  );
}
