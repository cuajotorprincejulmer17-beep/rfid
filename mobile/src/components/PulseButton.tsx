import { Ionicons } from '@expo/vector-icons';
import React from 'react';
import { Pressable, View } from 'react-native';
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
        opacity: pressed ? 0.88 : 1, shadowColor: theme.primary, shadowOpacity: theme.isDark ? 0.55 : 0.28, shadowRadius: 14, shadowOffset: { width: 0, height: 5 }, elevation: 10,
      })}
    >
      <View pointerEvents="none" style={{ width: BTN - 12, height: BTN - 12, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surfaceAlt, borderWidth: 1, borderColor: theme.accent }}>
        <Ionicons name={closing ? 'close' : 'pulse'} size={25} color={theme.accent} />
        <AppText variant="caption" color={theme.accent} style={{ fontSize: 10, fontWeight: '800', letterSpacing: 1.1 }}>
          {closing ? 'CLOSE' : 'MENU'}
        </AppText>
      </View>
    </Pressable>
  );
}
