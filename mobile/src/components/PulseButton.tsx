import { Ionicons } from '@expo/vector-icons';
import React, { useEffect, useRef } from 'react';
import { Animated, Pressable, View } from 'react-native';
import { useReducedMotion } from '../hooks/useReducedMotion';
import { useTheme } from '../theme/ThemeProvider';
import { radius } from '../theme/tokens';
import { AppText } from './AppText';
import { BTN } from '../navigation/pulseCore';

/** The circular Pulse Core control. `closing` swaps it to the close state used while an overlay is open. */
export function PulseButton({ closing, onPress }: { closing: boolean; onPress: () => void }) {
  const { theme } = useTheme();
  const reduced = useReducedMotion();
  const motion = useRef(new Animated.Value(closing ? 1 : 0)).current;

  useEffect(() => {
    Animated.timing(motion, { toValue: closing ? 1 : 0, duration: reduced ? 0 : 180, useNativeDriver: true }).start();
  }, [closing, motion, reduced]);

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={closing ? 'Close menu' : 'Pulse Core quick actions'}
      accessibilityState={{ expanded: closing }}
      onPress={onPress}
      style={({ pressed }) => ({
        width: BTN, height: BTN, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center',
        backgroundColor: theme.bg, borderWidth: 2, borderColor: theme.primary,
        opacity: pressed ? 0.88 : 1, shadowColor: theme.primary, shadowOpacity: theme.isDark ? 0.55 : 0.28, shadowRadius: 14, shadowOffset: { width: 0, height: 5 }, elevation: 10,
      })}
    >
      <View pointerEvents="none" style={{ width: BTN - 8, height: BTN - 8, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surface, borderWidth: 1, borderColor: theme.primary }}>
        <Animated.View style={{ width: BTN - 20, height: BTN - 20, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surfaceAlt, borderWidth: 1, borderColor: theme.accent, transform: [{ rotate: motion.interpolate({ inputRange: [0, 1], outputRange: ['0deg', '90deg'] }) }, { scale: motion.interpolate({ inputRange: [0, 1], outputRange: [1, 0.95] }) }] }}>
          <Ionicons name={closing ? 'close' : 'pulse'} size={25} color={theme.accent} />
          <AppText variant="caption" color={theme.accent} style={{ fontSize: 10, fontWeight: '800', letterSpacing: 1.1 }}>
            {closing ? 'CLOSE' : 'MENU'}
          </AppText>
        </Animated.View>
      </View>
    </Pressable>
  );
}
