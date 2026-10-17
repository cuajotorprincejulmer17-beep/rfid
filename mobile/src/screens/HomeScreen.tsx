import { Ionicons } from '@expo/vector-icons';
import React from 'react';
import { Pressable, View } from 'react-native';
import { AppText } from '../components/AppText';
import { Badge } from '../components/Badge';
import { Card } from '../components/Card';
import { Screen } from '../components/Screen';
import { SAMPLE } from '../mock/sample';
import { goTo } from '../navigation/goTo';
import type { Dest } from '../navigation/types';
import { useTheme } from '../theme/ThemeProvider';
import { minTouch, radius, spacing } from '../theme/tokens';

type Icon = keyof typeof Ionicons.glyphMap;

function greeting(d = new Date()): string {
  const h = d.getHours();
  return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
}

function Tappable({ dest, label, children }: { dest: Dest; label: string; children: React.ReactNode }) {
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={`${label}. Sample data.`} onPress={() => goTo(dest)} style={{ flexBasis: '47%', flexGrow: 1 }}>
      <Card style={{ gap: spacing.xs }}>{children}</Card>
    </Pressable>
  );
}

function IconBtn({ icon, label, dest }: { icon: Icon; label: string; dest: Dest }) {
  const { theme } = useTheme();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={() => goTo(dest)}
      style={{ width: minTouch, height: minTouch, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surface, borderWidth: 1, borderColor: theme.border }}
    >
      <Ionicons name={icon} size={22} color={theme.accent} />
    </Pressable>
  );
}

export function HomeScreen() {
  const { theme } = useTheme();
  return (
    <Screen>
      <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
          <Ionicons name="pulse" size={26} color={theme.accent} />
          <AppText variant="heading" style={{ letterSpacing: 4 }}>PULSE</AppText>
        </View>
        <View style={{ flexDirection: 'row', gap: spacing.sm }}>
          <IconBtn icon="notifications-outline" label="Updates" dest={{ stack: 'Updates' }} />
          <IconBtn icon="person-outline" label="Settings" dest={{ stack: 'Settings' }} />
        </View>
      </View>
      <View>
        <AppText variant="body" muted>{greeting()}</AppText>
        <AppText variant="title">Welcome back</AppText>
      </View>
      <Badge label="Prototype preview · sample data, not your records" />
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.md }}>
        <Tappable dest={{ stack: 'Attendance' }} label={`Attendance ${SAMPLE.attendancePercent}%`}>
          <Ionicons name="card-outline" size={22} color={theme.accent} />
          <AppText variant="caption" muted>Attendance</AppText>
          <AppText variant="heading">{SAMPLE.attendancePercent}%</AppText>
        </Tappable>
        <Tappable dest={{ tab: 'Schedule' }} label={`Next class ${SAMPLE.nextClass.title}`}>
          <Ionicons name="calendar-outline" size={22} color={theme.accent} />
          <AppText variant="caption" muted>Next class</AppText>
          <AppText variant="heading">{SAMPLE.nextClass.title} · {SAMPLE.nextClass.time}</AppText>
        </Tappable>
        <Tappable dest={{ tab: 'Tasks' }} label={`Tasks ${SAMPLE.tasksPending} pending`}>
          <Ionicons name="checkbox-outline" size={22} color={theme.accent} />
          <AppText variant="caption" muted>Tasks</AppText>
          <AppText variant="heading">{SAMPLE.tasksPending} pending</AppText>
        </Tappable>
        <Tappable dest={{ stack: 'Updates' }} label={`Announcements ${SAMPLE.announcementsNew} new`}>
          <Ionicons name="megaphone-outline" size={22} color={theme.accent} />
          <AppText variant="caption" muted>Announcements</AppText>
          <AppText variant="heading">{SAMPLE.announcementsNew} new</AppText>
        </Tappable>
      </View>
      <AppText variant="heading">Study Space</AppText>
      {SAMPLE.recentNotes.map((n) => (
        <Pressable key={n.id} accessibilityRole="button" accessibilityLabel={`${n.title}, edited ${n.ago}. Sample note.`} onPress={() => goTo({ stack: 'Notes' })}>
          <Card>
            <AppText style={{ fontWeight: '600' }}>{n.title}</AppText>
            <AppText variant="caption" muted>{n.preview} · {n.ago}</AppText>
          </Card>
        </Pressable>
      ))}
    </Screen>
  );
}
