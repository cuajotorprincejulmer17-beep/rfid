import { Ionicons } from '@expo/vector-icons';
import React, { useEffect, useRef, useState } from 'react';
import { Animated, Pressable, ScrollView, useWindowDimensions, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useReducedMotion } from '../hooks/useReducedMotion';
import { goTo } from '../navigation/goTo';
import { MENU } from '../navigation/menu';
import { useOverlay } from '../navigation/OverlayContext';
import { BAR_H } from '../navigation/pulseCore';
import type { Dest } from '../navigation/types';
import { mix } from '../theme/color';
import { useTheme } from '../theme/ThemeProvider';
import { minTouch, radius, spacing } from '../theme/tokens';
import { AppText } from './AppText';
import { PulseDock } from './PulseDock';

const HEADER_H = 64;

/** A rounded, scrollable panel over the dimmed app; Back closes it through OverlayProvider. */
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
  const dockH = BAR_H + insets.bottom;
  const edge = mix(theme.border, theme.primary, 0.45);
  const go = (dest: Dest) => {
    close();
    goTo(dest);
  };

  return (
    <View style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }} accessibilityViewIsModal>
      <Pressable
        accessibilityLabel="Close menu"
        accessibilityRole="button"
        onPress={close}
        style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: theme.isDark ? 'rgba(3,2,10,0.72)' : 'rgba(26,21,48,0.5)' }}
      />
      <View pointerEvents="box-none" style={{ paddingTop: insets.top, height: insets.top + HEADER_H, paddingHorizontal: spacing.lg, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
          <View style={{ width: 34, height: 34, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surface, borderWidth: 1, borderColor: edge }}>
            <Ionicons name="pulse" size={20} color={theme.accent} />
          </View>
          <AppText variant="heading" color={theme.text} style={{ letterSpacing: 3.5, fontSize: 18 }}>PULSE</AppText>
        </View>
        <View style={{ flexDirection: 'row', gap: spacing.sm }}>
          {([['notifications-outline', 'Updates', { stack: 'Updates' }], ['settings-outline', 'Settings', { stack: 'Settings' }]] as const).map(([icon, label, dest]) => (
            <Pressable key={label} accessibilityRole="button" accessibilityLabel={label} onPress={() => go(dest)} style={{ width: minTouch, height: minTouch, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surface, borderWidth: 1, borderColor: edge }}>
              <Ionicons name={icon} size={21} color={theme.accent} />
            </Pressable>
          ))}
        </View>
      </View>
      <Animated.View style={{ position: 'absolute', top: insets.top + HEADER_H, left: 0, right: 0, bottom: 0, backgroundColor: theme.bg, borderTopLeftRadius: radius.panel, borderTopRightRadius: radius.panel, borderTopWidth: 1, borderColor: edge, overflow: 'hidden', transform: [{ translateY: y }] }}>
        <View style={{ alignSelf: 'center', width: 44, height: 4, borderRadius: radius.pill, backgroundColor: edge, marginTop: spacing.sm }} />
        <ScrollView contentContainerStyle={{ padding: spacing.lg, paddingBottom: dockH + spacing.xxl, gap: spacing.lg }}>
          {MENU.map((group) => (
            <View key={group.title} style={{ gap: spacing.md, padding: spacing.lg, borderRadius: radius.panel, backgroundColor: theme.surface, borderWidth: 1, borderColor: theme.border, shadowColor: '#000000', shadowOpacity: theme.isDark ? 0.18 : 0.05, shadowRadius: 10, shadowOffset: { width: 0, height: 5 }, elevation: theme.isDark ? 2 : 1 }}>
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
                <View style={{ width: 30, height: 30, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surfaceAlt }}>
                  <Ionicons name={group.icon} size={17} color={theme.accent} />
                </View>
                <AppText variant="heading" style={{ fontSize: 18 }}>{group.title}</AppText>
                <View style={{ flex: 1, height: 1, backgroundColor: edge, opacity: 0.7 }} />
              </View>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', rowGap: spacing.lg, paddingTop: spacing.xs }}>
                {group.tiles.map((tile) => {
                  const dest = tile.dest;
                  return (
                    <Pressable key={tile.label} accessibilityRole="button" accessibilityLabel={dest ? tile.label : `${tile.label}, unavailable: ${tile.reason}`} accessibilityState={{ disabled: !dest }} disabled={!dest} onPress={() => dest && go(dest)} style={({ pressed }) => ({ width: group.columns === 3 ? '33.33%' : '50%', alignItems: 'center', gap: spacing.xs, minHeight: 100, opacity: dest ? (pressed ? 0.76 : 1) : 0.48 })}>
                      <View style={{ width: 58, height: 58, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surfaceAlt, borderWidth: 1, borderColor: dest ? theme.border : 'transparent', shadowColor: theme.primary, shadowOpacity: dest && theme.isDark ? 0.14 : 0, shadowRadius: 8, shadowOffset: { width: 0, height: 3 }, elevation: dest && theme.isDark ? 2 : 0 }}>
                        <Ionicons name={tile.icon} size={26} color={theme.accent} />
                      </View>
                      <AppText variant="caption" style={{ fontWeight: '600', textAlign: 'center' }}>{tile.label}</AppText>
                      {tile.reason ? <AppText variant="caption" muted style={{ fontSize: 12, textAlign: 'center' }}>{tile.reason}</AppText> : null}
                    </Pressable>
                  );
                })}
              </View>
            </View>
          ))}
        </ScrollView>
        <View style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: dockH, backgroundColor: theme.surface, borderTopWidth: 1, borderTopColor: theme.border }}>
          <PulseDock closing onPress={close} />
        </View>
      </Animated.View>
    </View>
  );
}
