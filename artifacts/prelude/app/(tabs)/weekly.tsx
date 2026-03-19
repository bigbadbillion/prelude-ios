import { Feather } from '@expo/vector-icons';
import React, { useMemo } from 'react';
import {
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  useColorScheme,
} from 'react-native';
import Svg, {
  Circle,
  Defs,
  LinearGradient,
  Path,
  Stop,
  Text as SvgText,
} from 'react-native-svg';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { getColors, PreludeColors } from '@/constants/colors';
import { useApp, emotionColors, type EmotionLabel, type Session } from '@/context/AppContext';

// ── Emotion weight: higher = lighter/more positive ──────────────────────────
const emotionWeight: Record<EmotionLabel, number> = {
  hopeful: 0.88,
  neutral: 0.52,
  confused: 0.38,
  frustrated: 0.28,
  sad: 0.22,
  anxious: 0.18,
  grieving: 0.12,
  overwhelmed: 0.10,
  angry: 0.10,
};

// ── Catmull-Rom → cubic bezier conversion ───────────────────────────────────
function catmullRomToBezier(
  pts: { x: number; y: number }[]
): string {
  if (pts.length === 0) return '';
  if (pts.length === 1) return `M ${pts[0].x} ${pts[0].y}`;

  let d = `M ${pts[0].x.toFixed(2)} ${pts[0].y.toFixed(2)}`;

  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[Math.max(i - 1, 0)];
    const p1 = pts[i];
    const p2 = pts[i + 1];
    const p3 = pts[Math.min(i + 2, pts.length - 1)];

    const cp1x = p1.x + (p2.x - p0.x) / 6;
    const cp1y = p1.y + (p2.y - p0.y) / 6;
    const cp2x = p2.x - (p3.x - p1.x) / 6;
    const cp2y = p2.y - (p3.y - p1.y) / 6;

    d += ` C ${cp1x.toFixed(2)} ${cp1y.toFixed(2)}, ${cp2x.toFixed(2)} ${cp2y.toFixed(2)}, ${p2.x.toFixed(2)} ${p2.y.toFixed(2)}`;
  }

  return d;
}

function formatChartDate(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

// ── Emotional Arc SVG Chart ──────────────────────────────────────────────────
function EmotionalArcChart({
  sessions,
  isDark,
}: {
  sessions: Session[];
  isDark: boolean;
}) {
  const colors = getColors(isDark);

  // Only sessions with a dominant emotion, oldest→newest
  const pts_sessions = useMemo(() => {
    return [...sessions]
      .filter((s) => s.dominantEmotion && s.completedAt)
      .sort((a, b) => new Date(a.completedAt!).getTime() - new Date(b.completedAt!).getTime())
      .slice(-6); // show last 6 sessions max
  }, [sessions]);

  const W = 300;
  const H = 100;
  const padX = 20;
  const padY = 12;
  const chartW = W - padX * 2;
  const chartH = H - padY * 2;

  const points = useMemo(() => {
    if (pts_sessions.length === 0) return [];
    return pts_sessions.map((s, i) => {
      const weight = emotionWeight[s.dominantEmotion!] ?? 0.5;
      const x = padX + (pts_sessions.length === 1 ? chartW / 2 : (i / (pts_sessions.length - 1)) * chartW);
      const y = padY + chartH - weight * chartH;
      return { x, y, session: s };
    });
  }, [pts_sessions]);

  if (points.length < 2) return null;

  const linePath = catmullRomToBezier(points.map((p) => ({ x: p.x, y: p.y })));

  // Filled area path: line path + closing along bottom
  const first = points[0];
  const last = points[points.length - 1];
  const areaPath =
    linePath +
    ` L ${last.x.toFixed(2)} ${(H - padY + 4).toFixed(2)}` +
    ` L ${first.x.toFixed(2)} ${(H - padY + 4).toFixed(2)} Z`;

  const dominantColor = pts_sessions[pts_sessions.length - 1]?.dominantEmotion
    ? emotionColors[pts_sessions[pts_sessions.length - 1].dominantEmotion!]
    : PreludeColors.calm;

  return (
    <View>
      <Svg width="100%" height={H + 28} viewBox={`0 0 ${W} ${H + 28}`}>
        <Defs>
          <LinearGradient id="arcFill" x1="0" y1="0" x2="0" y2="1">
            <Stop offset="0%" stopColor={dominantColor} stopOpacity={isDark ? 0.18 : 0.14} />
            <Stop offset="100%" stopColor={dominantColor} stopOpacity={0.0} />
          </LinearGradient>
        </Defs>

        {/* Filled area */}
        <Path d={areaPath} fill="url(#arcFill)" />

        {/* Curve line */}
        <Path
          d={linePath}
          fill="none"
          stroke={dominantColor}
          strokeWidth={1.5}
          strokeLinecap="round"
          strokeLinejoin="round"
          opacity={isDark ? 0.7 : 0.65}
        />

        {/* Data points + labels */}
        {points.map((pt, i) => {
          const emotion = pts_sessions[i].dominantEmotion!;
          const color = emotionColors[emotion];
          const label = formatChartDate(pts_sessions[i].completedAt!);
          return (
            <React.Fragment key={pts_sessions[i].id}>
              {/* Outer ring */}
              <Circle
                cx={pt.x}
                cy={pt.y}
                r={6}
                fill={isDark ? PreludeColors.surface.dark : PreludeColors.surface.light}
                stroke={color}
                strokeWidth={1.5}
                opacity={0.9}
              />
              {/* Inner dot */}
              <Circle cx={pt.x} cy={pt.y} r={2.5} fill={color} opacity={0.95} />
              {/* Date label */}
              <SvgText
                x={pt.x}
                y={H + 16}
                textAnchor="middle"
                fontSize={8}
                fontFamily="Inter_400Regular"
                fill={isDark ? PreludeColors.secondary.dark : PreludeColors.secondary.light}
                opacity={0.7}
              >
                {label}
              </SvgText>
              {/* Emotion label above dot */}
              <SvgText
                x={pt.x}
                y={pt.y - 10}
                textAnchor="middle"
                fontSize={7}
                fontFamily="Inter_400Regular"
                fill={color}
                opacity={0.75}
              >
                {emotion}
              </SvgText>
            </React.Fragment>
          );
        })}
      </Svg>
    </View>
  );
}

// ── Screen ───────────────────────────────────────────────────────────────────
export default function WeeklyScreen() {
  const isDark = useColorScheme() === 'dark';
  const colors = getColors(isDark);
  const insets = useSafeAreaInsets();
  const { weeklyBrief, sessions } = useApp();

  const webTopPad = Platform.OS === 'web' ? 67 : 0;
  const webBottomPad = Platform.OS === 'web' ? 34 : 0;

  if (!weeklyBrief) {
    return (
      <View
        style={[
          styles.container,
          { backgroundColor: isDark ? PreludeColors.depth.dark : PreludeColors.depth.light },
        ]}
      >
        <View
          style={[
            styles.header,
            {
              paddingTop: insets.top + webTopPad + 16,
              borderBottomColor: colors.border,
            },
          ]}
        >
          <Text style={[styles.title, { color: colors.primary }]}>This Week</Text>
        </View>
        <View style={styles.emptyState}>
          <Text style={[styles.emptyTitle, { color: colors.secondary }]}>
            Your weekly brief will appear here
          </Text>
          <Text style={[styles.emptyBody, { color: colors.tertiary }]}>
            Complete your first session to generate a weekly reflection.
          </Text>
        </View>
      </View>
    );
  }

  const weekStart = new Date(weeklyBrief.weekStart);
  const weekLabel = weekStart.toLocaleDateString('en-US', {
    month: 'long',
    day: 'numeric',
  });

  const paragraphs = weeklyBrief.summary.split('\n\n').filter(Boolean);

  return (
    <View
      style={[
        styles.container,
        { backgroundColor: isDark ? PreludeColors.depth.dark : PreludeColors.depth.light },
      ]}
    >
      {/* Header */}
      <View
        style={[
          styles.header,
          {
            paddingTop: insets.top + webTopPad + 16,
            borderBottomColor: colors.border,
          },
        ]}
      >
        <Text style={[styles.title, { color: colors.primary }]}>This Week</Text>
        <Text style={[styles.subtitle, { color: colors.secondary }]}>
          Week of {weekLabel}
        </Text>
      </View>

      <ScrollView
        style={styles.scroll}
        contentContainerStyle={[
          styles.scrollContent,
          { paddingBottom: insets.bottom + webBottomPad + 100 },
        ]}
        showsVerticalScrollIndicator={false}
        contentInsetAdjustmentBehavior="automatic"
      >
        {/* ── Emotional Arc Chart ── */}
        <View
          style={[
            styles.chartCard,
            {
              backgroundColor: isDark
                ? 'rgba(255,255,255,0.025)'
                : 'rgba(26,22,18,0.03)',
              borderColor: colors.border,
            },
          ]}
        >
          <View style={styles.chartHeader}>
            <Text style={[styles.sectionLabel, { color: colors.tertiary }]}>
              EMOTIONAL ARC
            </Text>
            <Text style={[styles.chartCaption, { color: colors.tertiary }]}>
              across sessions
            </Text>
          </View>

          <EmotionalArcChart sessions={sessions} isDark={isDark} />

          {/* Y-axis labels */}
          <View style={styles.yAxisRow}>
            <Text style={[styles.yAxisLabel, { color: colors.tertiary }]}>heavier</Text>
            <Text style={[styles.yAxisLabel, { color: colors.tertiary }]}>lighter</Text>
          </View>
        </View>

        {/* ── Main narrative card ── */}
        <View
          style={[
            styles.mainCard,
            {
              backgroundColor: isDark ? colors.surface : colors.surface,
              borderColor: colors.border,
            },
          ]}
        >
          <Text style={[styles.cardHeading, { color: colors.primary }]}>
            This week.
          </Text>

          {paragraphs.map((p, i) => (
            <Text
              key={i}
              style={[
                styles.paragraph,
                { color: i === 0 ? colors.primary : colors.secondary },
                i > 0 && styles.paragraphSpacing,
              ]}
            >
              {p}
            </Text>
          ))}
        </View>

        {/* ── Recurring themes ── */}
        {weeklyBrief.themes.length > 0 && (
          <View style={styles.section}>
            <Text style={[styles.sectionLabel, { color: colors.tertiary }]}>
              RECURRING THEMES
            </Text>
            <View style={styles.tagRow}>
              {weeklyBrief.themes.map((theme, i) => (
                <View
                  key={i}
                  style={[
                    styles.tag,
                    {
                      backgroundColor: isDark
                        ? 'rgba(200,135,58,0.12)'
                        : 'rgba(200,135,58,0.10)',
                      borderColor: 'rgba(200,135,58,0.25)',
                    },
                  ]}
                >
                  <Text style={[styles.tagText, { color: colors.amber }]}>
                    {theme}
                  </Text>
                </View>
              ))}
            </View>
          </View>
        )}

        {/* ── Worth bringing up ── */}
        {weeklyBrief.suggestions.length > 0 && (
          <View
            style={[
              styles.suggestionCard,
              {
                backgroundColor: isDark
                  ? 'rgba(200,135,58,0.08)'
                  : 'rgba(200,135,58,0.07)',
                borderColor: 'rgba(200,135,58,0.2)',
              },
            ]}
          >
            <View style={styles.suggestionHeader}>
              <Feather name="arrow-up-right" size={13} color={colors.amber} />
              <Text style={[styles.suggestionLabel, { color: colors.amber }]}>
                Worth bringing up
              </Text>
            </View>
            <Text style={[styles.suggestionText, { color: colors.primary }]}>
              {weeklyBrief.suggestions[0]}
            </Text>
          </View>
        )}

        {/* ── Regenerate ── */}
        <TouchableOpacity
          style={styles.regenerateBtn}
          activeOpacity={0.6}
          accessibilityLabel="Regenerate weekly brief"
          accessibilityRole="button"
        >
          <Feather name="refresh-cw" size={13} color={colors.tertiary} />
          <Text style={[styles.regenerateText, { color: colors.tertiary }]}>
            Regenerate
          </Text>
        </TouchableOpacity>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    paddingHorizontal: 24,
    paddingBottom: 20,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  title: {
    fontSize: 30,
    fontWeight: '400',
    fontFamily: Platform.OS === 'ios' ? 'NewYorkSmall-Regular' : undefined,
    marginBottom: 4,
    letterSpacing: 0.2,
  },
  subtitle: {
    fontSize: 14,
    fontFamily: 'Inter_400Regular',
  },
  scroll: {
    flex: 1,
  },
  scrollContent: {
    paddingHorizontal: 20,
    paddingTop: 20,
    gap: 14,
  },

  // Chart
  chartCard: {
    borderRadius: 16,
    borderWidth: StyleSheet.hairlineWidth,
    paddingTop: 16,
    paddingHorizontal: 4,
    paddingBottom: 10,
    overflow: 'hidden',
  },
  chartHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 14,
    marginBottom: 8,
  },
  chartCaption: {
    fontSize: 10,
    fontFamily: 'Inter_400Regular',
    letterSpacing: 0.3,
  },
  yAxisRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingHorizontal: 24,
    marginTop: 2,
  },
  yAxisLabel: {
    fontSize: 8,
    fontFamily: 'Inter_400Regular',
    letterSpacing: 0.4,
    opacity: 0.6,
  },

  // Main card
  mainCard: {
    borderRadius: 20,
    borderWidth: StyleSheet.hairlineWidth,
    padding: 24,
  },
  cardHeading: {
    fontSize: 26,
    fontWeight: '600',
    fontFamily: Platform.OS === 'ios' ? 'NewYorkSmall-Semibold' : undefined,
    marginBottom: 20,
    letterSpacing: 0.2,
  },
  paragraph: {
    fontSize: 16,
    lineHeight: 26,
    fontFamily: Platform.OS === 'ios' ? 'NewYorkSmall-Regular' : undefined,
  },
  paragraphSpacing: {
    marginTop: 16,
  },

  // Themes
  section: {
    marginTop: 4,
  },
  sectionLabel: {
    fontSize: 10,
    fontWeight: '600',
    letterSpacing: 1.3,
    fontFamily: 'Inter_600SemiBold',
    marginBottom: 12,
    paddingHorizontal: 2,
  },
  tagRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  tag: {
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: 100,
    borderWidth: 1,
  },
  tagText: {
    fontSize: 13,
    fontWeight: '500',
    fontFamily: 'Inter_500Medium',
  },

  // Worth bringing up
  suggestionCard: {
    borderRadius: 16,
    borderWidth: 1,
    padding: 18,
  },
  suggestionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginBottom: 10,
  },
  suggestionLabel: {
    fontSize: 10,
    fontWeight: '600',
    letterSpacing: 1.1,
    fontFamily: 'Inter_600SemiBold',
  },
  suggestionText: {
    fontSize: 16,
    lineHeight: 24,
    fontFamily: Platform.OS === 'ios' ? 'NewYorkSmall-Regular' : undefined,
  },

  // Regenerate
  regenerateBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    paddingVertical: 16,
  },
  regenerateText: {
    fontSize: 13,
    fontFamily: 'Inter_400Regular',
  },

  // Empty state
  emptyState: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 40,
    gap: 12,
  },
  emptyTitle: {
    fontSize: 18,
    fontWeight: '500',
    textAlign: 'center',
    fontFamily: 'Inter_500Medium',
  },
  emptyBody: {
    fontSize: 15,
    textAlign: 'center',
    lineHeight: 22,
    fontFamily: 'Inter_400Regular',
  },
});
