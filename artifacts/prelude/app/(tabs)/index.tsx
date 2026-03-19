import React, { useEffect } from 'react';
import {
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  useColorScheme,
  Platform,
  Pressable,
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

function formatLastSession(iso?: string): string {
  if (!iso) return '';
  const d = new Date(iso);
  const now = new Date();
  const daysDiff = Math.floor((now.getTime() - d.getTime()) / (1000 * 60 * 60 * 24));
  if (daysDiff === 0) return 'Today';
  if (daysDiff === 1) return 'Yesterday';
  return `${daysDiff} days ago`;
}

function AmbientBlob({
  size,
  x,
  y,
  opacity,
  rotateDuration,
  rotateOffset,
  breathDuration,
  color,
  radiusMultiplier,
}: {
  size: number;
  x: number;
  y: number;
  opacity: number;
  rotateDuration: number;
  rotateOffset: number;
  breathDuration: number;
  color: string;
  radiusMultiplier: number;
}) {
  const rotate = useSharedValue(rotateOffset);
  const scale = useSharedValue(1);

  useEffect(() => {
    rotate.value = withRepeat(
      withTiming(rotateOffset + 360, { duration: rotateDuration, easing: Easing.linear }),
      -1,
      false
    );
    scale.value = withRepeat(
      withSequence(
        withTiming(1.06, { duration: breathDuration, easing: Easing.inOut(Easing.sin) }),
        withTiming(0.96, { duration: breathDuration, easing: Easing.inOut(Easing.sin) })
      ),
      -1,
      false
    );
  }, []);

  const style = useAnimatedStyle(() => ({
    transform: [{ rotate: `${rotate.value}deg` }, { scale: scale.value }],
  }));

  return (
    <Animated.View
      style={[
        style,
        {
          position: 'absolute',
          left: x - size / 2,
          top: y - size / 2,
          width: size,
          height: size * 0.9,
          borderRadius: size * radiusMultiplier,
          backgroundColor: color,
          opacity,
        },
      ]}
    />
  );
}

export default function HomeScreen() {
  const isDark = useColorScheme() === 'dark';
  const colors = getColors(isDark);
  const insets = useSafeAreaInsets();
  const { sessions, userName, hasSeenDisclaimer } = useApp();

  const headerOpacity = useSharedValue(0);
  const contentOpacity = useSharedValue(0);
  const contentY = useSharedValue(12);
  const buttonScale = useSharedValue(0.97);

  useEffect(() => {
    headerOpacity.value = withTiming(1, { duration: 900, easing: Easing.out(Easing.exp) });
    contentOpacity.value = withTiming(1, { duration: 1100, easing: Easing.out(Easing.exp) });
    contentY.value = withTiming(0, { duration: 1000, easing: Easing.out(Easing.exp) });
    buttonScale.value = withRepeat(
      withSequence(
        withTiming(1.015, { duration: 3200, easing: Easing.inOut(Easing.sin) }),
        withTiming(0.985, { duration: 3200, easing: Easing.inOut(Easing.sin) })
      ),
      -1,
      false
    );
  }, []);

  const headerStyle = useAnimatedStyle(() => ({ opacity: headerOpacity.value }));
  const contentStyle = useAnimatedStyle(() => ({
    opacity: contentOpacity.value,
    transform: [{ translateY: contentY.value }],
  }));
  const buttonAnimStyle = useAnimatedStyle(() => ({
    transform: [{ scale: buttonScale.value }],
  }));

  const lastSession = sessions[0];
  const webTopPad = Platform.OS === 'web' ? 67 : 0;
  const webBottomPad = Platform.OS === 'web' ? 34 : 0;

  function handleBegin() {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (!hasSeenDisclaimer) {
      router.push('/onboarding');
    } else {
      router.push('/session');
    }
  }

  const amberFill = isDark ? `${PreludeColors.amber}` : `${PreludeColors.amber}`;
  const sageFill = isDark ? PreludeColors.sage : PreludeColors.sage;
  const screenW = 390;

  return (
    <View
      style={[
        styles.container,
        { backgroundColor: isDark ? PreludeColors.depth.dark : PreludeColors.depth.light },
      ]}
    >
      {/* ── Ambient background blobs ── */}
      <View style={StyleSheet.absoluteFill} pointerEvents="none">
        <AmbientBlob
          size={420}
          x={screenW * 0.72}
          y={180}
          opacity={isDark ? 0.055 : 0.07}
          rotateDuration={28000}
          rotateOffset={15}
          breathDuration={5000}
          color={amberFill}
          radiusMultiplier={0.48}
        />
        <AmbientBlob
          size={320}
          x={screenW * 0.18}
          y={380}
          opacity={isDark ? 0.04 : 0.055}
          rotateDuration={34000}
          rotateOffset={200}
          breathDuration={6500}
          color={sageFill}
          radiusMultiplier={0.44}
        />
        <AmbientBlob
          size={260}
          x={screenW * 0.65}
          y={580}
          opacity={isDark ? 0.03 : 0.045}
          rotateDuration={22000}
          rotateOffset={90}
          breathDuration={4800}
          color={amberFill}
          radiusMultiplier={0.5}
        />
      </View>

      {/* ── Header — Wordmark ── */}
      <Animated.View
        style={[
          styles.header,
          headerStyle,
          {
            paddingTop: insets.top + webTopPad + 20,
            borderBottomColor: isDark
              ? 'rgba(255,255,255,0.055)'
              : 'rgba(26,22,18,0.07)',
          },
        ]}
      >
        <View style={styles.wordmarkRow}>
          <Text style={[styles.wordmark, { color: colors.primary }]}>
            Prelude
          </Text>
          <View
            style={[
              styles.wordmarkDivider,
              { backgroundColor: isDark ? 'rgba(200,135,58,0.35)' : 'rgba(200,135,58,0.45)' },
            ]}
          />
          <Text style={[styles.tagline, { color: colors.amber }]}>
            Therapy prep
          </Text>
        </View>
      </Animated.View>

      {/* ── Main content ── */}
      <Animated.View
        style={[
          styles.content,
          contentStyle,
          {
            paddingBottom: insets.bottom + webBottomPad + 24,
          },
        ]}
      >
        {/* Greeting block */}
        <View style={styles.greetingBlock}>
          <Text style={[styles.greeting, { color: colors.primary }]}>
            {getGreeting()}
            {userName ? `,\n${userName.split(' ')[0]}` : '.'}{userName ? '.' : ''}
          </Text>
          <Text style={[styles.subtitle, { color: colors.secondary }]}>
            {lastSession?.brief?.themes?.[0]
              ? `Last time: ${lastSession.brief.themes[0]}`
              : 'Ready when you are.'}
          </Text>
        </View>

        {/* Begin Reflection — pill button */}
        <Animated.View style={[styles.buttonWrap, buttonAnimStyle]}>
          <Pressable
            onPress={handleBegin}
            accessibilityLabel="Begin Reflection"
            accessibilityRole="button"
            style={({ pressed }) => [
              styles.beginButton,
              {
                backgroundColor: pressed
                  ? isDark ? 'rgba(200,135,58,0.18)' : 'rgba(200,135,58,0.14)'
                  : isDark ? 'rgba(200,135,58,0.11)' : 'rgba(200,135,58,0.09)',
                borderColor: isDark
                  ? 'rgba(200,135,58,0.38)'
                  : 'rgba(200,135,58,0.45)',
                transform: [{ scale: pressed ? 0.978 : 1 }],
              },
            ]}
          >
            <Text style={[styles.beginLabel, { color: colors.amber }]}>
              Begin Reflection
            </Text>
            <View
              style={[
                styles.arrowCircle,
                { borderColor: isDark ? 'rgba(200,135,58,0.3)' : 'rgba(200,135,58,0.35)' },
              ]}
            >
              <Text style={[styles.arrow, { color: colors.amber }]}>→</Text>
            </View>
          </Pressable>
        </Animated.View>

        {/* Last session card */}
        {lastSession && (
          <View
            style={[
              styles.lastSessionCard,
              {
                backgroundColor: isDark
                  ? 'rgba(255,255,255,0.035)'
                  : 'rgba(26,22,18,0.04)',
                borderColor: isDark
                  ? 'rgba(255,255,255,0.06)'
                  : 'rgba(26,22,18,0.07)',
              },
            ]}
          >
            <View style={styles.lastSessionHeader}>
              <Text style={[styles.lastSessionLabel, { color: colors.tertiary }]}>
                {formatLastSession(lastSession.completedAt).toUpperCase()}
              </Text>
              <View
                style={[
                  styles.durationPill,
                  {
                    backgroundColor: isDark
                      ? 'rgba(122,158,126,0.12)'
                      : 'rgba(122,158,126,0.14)',
                  },
                ]}
              >
                <Text style={[styles.durationText, { color: colors.sage }]}>
                  {lastSession.durationMinutes ?? 18} min
                </Text>
              </View>
            </View>
            <Text
              style={[styles.lastSessionThemes, { color: colors.secondary }]}
              numberOfLines={2}
            >
              {lastSession.brief?.themes?.join('  ·  ') ?? 'Reflection session'}
            </Text>
            {lastSession.brief?.emotionalTone && (
              <Text style={[styles.emotionalTone, { color: colors.tertiary }]}>
                Tone: {lastSession.brief.emotionalTone}
              </Text>
            )}
          </View>
        )}
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },

  // Header
  header: {
    paddingHorizontal: 28,
    paddingBottom: 16,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  wordmarkRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  wordmark: {
    fontSize: 20,
    fontWeight: '500',
    fontFamily: Platform.OS === 'ios' ? 'NewYorkSmall-Medium' : undefined,
    letterSpacing: 0.3,
  },
  wordmarkDivider: {
    width: 1,
    height: 14,
    borderRadius: 1,
  },
  tagline: {
    fontSize: 12,
    fontWeight: '500',
    fontFamily: 'Inter_500Medium',
    letterSpacing: 1.4,
    textTransform: 'uppercase',
  },

  // Content
  content: {
    flex: 1,
    paddingHorizontal: 28,
    paddingTop: 52,
    justifyContent: 'flex-start',
    gap: 36,
  },

  // Greeting
  greetingBlock: {
    gap: 10,
  },
  greeting: {
    fontSize: 40,
    lineHeight: 48,
    fontWeight: '300',
    fontFamily: Platform.OS === 'ios' ? 'NewYorkSmall-Regular' : undefined,
    letterSpacing: -0.3,
  },
  subtitle: {
    fontSize: 15,
    fontWeight: '400',
    fontFamily: 'Inter_400Regular',
    letterSpacing: 0.1,
  },

  // Button
  buttonWrap: {},
  beginButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    borderRadius: 100,
    borderWidth: 1,
    paddingVertical: 17,
    paddingLeft: 26,
    paddingRight: 16,
  },
  beginLabel: {
    fontSize: 18,
    fontWeight: '500',
    fontFamily: Platform.OS === 'ios' ? 'NewYorkSmall-Medium' : 'Inter_500Medium',
    letterSpacing: 0.2,
  },
  arrowCircle: {
    width: 36,
    height: 36,
    borderRadius: 18,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  arrow: {
    fontSize: 16,
    fontWeight: '400',
  },

  // Last session card
  lastSessionCard: {
    borderRadius: 16,
    borderWidth: StyleSheet.hairlineWidth,
    padding: 18,
    gap: 8,
  },
  lastSessionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  lastSessionLabel: {
    fontSize: 10,
    fontWeight: '600',
    fontFamily: 'Inter_600SemiBold',
    letterSpacing: 1.2,
  },
  durationPill: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 100,
  },
  durationText: {
    fontSize: 11,
    fontWeight: '500',
    fontFamily: 'Inter_500Medium',
    letterSpacing: 0.3,
  },
  lastSessionThemes: {
    fontSize: 15,
    lineHeight: 22,
    fontFamily: Platform.OS === 'ios' ? 'NewYorkSmall-Regular' : undefined,
    letterSpacing: 0.1,
  },
  emotionalTone: {
    fontSize: 12,
    fontFamily: 'Inter_400Regular',
    letterSpacing: 0.2,
  },
});
