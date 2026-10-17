import { Ionicons } from '@expo/vector-icons';
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';
import React from 'react';
import { Pressable, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { BAR_H, BTN, BTN_TOP } from '../navigation/pulseCore';
import { useOverlay } from '../navigation/OverlayContext';
import type { TabName } from '../navigation/types';
import { useTheme } from '../theme/ThemeProvider';
import { minTouch } from '../theme/tokens';
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
        style={{ flex: 1, minHeight: minTouch, alignItems: 'center', justifyContent: 'center', gap: 2 }}
      >
        <Ionicons name={TAB_ICON[name][focused ? 0 : 1]} size={22} color={color} />
        <AppText variant="caption" color={color} style={{ fontSize: 11 }}>{name}</AppText>
      </Pressable>
    );
  };

  return (
    <View style={{ height: BAR_H + insets.bottom, paddingBottom: insets.bottom, backgroundColor: theme.surface, borderTopColor: theme.border, borderTopWidth: 1 }}>
      <View style={{ flex: 1, flexDirection: 'row', alignItems: 'center' }}>
        {item('Home')}
        {item('Schedule')}
        <View style={{ width: BTN + 16 }} />
        {item('Tasks')}
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="More"
          onPress={openMore}
          style={{ flex: 1, minHeight: minTouch, alignItems: 'center', justifyContent: 'center', gap: 2 }}
        >
          <Ionicons name="ellipsis-horizontal" size={22} color={theme.textMuted} />
          <AppText variant="caption" muted style={{ fontSize: 11 }}>More</AppText>
        </Pressable>
      </View>
      <View style={{ position: 'absolute', top: BTN_TOP, alignSelf: 'center' }}>
        <PulseButton closing={overlay === 'core'} onPress={toggleCore} />
      </View>
    </View>
  );
}
