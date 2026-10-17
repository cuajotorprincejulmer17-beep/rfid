import { Ionicons } from '@expo/vector-icons';
import React, { useEffect, useRef, useState } from 'react';
import { Animated, Dimensions, Pressable, ScrollView, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useReducedMotion } from '../hooks/useReducedMotion';
import { goTo } from '../navigation/goTo';
import { MENU } from '../navigation/menu';
import { useOverlay } from '../navigation/OverlayContext';
import { useTheme } from '../theme/ThemeProvider';
import { radius, spacing } from '../theme/tokens';
import { AppText } from './AppText';
import { PulseButton } from './PulseButton';

const HEIGHT = Dimensions.get('window').height;

/** Full-height, scrollable overlay. Back handling lives in OverlayProvider (closes this first). */
export function MoreSheet() {
  const { overlay, close } = useOverlay();
  const { theme } = useTheme();
  const insets = useSafeAreaInsets();
  const reduced = useReducedMotion();
  const y = useRef(new Animated.Value(HEIGHT)).current;
  const [mounted, setMounted] = useState(false);
  const open = overlay === 'more';

  useEffect(() => {
    if (open) setMounted(true);
    Animated.timing(y, { toValue: open ? 0 : HEIGHT, duration: reduced ? 0 : 260, useNativeDriver: true }).start(
      ({ finished }) => {
        if (finished && !open) setMounted(false);
      },
    );
  }, [open, reduced, y]);

  if (!mounted) return null;

  return (
    <Animated.View
      accessibilityViewIsModal
      style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: theme.bg, transform: [{ translateY: y }] }}
    >
      <ScrollView
        contentContainerStyle={{ paddingTop: insets.top + spacing.lg, paddingHorizontal: spacing.lg, paddingBottom: insets.bottom + 150, gap: spacing.lg }}
      >
        <AppText variant="title">More</AppText>
        {MENU.map((g) => (
          <View key={g.title} style={{ gap: spacing.md, padding: spacing.lg, borderRadius: radius.lg, backgroundColor: theme.surface, borderWidth: 1, borderColor: theme.border }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
              <Ionicons name={g.icon} size={22} color={theme.accent} />
              <AppText variant="heading">{g.title}</AppText>
              <View style={{ flex: 1, height: 1, backgroundColor: theme.primary, opacity: 0.6 }} />
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
                    style={{ width: g.columns === 3 ? '33.33%' : '50%', alignItems: 'center', gap: spacing.xs, minHeight: 96, opacity: dest ? 1 : 0.5 }}
                  >
                    <View style={{ width: 56, height: 56, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surfaceAlt }}>
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
