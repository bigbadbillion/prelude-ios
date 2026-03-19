import React, { useEffect, useRef } from 'react';
import {
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  useColorScheme,
  Platform,
} from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withTiming,
  withRepeat,
  withSequence,
  Easing,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { getColors, PreludeColors } from '@/constants/colors';
import { useApp } from '@/context/AppContext';

function getGreeting(): string {
  const h = new Date().getHours();
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

function getTimeOfDayGradient(isDark: boolean): string[] {
  const h = new Date().getHours();
  if (isDark) {
    if (h < 10) return ['#0F0D0A', '#1A1410', '#0F0D0A']; // warm honey morning
    if (h < 17) return ['#0F0D0A', '#131008', '#0F0D0A']; // neutral midday
    return ['#0F0D0A', '#160F08', '#0F0D0A']; // amber-brown evening
  } else {
    if (h < 10) return ['#FAF7F2', '#F5EFE4', '#FAF7F2'];
    if (h < 17) return ['#FAF7F2', '#F2EDE5', '#FAF7F2'];
    return ['#FAF7F2', '#EFE8DA', '#FAF7F2'];
  }
}

function formatLastSession(iso?: string): string {
  if (!iso) return '';
  const d = new Date(iso);
  const now = new Date();
  const daysDiff = Math.floor((now.getTime() - d.getTime()) / (1000 * 60 * 60 * 24));
  if (daysDiff === 0) return 'Today';
  if (daysDiff === 1) return 'Yesterday';
  return `${daysDiff} days ago`;
}

export default function HomeScreen() {
  const isDark = useColorScheme() === 'dark';
  const colors = getColors(isDark);
  const insets = useSafeAreaInsets();
  const { sessions, userName, hasSeenDisclaimer, setHasSeenDisclaimer } = useApp();

  const ambientOpacity = useSharedValue(0);
  const ctaOpacity = useSharedValue(0);
  const ctaScale = useSharedValue(0.96);
  const subtleBreath = useSharedValue(1);

  useEffect(() => {
    // Entrance
    ambientOpacity.value = withTiming(1, { duration: 1200, easing: Easing.out(Easing.exp) });
    ctaOpacity.value = withTiming(1, { duration: 1000, easing: Easing.out(Easing.exp) });

    // Subtle breathing on the CTA
    subtleBreath.value = withRepeat(
      withSequence(
        withTiming(1.02, { duration: 2800, easing: Easing.inOut(Easing.sin) }),
        withTiming(0.99, { duration: 2800, easing: Easing.inOut(Easing.sin) })
      ),
      -1,
      false
    );
  }, []);

  const ambientStyle = useAnimatedStyle(() => ({ opacity: ambientOpacity.value }));
  const ctaStyle = useAnimatedStyle(() => ({
    opacity: ctaOpacity.value,
    transform: [{ scale: ctaScale.value * subtleBreath.value }],
  }));

  const lastSession = sessions[0];
  const dayOfWeek = new Date().toLocaleDateString('en-US', { weekday: 'long' });

  function handleBegin() {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (!hasSeenDisclaimer) {
      router.push('/onboarding');
    } else {
      router.push('/session');
    }
  }

  const webTopPad = Platform.OS === 'web' ? 67 : 0;
  const webBottomPad = Platform.OS === 'web' ? 34 : 0;

  return (
    <View
      style={[
        styles.container,
        { backgroundColor: isDark ? PreludeColors.depth.dark : PreludeColors.depth.light },
      ]}
    >
      {/* Ambient background gradient — simulated with radial-ish layered views */}
      <Animated.View style={[styles.ambientLayer, ambientStyle]}>
        <View
          style={[
            styles.ambientCenter,
            {
              backgroundColor: isDark
                ? 'rgba(200,135,58,0.04)'
                : 'rgba(200,135,58,0.06)',
            },
          ]}
        />
      </Animated.View>

      <View
        style={[
          styles.content,
          {
            paddingTop: insets.top + webTopPad + 24,
            paddingBottom: insets.bottom + webBottomPad + 100,
          },
        ]}
      >
        {/* Greeting area — at roughly 40% from top */}
        <Animated.View style={[styles.greetingWrapper, ambientStyle]}>
          <Text style={[styles.greeting, { color: colors.primary }]}>
            {getGreeting()}{userName ? `, ${userName.split(' ')[0]}` : ''}.
          </Text>

          <Text style={[styles.dateLine, { color: colors.secondary }]}>
            {dayOfWeek}
            {lastSession && lastSession.brief?.themes?.[0]
              ? ` · ${lastSession.brief.themes[0]}`
              : ' · Ready when you are'}
          </Text>
        </Animated.View>

        {/* Begin CTA */}
        <Animated.View style={[styles.ctaWrapper, ctaStyle]}>
          <TouchableOpacity
            onPress={handleBegin}
            activeOpacity={0.8}
            accessibilityLabel="Begin Reflection"
            accessibilityRole="button"
            hitSlop={{ top: 24, bottom: 24, left: 48, right: 48 }}
          >
            <Text style={[styles.beginCTA, { color: colors.amber }]}>
              Begin Reflection
            </Text>
          </TouchableOpacity>
        </Animated.View>

        {/* Last session summary */}
        {lastSession && (
          <Animated.View style={[styles.lastSession, ambientStyle]}>
            <Text style={[styles.lastSessionLabel, { color: colors.tertiary }]}>
              {formatLastSession(lastSession.completedAt)}
            </Text>
            <Text
              style={[styles.lastSessionTheme, { color: colors.secondary }]}
              numberOfLines={2}
            >
              {lastSession.brief?.themes?.join(' · ') ?? 'Reflection session'}
            </Text>
          </Animated.View>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  ambientLayer: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
  },
  ambientCenter: {
    width: '120%',
    aspectRatio: 1,
    borderRadius: 9999,
  },
  content: {
    flex: 1,
    paddingHorizontal: 32,
    justifyContent: 'center',
  },
  greetingWrapper: {
    marginBottom: 52,
  },
  greeting: {
    fontSize: 34,
    lineHeight: 42,
    fontWeight: '400',
    // Uses system serif on both platforms
    fontFamily: Platform.OS === 'ios' ? 'NewYorkSmall-Regular' : undefined,
    letterSpacing: 0.2,
    marginBottom: 10,
  },
  dateLine: {
    fontSize: 15,
    fontWeight: '400',
    fontFamily: 'Inter_400Regular',
    letterSpacing: 0.1,
  },
  ctaWrapper: {
    marginBottom: 44,
  },
  beginCTA: {
    fontSize: 22,
    fontWeight: '600',
    fontFamily: Platform.OS === 'ios' ? 'NewYorkSmall-Semibold' : undefined,
    letterSpacing: 0.3,
  },
  lastSession: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: 'rgba(158,148,133,0.2)',
    paddingTop: 20,
  },
  lastSessionLabel: {
    fontSize: 11,
    fontWeight: '500',
    letterSpacing: 1.0,
    marginBottom: 6,
    textTransform: 'uppercase',
    fontFamily: 'Inter_500Medium',
  },
  lastSessionTheme: {
    fontSize: 15,
    lineHeight: 22,
    fontFamily: 'Inter_400Regular',
  },
});
