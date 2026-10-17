import { Ionicons } from '@expo/vector-icons';
import React, { useEffect, useRef, useState } from 'react';
import { Animated, Pressable, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useReducedMotion } from '../hooks/useReducedMotion';
import { goTo } from '../navigation/goTo';
import { useOverlay } from '../navigation/OverlayContext';
import { BAR_H, CORE_ITEMS, ITEM_W, coreCenterFromBottom, fanPositions } from '../navigation/pulseCore';
import { useTheme } from '../theme/ThemeProvider';
import { radius } from '../theme/tokens';
import { AppText } from './AppText';

/** Quick-action arc above the Pulse Core button. Leaves the button itself tappable (it becomes Close). */
export function PulseCoreFan() {
  const { overlay, close, openMore } = useOverlay();
  const { theme } = useTheme();
  const insets = useSafeAreaInsets();
  const reduced = useReducedMotion();
  const p = useRef(new Animated.Value(0)).current;
  const [mounted, setMounted] = useState(false);
  const open = overlay === 'core';

  useEffect(() => {
    if (open) setMounted(true);
    Animated.timing(p, { toValue: open ? 1 : 0, duration: reduced ? 0 : 200, useNativeDriver: true }).start(
      ({ finished }) => {
        if (finished && !open) setMounted(false);
      },
    );
  }, [open, reduced, p]);

  if (!mounted) return null;
  const pos = fanPositions(CORE_ITEMS.length);
  const barTop = BAR_H + insets.bottom;

  return (
    <View pointerEvents="box-none" style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }}>
      <Animated.View style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: barTop, opacity: p }}>
        <Pressable
          accessibilityLabel="Dismiss quick actions"
          accessibilityRole="button"
          onPress={close}
          style={{ flex: 1, backgroundColor: theme.isDark ? 'rgba(0,0,0,0.6)' : 'rgba(26,21,48,0.4)' }}
        />
      </Animated.View>
      <View pointerEvents="box-none" style={{ position: 'absolute', left: '50%', bottom: coreCenterFromBottom(insets.bottom), width: 0, height: 0 }}>
        {CORE_ITEMS.map((it, i) => (
          <Animated.View
            key={it.label}
            style={{ position: 'absolute', left: pos[i].x - ITEM_W / 2, bottom: pos[i].h - 32, width: ITEM_W, alignItems: 'center', opacity: p, transform: [{ scale: p }] }}
          >
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={it.label}
              onPress={() => {
                close();
                if (it.action === 'more') openMore();
                else goTo(it.action);
              }}
              style={{ alignItems: 'center', gap: 4 }}
            >
              <View style={{ width: 56, height: 56, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surfaceAlt, borderWidth: 1, borderColor: theme.primary }}>
                <Ionicons name={it.icon} size={24} color={theme.accent} />
              </View>
              <AppText variant="caption" style={{ fontSize: 12, fontWeight: '600' }}>{it.label}</AppText>
            </Pressable>
          </Animated.View>
        ))}
      </View>
    </View>
  );
}
