import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { DefaultTheme, NavigationContainer, Theme } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import React, { useMemo } from 'react';
import { View } from 'react-native';
import { MoreSheet } from '../components/MoreSheet';
import { PulseCoreFan } from '../components/PulseCoreFan';
import { TabBar } from '../components/TabBar';
import { HomeScreen } from '../screens/HomeScreen';
import { AttendanceScreen, NotesScreen, ReviewScreen, ScheduleScreen, TasksScreen, UpdatesScreen } from '../screens/placeholders';
import { SettingsScreen } from '../screens/SettingsScreen';
import { useTheme } from '../theme/ThemeProvider';
import { navigationRef } from './goTo';
import { OverlayProvider } from './OverlayContext';
import type { RootStackParamList, TabParamList } from './types';

const Tab = createBottomTabNavigator<TabParamList>();
const Stack = createNativeStackNavigator<RootStackParamList>();

function Tabs() {
  return (
    <Tab.Navigator tabBar={(p) => <TabBar {...p} />} screenOptions={{ headerShown: false }}>
      <Tab.Screen name="Home" component={HomeScreen} />
      <Tab.Screen name="Schedule" component={ScheduleScreen} />
      <Tab.Screen name="Tasks" component={TasksScreen} />
    </Tab.Navigator>
  );
}

export function RootNavigator() {
  const { theme } = useTheme();
  const navTheme = useMemo<Theme>(
    () => ({
      ...DefaultTheme,
      dark: theme.isDark,
      colors: { primary: theme.accent, background: theme.bg, card: theme.surface, text: theme.text, border: theme.border, notification: theme.primary },
    }),
    [theme],
  );
  return (
    <OverlayProvider>
      <NavigationContainer ref={navigationRef} theme={navTheme}>
        <View style={{ flex: 1 }}>
          <Stack.Navigator screenOptions={{ headerStyle: { backgroundColor: theme.surface }, headerTintColor: theme.text, contentStyle: { backgroundColor: theme.bg } }}>
            <Stack.Screen name="Tabs" component={Tabs} options={{ headerShown: false }} />
            <Stack.Screen name="Attendance" component={AttendanceScreen} />
            <Stack.Screen name="Updates" component={UpdatesScreen} />
            <Stack.Screen name="Notes" component={NotesScreen} />
            <Stack.Screen name="Review" component={ReviewScreen} />
            <Stack.Screen name="Settings" component={SettingsScreen} />
          </Stack.Navigator>
          <PulseCoreFan />
          <MoreSheet />
        </View>
      </NavigationContainer>
    </OverlayProvider>
  );
}
