import React, { useEffect, useRef } from 'react';
import { View, StyleSheet, Platform } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withSequence,
  withTiming,
  interpolateColor,
  Easing,
} from 'react-native-reanimated';
import type { VoiceState } from '@/context/AppContext';
import { PreludeColors } from '@/constants/colors';

interface PresenceShapeProps {
  voiceState: VoiceState;
  size?: number;
}

// Blob path control — a soft irregular organic shape
// We simulate it via layered scaled ellipses with different border radii
function BlobLayer({
  scale,
  opacity,
  color,
  size,
  borderRadius,
  rotate,
}: {
  scale: Animated.SharedValue<number>;
  opacity: Animated.SharedValue<number>;
  color: string;
  size: number;
  borderRadius: string;
  rotate: Animated.SharedValue<number>;
}) {
  const style = useAnimatedStyle(() => ({
    transform: [
      { scale: scale.value },
      { rotate: `${rotate.value}deg` },
    ],
    opacity: opacity.value,
  }));

  return (
    <Animated.View
      style={[
        {
          position: 'absolute',
          width: size,
          height: size * 0.92,
          backgroundColor: color,
          borderRadius: (size / 2) * 0.95,
        },
        style,
      ]}
    />
  );
}

export default function PresenceShape({ voiceState, size = 260 }: PresenceShapeProps) {
  const scale1 = useSharedValue(1);
  const scale2 = useSharedValue(0.88);
  const scale3 = useSharedValue(0.72);
  const opacity1 = useSharedValue(0.15);
  const opacity2 = useSharedValue(0.1);
  const opacity3 = useSharedValue(0.07);
  const rotate1 = useSharedValue(0);
  const rotate2 = useSharedValue(12);
  const colorProgress = useSharedValue(0); // 0 = calm, 1 = active, 2 = processing

  // Outer ring (progress arc) — just a thin border
  const ringScale = useSharedValue(1);

  useEffect(() => {
    // Cancel previous animations
    scale1.value = 1;
    scale2.value = 0.88;
    scale3.value = 0.72;

    if (voiceState === 'idle' || voiceState === 'listening') {
      // Slow ambient breath — 4 seconds per cycle
      scale1.value = withRepeat(
        withSequence(
          withTiming(1.08, { duration: 2000, easing: Easing.inOut(Easing.sin) }),
          withTiming(0.97, { duration: 2000, easing: Easing.inOut(Easing.sin) })
        ),
        -1,
        false
      );
      scale2.value = withRepeat(
        withSequence(
          withTiming(0.95, { duration: 2400, easing: Easing.inOut(Easing.sin) }),
          withTiming(0.84, { duration: 2400, easing: Easing.inOut(Easing.sin) })
        ),
        -1,
        false
      );
      opacity1.value = withTiming(0.15, { duration: 600 });
      opacity2.value = withTiming(0.10, { duration: 600 });
      opacity3.value = withTiming(0.07, { duration: 600 });
      rotate1.value = withRepeat(
        withTiming(360, { duration: 18000, easing: Easing.linear }),
        -1,
        false
      );
    } else if (voiceState === 'speaking') {
      // Expanded, fuller form with soft pulse
      scale1.value = withRepeat(
        withSequence(
          withTiming(1.18, { duration: 900, easing: Easing.inOut(Easing.sin) }),
          withTiming(1.12, { duration: 900, easing: Easing.inOut(Easing.sin) })
        ),
        -1,
        false
      );
      scale2.value = withRepeat(
        withSequence(
          withTiming(1.04, { duration: 1100, easing: Easing.inOut(Easing.sin) }),
          withTiming(0.97, { duration: 1100, easing: Easing.inOut(Easing.sin) })
        ),
        -1,
        false
      );
      opacity1.value = withTiming(0.22, { duration: 800 });
      opacity2.value = withTiming(0.14, { duration: 800 });
      opacity3.value = withTiming(0.09, { duration: 800 });
    } else if (voiceState === 'processing') {
      // Contract gently and hold still
      scale1.value = withTiming(0.88, { duration: 800, easing: Easing.out(Easing.exp) });
      scale2.value = withTiming(0.74, { duration: 900, easing: Easing.out(Easing.exp) });
      scale3.value = withTiming(0.58, { duration: 1000, easing: Easing.out(Easing.exp) });
      opacity1.value = withTiming(0.12, { duration: 600 });
      opacity2.value = withTiming(0.08, { duration: 600 });
      opacity3.value = withTiming(0.05, { duration: 600 });
    } else if (voiceState === 'paused') {
      scale1.value = withTiming(0.95, { duration: 600 });
      opacity1.value = withTiming(0.10, { duration: 600 });
    } else if (voiceState === 'ended') {
      scale1.value = withTiming(0.85, { duration: 1200 });
      opacity1.value = withTiming(0.08, { duration: 1200 });
      opacity2.value = withTiming(0.05, { duration: 1200 });
      opacity3.value = withTiming(0.03, { duration: 1200 });
    }
  }, [voiceState]);

  // Color based on state
  const stateColor =
    voiceState === 'speaking'
      ? PreludeColors.calm
      : voiceState === 'processing'
      ? PreludeColors.processing
      : PreludeColors.calm;

  return (
    <View
      style={[styles.container, { width: size, height: size }]}
      accessibilityLabel={`Presence indicator, currently ${voiceState}`}
    >
      {/* Outermost glow layer */}
      <Animated.View
        style={[
          styles.layer,
          {
            width: size * 1.1,
            height: size * 1.1,
            backgroundColor: stateColor,
            borderRadius: size * 0.55,
            opacity: opacity3,
            transform: [{ scale: scale1 }],
          },
        ]}
      />

      {/* Middle layer — slightly different shape */}
      <Animated.View
        style={[
          styles.layer,
          {
            width: size * 0.85,
            height: size * 0.9,
            backgroundColor: stateColor,
            borderRadius: size * 0.42,
            opacity: opacity2,
            transform: [{ scale: scale2 }, { rotate: '8deg' }],
          },
        ]}
      />

      {/* Core layer */}
      <Animated.View
        style={[
          styles.layer,
          {
            width: size * 0.62,
            height: size * 0.66,
            backgroundColor: stateColor,
            borderRadius: size * 0.32,
            opacity: opacity1,
            transform: [{ scale: scale3 }],
          },
        ]}
      />

      {/* Subtle progress ring — thin arc at edge */}
      <View
        style={[
          styles.ring,
          {
            width: size + 2,
            height: size + 2,
            borderRadius: (size + 2) / 2,
            borderColor:
              voiceState === 'listening'
                ? `${PreludeColors.calm}40`
                : `${stateColor}20`,
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
