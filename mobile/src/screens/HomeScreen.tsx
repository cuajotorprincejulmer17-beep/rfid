import { Ionicons } from '@expo/vector-icons';
import React from 'react';
import { Pressable, View } from 'react-native';
import { AppText } from '../components/AppText';
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

function IconBtn({ icon, label, dest }: { icon: Icon; label: string; dest: Dest }) {
  const { theme } = useTheme();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={() => goTo(dest)}
      style={({ pressed }) => ({
        width: minTouch, height: minTouch, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center',
        backgroundColor: pressed ? theme.surfaceAlt : theme.surface, borderWidth: 1, borderColor: theme.border,
      })}
    >
      <Ionicons name={icon} size={21} color={theme.accent} />
    </Pressable>
  );
}

function SectionLabel({ children, action, onPress }: { children: string; action?: string; onPress?: () => void }) {
  const { theme } = useTheme();
  return (
    <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
      <AppText variant="heading" style={{ fontSize: 18 }}>{children}</AppText>
      {action ? <Pressable accessibilityRole="button" accessibilityLabel={action} onPress={onPress} hitSlop={8}>
        <AppText variant="caption" color={theme.accent} style={{ fontWeight: '700' }}>{action}</AppText>
      </Pressable> : null}
    </View>
  );
}

export function HomeScreen() {
  const { theme } = useTheme();
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

      <View style={{ gap: spacing.xs }}>
        <AppText variant="body" muted>{greeting()}</AppText>
        <AppText variant="title" style={{ fontSize: 28 }}>Your day, in rhythm.</AppText>
      </View>

      <Pressable accessibilityRole="button" accessibilityLabel={`Attendance ${SAMPLE.attendancePercent} percent. Sample data.`} onPress={() => goTo({ stack: 'Attendance' })}>
        <Card variant="feature" style={{ overflow: 'hidden', gap: spacing.lg, borderColor: theme.primary, borderWidth: 1.5, backgroundColor: theme.isDark ? '#151536' : theme.surface }}>
          <View style={{ position: 'absolute', width: 150, height: 150, borderRadius: radius.pill, right: -42, top: -54, backgroundColor: theme.primary, opacity: theme.isDark ? 0.18 : 0.1 }} />
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <View style={{ gap: spacing.xs }}>
              <View style={{ alignSelf: 'flex-start', paddingHorizontal: spacing.sm, paddingVertical: 5, borderRadius: radius.pill, backgroundColor: theme.surfaceAlt }}>
                <AppText variant="caption" color={theme.accent} style={{ fontSize: 10, fontWeight: '800', letterSpacing: 1 }}>ATTENDANCE</AppText>
              </View>
              <AppText variant="body" muted>This term - sample data</AppText>
            </View>
            <View style={{ width: 48, height: 48, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surfaceAlt, borderWidth: 1, borderColor: theme.primary }}>
              <Ionicons name="card-outline" size={25} color={theme.accent} />
            </View>
          </View>
          <View style={{ flexDirection: 'row', alignItems: 'flex-end', gap: spacing.md }}>
            <AppText style={{ color: theme.text, fontSize: 44, lineHeight: 48, fontWeight: '800', letterSpacing: -1 }}>{SAMPLE.attendancePercent}%</AppText>
            <AppText variant="caption" muted style={{ paddingBottom: 7 }}>on track</AppText>
          </View>
          <View style={{ height: 6, borderRadius: radius.pill, backgroundColor: theme.surfaceAlt, overflow: 'hidden' }}>
            <View style={{ width: `${SAMPLE.attendancePercent}%`, height: '100%', borderRadius: radius.pill, backgroundColor: theme.primary }} />
          </View>
        </Card>
      </Pressable>

      <SectionLabel>Today</SectionLabel>
      <View style={{ flexDirection: 'row', gap: spacing.md }}>
        <Pressable accessibilityRole="button" accessibilityLabel={`Next class ${SAMPLE.nextClass.title} at ${SAMPLE.nextClass.time}. Sample data.`} onPress={() => goTo({ tab: 'Schedule' })} style={{ flex: 1.45 }}>
          <Card variant="panel" style={{ minHeight: 142, justifyContent: 'space-between', gap: spacing.md, borderColor: theme.border }}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
              <Ionicons name="calendar-outline" size={22} color={theme.accent} />
              <AppText variant="caption" color={theme.accent} style={{ fontWeight: '700' }}>NEXT</AppText>
            </View>
            <View style={{ gap: 2 }}>
              <AppText variant="heading" style={{ fontSize: 17 }}>{SAMPLE.nextClass.title}</AppText>
              <AppText variant="caption" muted>{SAMPLE.nextClass.time}</AppText>
            </View>
          </Card>
        </Pressable>
        <View style={{ flex: 1, gap: spacing.md }}>
          <Pressable accessibilityRole="button" accessibilityLabel={`Tasks ${SAMPLE.tasksPending} pending. Sample data.`} onPress={() => goTo({ tab: 'Tasks' })}>
            <Card variant="row" style={{ minHeight: 65, paddingVertical: spacing.sm, flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
              <View style={{ width: 32, height: 32, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surfaceAlt }}>
                <Ionicons name="checkbox-outline" size={18} color={theme.accent} />
              </View>
              <View style={{ flex: 1, gap: 1 }}>
                <AppText variant="heading" style={{ fontSize: 15 }}>{SAMPLE.tasksPending} tasks</AppText>
                <AppText variant="caption" muted style={{ fontSize: 12 }}>pending</AppText>
              </View>
            </Card>
          </Pressable>
          <Pressable accessibilityRole="button" accessibilityLabel={`Updates ${SAMPLE.announcementsNew} new. Sample data.`} onPress={() => goTo({ stack: 'Updates' })}>
            <Card variant="row" style={{ minHeight: 65, paddingVertical: spacing.sm, flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
              <View style={{ width: 32, height: 32, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surfaceAlt }}>
                <Ionicons name="megaphone-outline" size={18} color={theme.accent} />
              </View>
              <View style={{ flex: 1, gap: 1 }}>
                <AppText variant="heading" style={{ fontSize: 15 }}>{SAMPLE.announcementsNew} new</AppText>
                <AppText variant="caption" muted style={{ fontSize: 12 }}>updates</AppText>
              </View>
            </Card>
          </Pressable>
        </View>
      </View>

      <SectionLabel action="View notes" onPress={() => goTo({ stack: 'Notes' })}>Study Space</SectionLabel>
      <View style={{ gap: spacing.sm }}>
        {SAMPLE.recentNotes.map((n, index) => (
          <Pressable key={n.id} accessibilityRole="button" accessibilityLabel={`${n.title}, edited ${n.ago}. Sample note.`} onPress={() => goTo(index === 0 ? { stack: 'Notes' } : { stack: 'Review' })}>
            <Card variant="row" style={{ paddingVertical: spacing.md, flexDirection: 'row', alignItems: 'center', gap: spacing.md }}>
              <View style={{ width: 38, height: 38, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surfaceAlt, borderWidth: 1, borderColor: theme.border }}>
                <Ionicons name={index === 0 ? 'document-text-outline' : 'layers-outline'} size={20} color={theme.accent} />
              </View>
              <View style={{ flex: 1, gap: 2 }}>
                <AppText style={{ fontWeight: '700' }}>{n.title}</AppText>
                <AppText variant="caption" muted numberOfLines={1}>{n.preview}</AppText>
              </View>
              <AppText variant="caption" muted>{n.ago}</AppText>
              <Ionicons name="chevron-forward" size={16} color={theme.textMuted} />
            </Card>
          </Pressable>
        ))}
      </View>
    </Screen>
  );
}
