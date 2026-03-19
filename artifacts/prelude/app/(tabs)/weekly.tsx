import { Feather } from '@expo/vector-icons';
import React from 'react';
import {
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  useColorScheme,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { getColors, PreludeColors } from '@/constants/colors';
import { useApp } from '@/context/AppContext';

export default function WeeklyScreen() {
  const isDark = useColorScheme() === 'dark';
  const colors = getColors(isDark);
  const insets = useSafeAreaInsets();
  const { weeklyBrief } = useApp();

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
        {/* Main card */}
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

        {/* Themes */}
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

        {/* Worth bringing up */}
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

        {/* Regenerate */}
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
    paddingTop: 24,
    gap: 16,
  },
  mainCard: {
    borderRadius: 20,
    borderWidth: StyleSheet.hairlineWidth,
    padding: 24,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.08,
    shadowRadius: 16,
    elevation: 2,
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
  section: {
    marginTop: 4,
  },
  sectionLabel: {
    fontSize: 11,
    fontWeight: '500',
    letterSpacing: 1.2,
    fontFamily: 'Inter_500Medium',
    marginBottom: 12,
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
    fontSize: 11,
    fontWeight: '500',
    letterSpacing: 1.0,
    fontFamily: 'Inter_500Medium',
  },
  suggestionText: {
    fontSize: 16,
    lineHeight: 24,
    fontFamily: Platform.OS === 'ios' ? 'NewYorkSmall-Regular' : undefined,
  },
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
