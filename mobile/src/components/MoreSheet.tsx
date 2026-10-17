import { Ionicons } from '@expo/vector-icons';
import React, { useEffect, useRef, useState } from 'react';
import { Animated, Pressable, ScrollView, useWindowDimensions, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useReducedMotion } from '../hooks/useReducedMotion';
import { goTo } from '../navigation/goTo';
import { MENU } from '../navigation/menu';
import { useOverlay } from '../navigation/OverlayContext';
import { useTheme } from '../theme/ThemeProvider';
import { radius, spacing } from '../theme/tokens';
import { AppText } from './AppText';
import { PulseButton } from './PulseButton';

/** Full-height, scrollable overlay. Back handling lives in OverlayProvider (closes this first). */
export function MoreSheet() {
  const { overlay, close } = useOverlay();
  const { theme } = useTheme();
  const insets = useSafeAreaInsets();
  const reduced = useReducedMotion();
  const { height } = useWindowDimensions();
  const y = useRef(new Animated.Value(height)).current;
  const [mounted, setMounted] = useState(false);
  const open = overlay === 'more';

  useEffect(() => {
    if (open) setMounted(true);
    Animated.timing(y, { toValue: open ? 0 : height, duration: reduced ? 0 : 260, useNativeDriver: true }).start(
      ({ finished }) => {
        if (finished && !open) setMounted(false);
      },
    );
  }, [height, open, reduced, y]);

  if (!mounted) return null;

  return (
    <Animated.View
      accessibilityViewIsModal
      style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: theme.bg, transform: [{ translateY: y }] }}
    >
      <ScrollView
        contentContainerStyle={{ paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.lg, paddingBottom: insets.bottom + 142, gap: spacing.lg }}
      >
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
          <View style={{ gap: 2 }}>
            <AppText variant="caption" color={theme.accent} style={{ fontWeight: '800', letterSpacing: 1.4 }}>PULSE</AppText>
            <AppText variant="title">More</AppText>
          </View>
          <View style={{ width: 42, height: 42, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surfaceAlt, borderWidth: 1, borderColor: theme.border }}>
            <Ionicons name="grid-outline" size={21} color={theme.accent} />
          </View>
        </View>
        {MENU.map((g) => (
          <View key={g.title} style={{ gap: spacing.md, paddingTop: spacing.sm, paddingBottom: spacing.lg, borderBottomWidth: 1, borderBottomColor: theme.border }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm, paddingHorizontal: spacing.xs }}>
              <View style={{ width: 30, height: 30, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surfaceAlt }}>
                <Ionicons name={g.icon} size={17} color={theme.accent} />
              </View>
              <AppText variant="heading" style={{ fontSize: 18 }}>{g.title}</AppText>
              <View style={{ flex: 1, height: 1, backgroundColor: theme.primary, opacity: 0.32 }} />
            </View>
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', rowGap: spacing.lg }}>
              {g.tiles.map((t) => {
                const dest = t.dest;
                return (
                  <Pressable
                    key={t.label}
                    accessibilityRole="button"
                    accessibilityLabel={dest ? t.label : `${t.label}, unavailable: ${t.reason}`}
                    accessibilityState={{ disabled: !dest }}
                    disabled={!dest}
                    onPress={() => {
                      close();
                      if (dest) goTo(dest);
                    }}
                    style={({ pressed }) => ({ width: g.columns === 3 ? '33.33%' : '50%', alignItems: 'center', gap: spacing.xs, minHeight: 100, opacity: dest ? (pressed ? 0.76 : 1) : 0.48 })}
                  >
                    <View style={{ width: 58, height: 58, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surfaceAlt, borderWidth: 1, borderColor: dest ? theme.border : 'transparent' }}>
                      <Ionicons name={t.icon} size={26} color={theme.accent} />
                    </View>
                    <AppText variant="caption" style={{ fontWeight: '600', textAlign: 'center' }}>{t.label}</AppText>
                    {t.reason ? <AppText variant="caption" muted style={{ fontSize: 12, textAlign: 'center' }}>{t.reason}</AppText> : null}
                  </Pressable>
                );
              })}
            </View>
          </View>
        ))}
      </ScrollView>
      <View style={{ position: 'absolute', alignSelf: 'center', bottom: insets.bottom + spacing.lg }}>
        <PulseButton closing onPress={close} />
      </View>
    </Animated.View>
  );
}
