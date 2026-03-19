import { Feather } from '@expo/vector-icons';
import * as Clipboard from 'expo-clipboard';
import * as Haptics from 'expo-haptics';
import { router, useLocalSearchParams } from 'expo-router';
import React, { useEffect, useRef } from 'react';
import {
  Platform,
  ScrollView,
  Share,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  useColorScheme,
} from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withTiming,
  Easing,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import BriefCard from '@/components/BriefCard';
import { getColors, PreludeColors } from '@/constants/colors';
import type { CardType } from '@/context/AppContext';
import { useApp } from '@/context/AppContext';

// Animated card wrapper
function AnimatedCard({
  index,
  children,
}: {
  index: number;
  children: React.ReactNode;
}) {
  const opacity = useSharedValue(0);
  const translateY = useSharedValue(20);

  useEffect(() => {
    opacity.value = withDelay(
      300 + index * 200,
      withTiming(1, { duration: 500, easing: Easing.out(Easing.exp) })
    );
    translateY.value = withDelay(
      300 + index * 200,
      withTiming(0, { duration: 500, easing: Easing.out(Easing.exp) })
    );
  }, []);

  const style = useAnimatedStyle(() => ({
    opacity: opacity.value,
    transform: [{ translateY: translateY.value }],
  }));

  return <Animated.View style={style}>{children}</Animated.View>;
}

export default function BriefScreen() {
  const isDark = useColorScheme() === 'dark';
  const colors = getColors(isDark);
  const insets = useSafeAreaInsets();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { sessions } = useApp();

  const session = sessions.find((s) => s.id === id);
  const brief = session?.brief;

  const headerOpacity = useSharedValue(0);
  const headerStyle = useAnimatedStyle(() => ({ opacity: headerOpacity.value }));

  useEffect(() => {
    headerOpacity.value = withTiming(1, { duration: 600 });
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
  }, []);

  const webTopPad = Platform.OS === 'web' ? 67 : 0;
  const webBottomPad = Platform.OS === 'web' ? 34 : 0;

  if (!brief) {
    return (
      <View
        style={[
          styles.container,
          { backgroundColor: isDark ? PreludeColors.depth.dark : PreludeColors.depth.light },
        ]}
      >
        <View style={[styles.navBar, { paddingTop: insets.top + webTopPad + 12 }]}>
          <TouchableOpacity
            onPress={() => router.back()}
            hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
            accessibilityRole="button"
            accessibilityLabel="Go back"
          >
            <Feather name="x" size={20} color={colors.secondary} />
          </TouchableOpacity>
        </View>
        <View style={styles.emptyState}>
          <Text style={[styles.emptyText, { color: colors.secondary }]}>
            Brief not found
          </Text>
        </View>
      </View>
    );
  }

  // Build card list from brief
  const cards: { type: CardType; text: string; isUserWords?: boolean }[] = [
    { type: 'emotionalState', text: brief.emotionalState },
    ...brief.themes.slice(0, 1).map((t) => ({
      type: 'mainConcern' as CardType,
      text: t,
    })),
    ...brief.focusItems.slice(0, 1).map((f) => ({
      type: 'keyEmotion' as CardType,
      text: f,
    })),
    { type: 'whatToSay', text: brief.patientWords, isUserWords: true },
    ...brief.focusItems.slice(1, 2).map((f) => ({
      type: 'unresolvedThread' as CardType,
      text: f,
    })),
    ...brief.focusItems.slice(2).map((f) => ({
      type: 'therapyGoal' as CardType,
      text: f,
    })),
    ...(brief.patternNote
      ? [{ type: 'patternNote' as CardType, text: brief.patternNote }]
      : []),
  ];

  async function handleShare() {
    const text = cards
      .map((c) => `${c.type.toUpperCase()}\n${c.text}`)
      .join('\n\n');

    try {
      await Share.share({ message: text, title: 'My Session Brief — Prelude' });
    } catch {
      await Clipboard.setStringAsync(text);
    }
  }

  const sessionDate = session?.startedAt
    ? new Date(session.startedAt).toLocaleDateString('en-US', {
        weekday: 'long',
        month: 'long',
        day: 'numeric',
      })
    : '';

  return (
    <View
      style={[
        styles.container,
        { backgroundColor: isDark ? PreludeColors.depth.dark : PreludeColors.depth.light },
      ]}
    >
      {/* Nav bar */}
      <Animated.View
        style={[
          styles.navBar,
          headerStyle,
          { paddingTop: insets.top + webTopPad + 12 },
        ]}
      >
        <TouchableOpacity
          onPress={() => router.back()}
          hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
          accessibilityRole="button"
          accessibilityLabel="Go back"
        >
          <Feather name="x" size={20} color={colors.secondary} />
        </TouchableOpacity>
        <Text style={[styles.navTitle, { color: colors.tertiary }]}>
          Session Brief
        </Text>
        <View style={{ width: 20 }} />
      </Animated.View>

      <ScrollView
        style={styles.scroll}
        contentContainerStyle={[
          styles.scrollContent,
          {
            paddingBottom: insets.bottom + webBottomPad + 60,
          },
        ]}
        showsVerticalScrollIndicator={false}
      >
        {/* Date heading */}
        <Animated.View style={[styles.dateWrapper, headerStyle]}>
          <Text style={[styles.dateText, { color: colors.secondary }]}>
            {sessionDate}
          </Text>
        </Animated.View>

        {/* Cards */}
        {cards.map((card, i) => (
          <AnimatedCard key={i} index={i}>
            <BriefCard
              type={card.type}
              text={card.text}
              isUserWords={card.isUserWords}
            />
          </AnimatedCard>
        ))}

        {/* Share CTA */}
        <AnimatedCard index={cards.length}>
          <TouchableOpacity
            onPress={handleShare}
            activeOpacity={0.6}
            style={styles.shareCTA}
            accessibilityRole="button"
            accessibilityLabel="Take this to your session — copies brief"
          >
            <Text style={[styles.shareCTAText, { color: colors.secondary }]}>
              Take this to your session
            </Text>
          </TouchableOpacity>
        </AnimatedCard>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  navBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 24,
    paddingBottom: 16,
  },
  navTitle: {
    fontSize: 13,
    fontWeight: '500',
    letterSpacing: 0.8,
    fontFamily: 'Inter_500Medium',
  },
  scroll: {
    flex: 1,
  },
  scrollContent: {
    paddingHorizontal: 20,
    paddingTop: 8,
  },
  dateWrapper: {
    marginBottom: 20,
    paddingHorizontal: 2,
  },
  dateText: {
    fontSize: 14,
    fontFamily: 'Inter_400Regular',
    fontWeight: '400',
  },
  shareCTA: {
    alignItems: 'center',
    paddingVertical: 24,
  },
  shareCTAText: {
    fontSize: 15,
    fontFamily: Platform.OS === 'ios' ? 'NewYorkSmall-Regular' : undefined,
    letterSpacing: 0.3,
  },
  emptyState: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyText: {
    fontSize: 16,
    fontFamily: 'Inter_400Regular',
  },
});
