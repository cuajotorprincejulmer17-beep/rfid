import { Ionicons } from '@expo/vector-icons';
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';
import React from 'react';
import { Pressable, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { BAR_H, BTN, BTN_TOP } from '../navigation/pulseCore';
import { useOverlay } from '../navigation/OverlayContext';
import type { TabName } from '../navigation/types';
import { useTheme } from '../theme/ThemeProvider';
import { minTouch, radius, spacing } from '../theme/tokens';
import { AppText } from './AppText';
import { PulseButton } from './PulseButton';

type Icon = keyof typeof Ionicons.glyphMap;
const TAB_ICON: Record<TabName, [Icon, Icon]> = {
  Home: ['home', 'home-outline'],
  Schedule: ['calendar', 'calendar-outline'],
  Tasks: ['checkbox', 'checkbox-outline'],
};

/** Home, Schedule, [Pulse Core], Tasks, More. More opens an overlay; it is not a route. */
export function TabBar({ state, navigation }: BottomTabBarProps) {
  const { theme } = useTheme();
  const insets = useSafeAreaInsets();
  const { overlay, openMore, toggleCore } = useOverlay();

  const item = (name: TabName) => {
    const focused = state.routes[state.index]?.name === name;
    const color = focused ? theme.accent : theme.textMuted;
    return (
      <Pressable
        key={name}
        accessibilityRole="tab"
        accessibilityLabel={name}
        accessibilityState={{ selected: focused }}
        onPress={() => navigation.navigate(name)}
        style={{ flex: 1, minHeight: minTouch, alignItems: 'center', justifyContent: 'center' }}
      >
        <View style={{ minWidth: focused ? 58 : 44, height: 42, paddingHorizontal: spacing.sm, alignItems: 'center', justifyContent: 'center', borderRadius: radius.pill, backgroundColor: focused ? theme.surfaceAlt : 'transparent', borderWidth: focused ? 1 : 0, borderColor: focused ? theme.border : 'transparent', gap: 1 }}>
          <Ionicons name={TAB_ICON[name][focused ? 0 : 1]} size={20} color={color} />
          <AppText variant="caption" color={color} style={{ fontSize: 10 }}>{name}</AppText>
        </View>
      </Pressable>
    );
  };

  return (
    <View style={{ height: BAR_H + insets.bottom, paddingBottom: insets.bottom, backgroundColor: theme.surface, borderTopColor: theme.border, borderTopWidth: 1, shadowColor: '#000000', shadowOpacity: theme.isDark ? 0.3 : 0.08, shadowRadius: 12, shadowOffset: { width: 0, height: -4 }, elevation: 12 }}>
      <View style={{ flex: 1, flexDirection: 'row', alignItems: 'center' }}>
        {item('Home')}
        {item('Schedule')}
        <View style={{ width: BTN + 16 }} />
        {item('Tasks')}
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="More"
          onPress={openMore}
          style={{ flex: 1, minHeight: minTouch, alignItems: 'center', justifyContent: 'center' }}
        >
          <View style={{ minWidth: overlay === 'more' ? 58 : 44, height: 42, paddingHorizontal: 8, alignItems: 'center', justifyContent: 'center', borderRadius: radius.pill, backgroundColor: overlay === 'more' ? theme.surfaceAlt : 'transparent', borderWidth: overlay === 'more' ? 1 : 0, borderColor: overlay === 'more' ? theme.border : 'transparent', gap: 1 }}>
            <Ionicons name="ellipsis-horizontal" size={21} color={overlay === 'more' ? theme.accent : theme.textMuted} />
            <AppText variant="caption" color={overlay === 'more' ? theme.accent : theme.textMuted} style={{ fontSize: 10 }}>More</AppText>
          </View>
        </Pressable>
      </View>
      <View style={{ position: 'absolute', top: BTN_TOP, alignSelf: 'center' }}>
        <PulseButton closing={overlay === 'core'} onPress={toggleCore} />
      </View>
    </View>
  );
}
