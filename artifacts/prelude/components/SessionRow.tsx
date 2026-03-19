import React from 'react';
import { StyleSheet, Text, TouchableOpacity, View, useColorScheme } from 'react-native';
import type { Session } from '@/context/AppContext';
import { emotionColors } from '@/context/AppContext';
import { getColors } from '@/constants/colors';
import { TypeScale } from '@/constants/typography';

interface SessionRowProps {
  session: Session;
  onPress: () => void;
}

function formatDate(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'short',
    day: 'numeric',
  });
}

function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60);
  return `${m} min`;
}

export default function SessionRow({ session, onPress }: SessionRowProps) {
  const isDark = useColorScheme() === 'dark';
  const colors = getColors(isDark);

  const dotColor = session.dominantEmotion
    ? emotionColors[session.dominantEmotion]
    : colors.tertiary;

  const firstTheme = session.brief?.themes?.[0] ?? 'Reflection';

  return (
    <TouchableOpacity
      onPress={onPress}
      activeOpacity={0.7}
      style={[
        styles.container,
        {
          borderBottomColor: colors.border,
        },
      ]}
      accessibilityRole="button"
      accessibilityLabel={`Session from ${formatDate(session.startedAt)}`}
    >
      {/* Timeline dot + line */}
      <View style={styles.timelineCol}>
        <View style={[styles.dot, { backgroundColor: dotColor }]} />
        <View style={[styles.line, { backgroundColor: colors.border }]} />
      </View>

      {/* Content */}
      <View style={styles.content}>
        <View style={styles.topRow}>
          <Text style={[styles.date, { color: colors.primary }]}>
            {formatDate(session.startedAt)}
          </Text>
          <Text style={[styles.duration, { color: colors.tertiary }]}>
            {formatDuration(session.durationSeconds)}
          </Text>
        </View>
        <Text
          style={[styles.theme, { color: colors.secondary }]}
          numberOfLines={1}
        >
          {firstTheme}
        </Text>
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    paddingRight: 20,
    paddingVertical: 18,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  timelineCol: {
    width: 44,
    alignItems: 'center',
    paddingTop: 4,
  },
  dot: {
    width: 10,
    height: 10,
    borderRadius: 5,
  },
  line: {
    width: 1,
    flex: 1,
    marginTop: 6,
  },
  content: {
    flex: 1,
    paddingBottom: 12,
  },
  topRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 5,
  },
  date: {
    fontSize: 15,
    fontWeight: '500',
  },
  duration: {
    ...TypeScale.caption,
  },
  theme: {
    fontSize: 15,
    lineHeight: 22,
  },
});
