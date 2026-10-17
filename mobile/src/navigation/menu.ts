import type { Ionicons } from '@expo/vector-icons';
import type { Dest } from './types';

type Icon = keyof typeof Ionicons.glyphMap;
export interface MenuTile {
  label: string;
  icon: Icon;
  /** Present = tapping navigates. Absent = rendered disabled and `reason` explains why. */
  dest?: Dest;
  reason?: string;
}
export interface MenuGroup {
  title: string;
  icon: Icon;
  columns: 2 | 3;
  tiles: MenuTile[];
}

export const MENU: MenuGroup[] = [
  {
    title: 'Academic', icon: 'school-outline', columns: 3,
    tiles: [
      { label: 'Schedule', icon: 'calendar-outline', dest: { tab: 'Schedule' } },
      { label: 'Attendance', icon: 'card-outline', dest: { stack: 'Attendance' } },
      { label: 'Tasks & Planner', icon: 'checkbox-outline', dest: { tab: 'Tasks' } },
      { label: 'Announcements', icon: 'megaphone-outline', dest: { stack: 'Updates' } },
      { label: 'Workload', icon: 'bar-chart-outline', reason: 'Coming soon' },
      { label: 'Insights', icon: 'bulb-outline', reason: 'Coming soon' },
    ],
  },
  {
    title: 'Study Space', icon: 'book-outline', columns: 3,
    tiles: [
      { label: 'Notes', icon: 'document-text-outline', dest: { stack: 'Notes' } },
      { label: 'Review', icon: 'layers-outline', dest: { stack: 'Review' } },
    ],
  },
  {
    title: 'Campus', icon: 'business-outline', columns: 2,
    tiles: [
      { label: 'Digital ID', icon: 'id-card-outline', reason: 'Needs school ID system' },
      { label: 'Room Finder', icon: 'location-outline', reason: 'No campus data yet' },
      { label: 'Directory', icon: 'people-outline', reason: 'Coming soon' },
      { label: 'Lost & Found', icon: 'cube-outline', reason: 'Needs school backend' },
    ],
  },
  {
    title: 'Personal', icon: 'person-outline', columns: 2,
    tiles: [
      { label: 'Profile', icon: 'person-circle-outline', reason: 'Coming soon' },
      { label: 'Settings', icon: 'settings-outline', dest: { stack: 'Settings' } },
      { label: 'Help & Support', icon: 'help-circle-outline', reason: 'Coming soon' },
    ],
  },
];
