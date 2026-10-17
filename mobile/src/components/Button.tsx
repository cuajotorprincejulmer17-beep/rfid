import React from 'react';
import { Pressable } from 'react-native';
import { useTheme } from '../theme/ThemeProvider';
import { minTouch, radius, spacing } from '../theme/tokens';
import { AppText } from './AppText';

interface Props {
  label: string;
  onPress: () => void;
  variant?: 'primary' | 'secondary';
  disabled?: boolean;
}

export function Button({ label, onPress, variant = 'primary', disabled }: Props) {
  const { theme } = useTheme();
  const primary = variant === 'primary';
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled: !!disabled }}
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => ({
        minHeight: minTouch,
        paddingHorizontal: spacing.xl,
        borderRadius: radius.md,
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: primary ? theme.primary : theme.surfaceAlt,
        borderWidth: primary ? 0 : 1,
        borderColor: theme.border,
        opacity: disabled ? 0.45 : pressed ? 0.85 : 1,
      })}
    >
      <AppText variant="body" color={primary ? theme.onPrimary : theme.text} style={{ fontWeight: '600' }}>
        {label}
      </AppText>
    </Pressable>
  );
}
