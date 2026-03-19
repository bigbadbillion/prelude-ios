import { Feather } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { router } from 'expo-router';
import React, { useEffect } from 'react';
import {
  Linking,
  Platform,
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
import PresenceShape from '@/components/PresenceShape';
import { getColors, PreludeColors } from '@/constants/colors';
import { useApp } from '@/context/AppContext';

export default function OnboardingScreen() {
  const isDark = useColorScheme() === 'dark';
  const colors = getColors(isDark);
  const insets = useSafeAreaInsets();
  const { setHasSeenDisclaimer } = useApp();

  const logoOpacity = useSharedValue(0);
  const textOpacity = useSharedValue(0);
  const disclaimerOpacity = useSharedValue(0);
  const ctaOpacity = useSharedValue(0);

  const logoStyle = useAnimatedStyle(() => ({ opacity: logoOpacity.value }));
  const textStyle = useAnimatedStyle(() => ({ opacity: textOpacity.value }));
  const disclaimerStyle = useAnimatedStyle(() => ({ opacity: disclaimerOpacity.value }));
  const ctaStyle = useAnimatedStyle(() => ({ opacity: ctaOpacity.value }));

  useEffect(() => {
    logoOpacity.value = withTiming(1, { duration: 1000, easing: Easing.out(Easing.exp) });
    textOpacity.value = withDelay(600, withTiming(1, { duration: 800 }));
    disclaimerOpacity.value = withDelay(1200, withTiming(1, { duration: 700 }));
    ctaOpacity.value = withDelay(1800, withTiming(1, { duration: 700 }));
  }, []);

  async function handleBegin() {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    await setHasSeenDisclaimer(true);
    router.replace('/session');
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
      {/* Ambient top shape */}
      <Animated.View
        style={[
          styles.shapeWrapper,
          logoStyle,
          { paddingTop: insets.top + webTopPad + 60 },
        ]}
      >
        <PresenceShape voiceState="idle" size={160} />
        <Text style={[styles.wordmark, { color: colors.primary }]}>Prelude</Text>
      </Animated.View>

      {/* Main content */}
      <View style={styles.content}>
        <Animated.View style={[styles.textBlock, textStyle]}>
          <Text style={[styles.heading, { color: colors.primary }]}>
            A space to prepare.
          </Text>
          <Text style={[styles.body, { color: colors.secondary }]}>
            Prelude helps you arrive at therapy ready — by guiding a short reflection before your session, so you carry what matters most into the room.
          </Text>
          <Text style={[styles.body, { color: colors.secondary }]}>
            Everything stays on your device. Your words, your insights — private by design.
          </Text>
        </Animated.View>

        {/* Disclaimer */}
        <Animated.View
          style={[
            styles.disclaimerBox,
            disclaimerStyle,
            {
              backgroundColor: isDark
                ? 'rgba(37,32,24,0.6)'
                : 'rgba(240,235,227,0.7)',
              borderColor: colors.border,
            },
          ]}
        >
          <Feather name="info" size={14} color={colors.tertiary} style={styles.infoIcon} />
          <Text style={[styles.disclaimerText, { color: colors.tertiary }]}>
            Prelude is a reflection and preparation tool. It is not therapy, and is not a substitute for professional mental health care. If you are in crisis, text or call{' '}
            <Text
              style={{ color: colors.amber }}
              onPress={() => Linking.openURL('tel:988')}
              accessibilityRole="link"
              accessibilityLabel="Call 988 Lifeline"
            >
              988
            </Text>
            .
          </Text>
        </Animated.View>

        {/* CTA */}
        <Animated.View style={[styles.ctaWrapper, ctaStyle]}>
          <TouchableOpacity
            onPress={handleBegin}
            activeOpacity={0.75}
            style={styles.ctaBtn}
            accessibilityRole="button"
            accessibilityLabel="I understand, begin"
          >
            <Text style={[styles.ctaText, { color: colors.amber }]}>
              I understand — begin
            </Text>
          </TouchableOpacity>
        </Animated.View>
      </View>

      <View style={{ height: insets.bottom + webBottomPad + 20 }} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  shapeWrapper: {
    alignItems: 'center',
    gap: 24,
    paddingBottom: 20,
  },
  wordmark: {
    fontSize: 22,
    fontFamily: Platform.OS === 'ios' ? 'NewYorkSmall-Regular' : undefined,
    letterSpacing: 2,
    fontWeight: '400',
  },
  content: {
    flex: 1,
    paddingHorizontal: 32,
    justifyContent: 'center',
    gap: 24,
  },
  textBlock: {
    gap: 16,
  },
  heading: {
    fontSize: 28,
    lineHeight: 36,
    fontFamily: Platform.OS === 'ios' ? 'NewYorkSmall-Regular' : undefined,
    fontWeight: '400',
    letterSpacing: 0.2,
  },
  body: {
    fontSize: 16,
    lineHeight: 25,
    fontFamily: 'Inter_400Regular',
  },
  disclaimerBox: {
    flexDirection: 'row',
    padding: 16,
    borderRadius: 14,
    borderWidth: StyleSheet.hairlineWidth,
    gap: 10,
  },
  infoIcon: {
    marginTop: 2,
    flexShrink: 0,
  },
  disclaimerText: {
    fontSize: 13,
    lineHeight: 20,
    fontFamily: 'Inter_400Regular',
    flex: 1,
  },
  ctaWrapper: {
    alignItems: 'flex-start',
    paddingTop: 8,
  },
  ctaBtn: {
    paddingVertical: 4,
    hitSlop: { top: 16, bottom: 16 },
  },
  ctaText: {
    fontSize: 19,
    fontWeight: '600',
    fontFamily: Platform.OS === 'ios' ? 'NewYorkSmall-Semibold' : undefined,
    letterSpacing: 0.3,
  },
});
