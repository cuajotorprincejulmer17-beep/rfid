import type { NavigatorScreenParams } from '@react-navigation/native';

export type TabParamList = { Home: undefined; Schedule: undefined; Tasks: undefined };

export type RootStackParamList = {
  Tabs: NavigatorScreenParams<TabParamList> | undefined;
  Attendance: undefined;
  Updates: undefined;
  Notes: undefined;
  Review: undefined;
  Settings: undefined;
};

export type TabName = keyof TabParamList;
export type StackName = Exclude<keyof RootStackParamList, 'Tabs'>;
/** A place the user can actually go. Anything else must be shown disabled with a reason. */
export type Dest = { tab: TabName } | { stack: StackName };

/** Screens that exist in the navigator right now (checked by the menu integrity test). */
export const IMPLEMENTED_TABS: TabName[] = ['Home', 'Schedule', 'Tasks'];
export const IMPLEMENTED_STACK: StackName[] = ['Attendance', 'Updates', 'Notes', 'Review', 'Settings'];
