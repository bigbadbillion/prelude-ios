import React, { useEffect } from 'react';
import { View, StyleSheet } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming,
  Easing,
} from 'react-native-reanimated';
import type { VoiceState } from '@/context/AppContext';
import { PreludeColors } from '@/constants/colors';

interface PresenceShapeProps {
  voiceState: VoiceState;
  size?: number;
  /** Live microphone amplitude 0–1. Drives reactive breathing when listening. */
  amplitude?: number;
}

export default function PresenceShape({
  voiceState,
  size = 260,
  amplitude = 0,
}: PresenceShapeProps) {
  // ── Shared values ──────────────────────────────────────────────────────────
  const scale1 = useSharedValue(1);
  const scale2 = useSharedValue(0.88);
  const scale3 = useSharedValue(0.72);
  const opacity1 = useSharedValue(0.15);
  const opacity2 = useSharedValue(0.10);
  const opacity3 = useSharedValue(0.07);
  const rotate1 = useSharedValue(0);

  // Amplitude-driven reactive layer on top of the ambient breathing
  const ampScale = useSharedValue(1);

  // ── Animate on voiceState change ───────────────────────────────────────────
  useEffect(() => {
    if (voiceState === 'idle' || voiceState === 'listening') {
      // Slow ambient breath — autoreverse for seamless loop
      scale1.value = withRepeat(
        withTiming(1.08, { duration: 2000, easing: Easing.inOut(Easing.sin) }),
        -1, true
      );
      scale2.value = withRepeat(
        withTiming(0.95, { duration: 2800, easing: Easing.inOut(Easing.sin) }),
        -1, true
      );
      opacity1.value = withTiming(0.15, { duration: 600 });
      opacity2.value = withTiming(0.10, { duration: 600 });
      opacity3.value = withTiming(0.07, { duration: 600 });
      rotate1.value = withRepeat(
        withTiming(360, { duration: 18000, easing: Easing.linear }),
        -1, false
      );
    } else if (voiceState === 'speaking') {
      // Fuller, expanded form with soft pulse
      scale1.value = withRepeat(
        withTiming(1.18, { duration: 1000, easing: Easing.inOut(Easing.sin) }),
        -1, true
      );
      scale2.value = withRepeat(
        withTiming(1.04, { duration: 1200, easing: Easing.inOut(Easing.sin) }),
        -1, true
      );
      opacity1.value = withTiming(0.22, { duration: 800 });
      opacity2.value = withTiming(0.14, { duration: 800 });
      opacity3.value = withTiming(0.09, { duration: 800 });
    } else if (voiceState === 'processing') {
      // Contract and hold still
      scale1.value = withTiming(0.88, { duration: 800, easing: Easing.out(Easing.exp) });
      scale2.value = withTiming(0.74, { duration: 900, easing: Easing.out(Easing.exp) });
      scale3.value = withTiming(0.58, { duration: 1000, easing: Easing.out(Easing.exp) });
      opacity1.value = withTiming(0.10, { duration: 600 });
      opacity2.value = withTiming(0.07, { duration: 600 });
      opacity3.value = withTiming(0.04, { duration: 600 });
    } else if (voiceState === 'paused') {
      scale1.value = withTiming(0.94, { duration: 600 });
      scale2.value = withTiming(0.78, { duration: 700 });
      opacity1.value = withTiming(0.08, { duration: 600 });
      opacity2.value = withTiming(0.05, { duration: 600 });
    } else if (voiceState === 'ended') {
      scale1.value = withTiming(0.82, { duration: 1200 });
      opacity1.value = withTiming(0.06, { duration: 1200 });
      opacity2.value = withTiming(0.04, { duration: 1200 });
      opacity3.value = withTiming(0.02, { duration: 1200 });
    }
  }, [voiceState]);

  // ── Amplitude reaction — drives ampScale smoothly ──────────────────────────
  useEffect(() => {
    // Amplitude 0–1 → additional scale 1.0–1.25 on the outer layer
    // Use a fast withTiming so it tracks the mic in near real-time
    const target = 1 + amplitude * 0.28;
    ampScale.value = withTiming(target, { duration: 80, easing: Easing.out(Easing.quad) });
  }, [amplitude]);

  // ── State color ────────────────────────────────────────────────────────────
  const stateColor =
    voiceState === 'processing'
      ? PreludeColors.processing
      : voiceState === 'speaking'
      ? PreludeColors.calm
      : PreludeColors.calm;

  // ── Animated styles ────────────────────────────────────────────────────────
  const outerStyle = useAnimatedStyle(() => ({
    opacity: opacity3.value,
    transform: [
      { scale: scale1.value * ampScale.value },
      { rotate: `${rotate1.value}deg` },
    ],
  }));

  const midStyle = useAnimatedStyle(() => ({
    opacity: opacity2.value,
    transform: [{ scale: scale2.value * (1 + (ampScale.value - 1) * 0.6) }],
  }));

  const coreStyle = useAnimatedStyle(() => ({
    opacity: opacity1.value,
    transform: [{ scale: scale3.value * (1 + (ampScale.value - 1) * 0.35) }],
  }));

  return (
    <View
      style={[styles.container, { width: size, height: size }]}
      accessibilityLabel={`Presence indicator, currently ${voiceState}`}
    >
      {/* Outermost glow */}
      <Animated.View
        style={[
          styles.layer,
          {
            width: size * 1.1,
            height: size * 1.1,
            backgroundColor: stateColor,
            borderRadius: size * 0.55,
          },
          outerStyle,
        ]}
      />

      {/* Mid layer — slightly different shape */}
      <Animated.View
        style={[
          styles.layer,
          {
            width: size * 0.85,
            height: size * 0.9,
            backgroundColor: stateColor,
            borderRadius: size * 0.42,
          },
          midStyle,
        ]}
      />

      {/* Core */}
      <Animated.View
        style={[
          styles.layer,
          {
            width: size * 0.62,
            height: size * 0.66,
            backgroundColor: stateColor,
            borderRadius: size * 0.32,
          },
          coreStyle,
        ]}
      />

      {/* Edge ring */}
      <View
        style={[
          styles.ring,
          {
            width: size + 2,
            height: size + 2,
            borderRadius: (size + 2) / 2,
            borderColor:
              voiceState === 'listening'
                ? `${PreludeColors.calm}50`
                : `${stateColor}25`,
          },
        ]}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  layer: {
    position: 'absolute',
  },
  ring: {
    position: 'absolute',
    borderWidth: 1,
    backgroundColor: 'transparent',
  },
});
