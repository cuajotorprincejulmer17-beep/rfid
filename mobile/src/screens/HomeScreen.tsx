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
import { mix } from '../theme/color';
import { useTheme } from '../theme/ThemeProvider';
import { minTouch, radius, spacing } from '../theme/tokens';

type Icon = keyof typeof Ionicons.glyphMap;

function greeting(d = new Date()): string {
  const h = d.getHours();
  return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
}

function IconBtn({ icon, label, dest }: { icon: Icon; label: string; dest: Dest }) {
  const { theme } = useTheme();
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={label} onPress={() => goTo(dest)} style={{ width: minTouch, height: minTouch, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surface, borderWidth: 1, borderColor: mix(theme.border, theme.primary, 0.45) }}>
      <Ionicons name={icon} size={22} color={theme.accent} />
    </Pressable>
  );
}

function IconCircle({ icon, size = 52 }: { icon: Icon; size?: number }) {
  const { theme } = useTheme();
  return (
    <View style={{ width: size, height: size, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surfaceAlt, borderWidth: 1.5, borderColor: mix(theme.border, theme.primary, 0.7) }}>
      <Ionicons name={icon} size={size * 0.5} color={theme.accent} />
    </View>
  );
}

function SectionHeader({ icon, title, to }: { icon: Icon; title: string; to?: Dest }) {
  const { theme } = useTheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
      <Ionicons name={icon} size={20} color={theme.accent} />
      <AppText variant="heading" style={{ flex: 1 }}>{title}</AppText>
      {to ? <Pressable accessibilityRole="button" accessibilityLabel={`View all ${title}`} onPress={() => goTo(to)} style={{ minHeight: minTouch, justifyContent: 'center', paddingHorizontal: spacing.sm }}>
        <AppText variant="caption" color={theme.accent} style={{ fontWeight: '700' }}>View all</AppText>
      </Pressable> : null}
    </View>
  );
}

function Row({ title, meta, onPress, label, leading }: { title: string; meta: string; onPress: () => void; label: string; leading?: React.ReactNode }) {
  const { theme } = useTheme();
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={`${label}. Sample data.`} onPress={onPress} style={{ minHeight: minTouch, flexDirection: 'row', alignItems: 'center', gap: spacing.md, paddingVertical: spacing.sm }}>
      {leading}
      <View style={{ flex: 1 }}>
        <AppText style={{ fontWeight: '600' }} numberOfLines={1}>{title}</AppText>
        <AppText variant="caption" muted numberOfLines={1}>{meta}</AppText>
      </View>
      <Ionicons name="chevron-forward" size={18} color={theme.textMuted} />
    </Pressable>
  );
}

export function HomeScreen() {
  const { theme } = useTheme();
  const divider = <View style={{ height: 1, backgroundColor: theme.border }} />;
  return (
    <Screen>
      <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
          <View style={{ width: 34, height: 34, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surfaceAlt, borderWidth: 1, borderColor: theme.primary }}>
            <Ionicons name="pulse" size={21} color={theme.accent} />
          </View>
          <View>
            <AppText variant="heading" style={{ letterSpacing: 3.5, fontSize: 18 }}>PULSE</AppText>
            <AppText variant="caption" muted style={{ fontSize: 11 }}>STUDENT SPACE</AppText>
          </View>
        </View>
        <View style={{ flexDirection: 'row', gap: spacing.sm }}>
          <IconBtn icon="notifications-outline" label="Updates" dest={{ stack: 'Updates' }} />
          <IconBtn icon="settings-outline" label="Settings" dest={{ stack: 'Settings' }} />
        </View>
      </View>

      <View style={{ gap: 2 }}>
        <AppText variant="body" muted>{greeting()},</AppText>
        <AppText style={{ fontSize: 30, lineHeight: 36, fontWeight: '700' }}>Welcome back</AppText>
        <View style={{ width: 32, height: 3, borderRadius: radius.pill, backgroundColor: theme.primary, marginTop: spacing.xs }} />
      </View>
      <Badge label="Prototype preview · sample data, not your records" />

      <Pressable accessibilityRole="button" accessibilityLabel={`Today's attendance: ${SAMPLE.attendance.status}. Sample data.`} onPress={() => goTo({ stack: 'Attendance' })}>
        <Card featured style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.lg, paddingVertical: spacing.xl, borderColor: theme.primary, borderWidth: 1.5 }}>
          <IconCircle icon="card-outline" size={64} />
          <View style={{ flex: 1, gap: 2 }}>
            <AppText variant="caption" muted>Today's attendance</AppText>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
              <AppText style={{ fontSize: 22, lineHeight: 28, fontWeight: '700', flexShrink: 1 }}>{SAMPLE.attendance.status}</AppText>
              <Ionicons name="checkmark-circle" size={20} color={theme.success} />
            </View>
            <AppText variant="caption" muted>Last recorded: {SAMPLE.attendance.last}</AppText>
          </View>
          <Ionicons name="chevron-forward" size={20} color={theme.textMuted} />
        </Card>
      </Pressable>

      <Pressable accessibilityRole="button" accessibilityLabel={`Next class: ${SAMPLE.nextClass.title}. Sample data.`} onPress={() => goTo({ tab: 'Schedule' })}>
        <Card variant="panel" style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.lg }}>
          <IconCircle icon="calendar-outline" size={52} />
          <View style={{ flex: 1, gap: 2 }}>
            <AppText variant="caption" muted>Next class</AppText>
            <AppText variant="heading">{SAMPLE.nextClass.title}</AppText>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.xs, flexWrap: 'wrap' }}>
              <Ionicons name="time-outline" size={14} color={theme.textMuted} />
              <AppText variant="caption" muted>{SAMPLE.nextClass.time}</AppText>
              <Ionicons name="location-outline" size={14} color={theme.textMuted} style={{ marginLeft: spacing.sm }} />
              <AppText variant="caption" muted>{SAMPLE.nextClass.room}</AppText>
            </View>
          </View>
          <Ionicons name="chevron-forward" size={20} color={theme.textMuted} />
        </Card>
      </Pressable>

      <Card variant="panel" style={{ gap: spacing.xs }}>
        <SectionHeader icon="checkbox-outline" title="Upcoming tasks" to={{ tab: 'Tasks' }} />
        {SAMPLE.tasks.map((task, index) => <View key={task.id}>
          {index > 0 ? divider : null}
          <Row title={task.title} meta={task.due} label={task.title} onPress={() => goTo({ tab: 'Tasks' })} leading={<View style={{ width: 10, height: 10, borderRadius: radius.pill, backgroundColor: theme.primary }} />} />
        </View>)}
      </Card>

      <Card variant="panel" style={{ gap: spacing.xs }}>
        <SectionHeader icon="megaphone-outline" title="Latest updates" to={{ stack: 'Updates' }} />
        {SAMPLE.updates.map((update) => <Row key={update.id} title={update.title} meta={update.ago} label={update.title} onPress={() => goTo({ stack: 'Updates' })} />)}
      </Card>

      <View style={{ gap: spacing.sm }}>
        <SectionHeader icon="book-outline" title="Study Space" />
        <Card variant="panel" style={{ paddingVertical: spacing.sm }}>
          <Row title="Continue reviewing" meta={`${SAMPLE.review.title} · ${SAMPLE.review.meta}`} label="Continue reviewing" onPress={() => goTo({ stack: 'Review' })} leading={<IconCircle icon="layers-outline" size={38} />} />
          {divider}
          <Row title={SAMPLE.recentNote.title} meta={`${SAMPLE.recentNote.preview} · ${SAMPLE.recentNote.ago}`} label={`Recent note ${SAMPLE.recentNote.title}`} onPress={() => goTo({ stack: 'Notes' })} leading={<IconCircle icon="document-text-outline" size={38} />} />
          {divider}
          <Row title="Create a note" meta="Opens Notes" label="Create a note" onPress={() => goTo({ stack: 'Notes' })} leading={<IconCircle icon="add-outline" size={38} />} />
        </Card>
      </View>
    </Screen>
  );
}
