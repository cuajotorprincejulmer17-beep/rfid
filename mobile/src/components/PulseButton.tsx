import { Ionicons } from '@expo/vector-icons';
import React from 'react';
import { Pressable } from 'react-native';
import { useTheme } from '../theme/ThemeProvider';
import { radius } from '../theme/tokens';
import { AppText } from './AppText';
import { BTN } from '../navigation/pulseCore';

/** The circular Pulse Core control. `closing` swaps it to the close state used while an overlay is open. */
export function PulseButton({ closing, onPress }: { closing: boolean; onPress: () => void }) {
  const { theme } = useTheme();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={closing ? 'Close menu' : 'Pulse Core quick actions'}
      accessibilityState={{ expanded: closing }}
      onPress={onPress}
      style={({ pressed }) => ({
        width: BTN, height: BTN, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center',
        backgroundColor: theme.surface, borderWidth: 2.5, borderColor: theme.primary,
        opacity: pressed ? 0.85 : 1, shadowColor: theme.primary, shadowOpacity: 0.35, shadowRadius: 10, elevation: 6,
      })}
    >
      <Ionicons name={closing ? 'close' : 'pulse'} size={26} color={theme.accent} />
      <AppText variant="caption" color={theme.accent} style={{ fontSize: 10, fontWeight: '700', letterSpacing: 1 }}>
        {closing ? 'CLOSE' : 'MENU'}
      </AppText>
    </Pressable>
  );
}
