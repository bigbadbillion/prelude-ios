import { Feather } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { router } from 'expo-router';
import React, { useCallback, useEffect, useRef } from 'react';
import {
  Alert,
  Linking,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  useColorScheme,
} from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withTiming,
  Easing,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import PresenceShape from '@/components/PresenceShape';
import { PreludeColors, getColors } from '@/constants/colors';
import { useApp, type Session } from '@/context/AppContext';
import { useVoiceEngine } from '@/hooks/useVoiceEngine';

// ── Phase 2: scripted agent turns — swapped for real AI in Phase 3 ───────────
// Index 0 is the opening line (agent speaks first).
// Indices 1-N are responses to each user turn.
const AGENT_SCRIPT = [
  "Take a moment to settle in. There's no hurry here. When you're ready — how are you coming into today?",
  "I hear that. When you say things have felt heavy — is there a particular moment this week that sits with you most?",
  "It sounds like there's a real weight in that. What emotion is underneath it, if you had to name one?",
  "I want to reflect back a few things I heard: a sense of carrying something alone, some uncertainty about what comes next, and underneath it all — a quiet hope that things can shift. Does that feel close?",
  "You've been generous in what you've shared today. I'll pull together your brief now. Take it into your session — it's yours.",
];

export default function SessionScreen() {
  const isDark = useColorScheme() === 'dark';
  const colors = getColors(isDark);
  const insets = useSafeAreaInsets();
  const { startSession, endSession } = useApp();

  const sessionRef = useRef<Session | null>(null);
  const scriptIndexRef = useRef(1); // 0 is spoken as opening; responses start at 1
  const transcriptScrollRef = useRef<ScrollView>(null);
  const didStartRef = useRef(false);

  const controlsOpacity = useSharedValue(0);
  const agentTextOpacity = useSharedValue(0);
  const controlsStyle = useAnimatedStyle(() => ({ opacity: controlsOpacity.value }));
  const agentTextStyle = useAnimatedStyle(() => ({ opacity: agentTextOpacity.value }));

  // ── Agent response callback — called after user silence detected ──────────
  const onUserTurnComplete = useCallback(async (transcript: string): Promise<string | null> => {
    const idx = scriptIndexRef.current;
    if (idx >= AGENT_SCRIPT.length) {
      // No more lines — signal session end
      return null;
    }
    scriptIndexRef.current += 1;
    return AGENT_SCRIPT[idx];
  }, []);

  // ── Session end callback ──────────────────────────────────────────────────
  const onSessionEnd = useCallback(() => {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    const session = sessionRef.current;
    if (session) endSession(session);
    setTimeout(() => {
      router.replace({
        pathname: '/brief/[id]',
        params: { id: session?.id ?? '0' },
      });
    }, 900);
  }, [endSession]);

  // ── Voice engine ──────────────────────────────────────────────────────────
  const voice = useVoiceEngine({
    onUserTurnComplete,
    onSessionEnd,
    onLiveTranscript: () => {
      transcriptScrollRef.current?.scrollToEnd({ animated: true });
    },
    silenceThresholdMs: 800,
  });

  // ── Mount: start audio, haptic feedback, then speak opening line ──────────
  useEffect(() => {
    const session = startSession();
    sessionRef.current = session;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    controlsOpacity.value = withTiming(1, { duration: 900, easing: Easing.out(Easing.exp) });

    // Set up audio pipeline, then have agent speak the opening line
    voice.start().then(() => {
      if (!didStartRef.current) {
        didStartRef.current = true;
        setTimeout(() => {
          voice.speakAgent(AGENT_SCRIPT[0]);
        }, 600); // brief pause before first word
      }
    });

    return () => {
      voice.end();
    };
  }, []);

  // ── Cross-fade agent text on each new utterance ───────────────────────────
  const prevAgentText = useRef('');
  useEffect(() => {
    if (voice.agentText && voice.agentText !== prevAgentText.current) {
      prevAgentText.current = voice.agentText;
      agentTextOpacity.value = withTiming(0, { duration: 180 }, () => {
        agentTextOpacity.value = withTiming(1, { duration: 500 });
      });
    }
  }, [voice.agentText]);

  // ── Auto-scroll transcript on new committed lines ─────────────────────────
  useEffect(() => {
    if (voice.transcriptLines.length > 0) {
      setTimeout(() => transcriptScrollRef.current?.scrollToEnd({ animated: true }), 60);
    }
  }, [voice.transcriptLines.length]);

  // ── Pause / resume ────────────────────────────────────────────────────────
  function handlePauseResume() {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (voice.voiceState === 'paused') {
      voice.resume();
    } else {
      voice.pause();
    }
  }

  // ── End session ───────────────────────────────────────────────────────────
  function confirmEndSession() {
    Alert.alert(
      'End session?',
      "Your brief will be generated from what you've shared so far.",
      [
        { text: 'Keep going', style: 'cancel' },
        {
          text: 'End session',
          style: 'default',
          onPress: () => {
            voice.end();
            Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
            const session = sessionRef.current;
            if (session) endSession(session);
            setTimeout(() => {
              router.replace({
                pathname: '/brief/[id]',
                params: { id: session?.id ?? '0' },
              });
            }, 600);
          },
        },
      ]
    );
  }

  // ── Crisis resource ───────────────────────────────────────────────────────
  function handleCrisisResource() {
    Alert.alert(
      '988 Suicide & Crisis Lifeline',
      "If you're in crisis, support is available. Call or text 988.",
      [
        { text: 'Not now', style: 'cancel' },
        { text: 'Call 988', onPress: () => Linking.openURL('tel:988'), style: 'default' },
      ]
    );
  }

  const stateLabel =
    voice.voiceState === 'listening'
      ? 'Listening'
      : voice.voiceState === 'paused'
      ? 'Paused'
      : '';

  const webTopPad = Platform.OS === 'web' ? 67 : 0;
  const webBottomPad = Platform.OS === 'web' ? 34 : 0;
  const bgColor = isDark ? PreludeColors.depth.dark : PreludeColors.depth.light;

  // ── Permission denied ─────────────────────────────────────────────────────
  if (voice.isPermissionGranted === false) {
    return (
      <View style={[styles.container, { backgroundColor: bgColor }]}>
        <View style={styles.centeredState}>
          <Feather name="mic-off" size={32} color={colors.tertiary} />
          <Text style={[styles.permissionTitle, { color: colors.primary }]}>
            Microphone access needed
          </Text>
          <Text style={[styles.permissionBody, { color: colors.secondary }]}>
            Prelude listens during sessions. Please enable microphone access in
            your browser or device settings and try again.
          </Text>
          <TouchableOpacity
            onPress={() => router.back()}
            style={styles.backBtn}
            accessibilityRole="button"
          >
            <Text style={[styles.backLabel, { color: colors.amber }]}>Go back</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────
  if (voice.error) {
    return (
      <View style={[styles.container, { backgroundColor: bgColor }]}>
        <View style={styles.centeredState}>
          <Feather name="alert-circle" size={28} color={colors.tertiary} />
          <Text style={[styles.permissionTitle, { color: colors.primary }]}>
            Something went wrong
          </Text>
          <Text style={[styles.permissionBody, { color: colors.secondary }]}>
            {voice.error}
          </Text>
          <TouchableOpacity
            onPress={() => router.back()}
            style={styles.backBtn}
            accessibilityRole="button"
          >
            <Text style={[styles.backLabel, { color: colors.amber }]}>Go back</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  return (
    <View style={[styles.container, { backgroundColor: bgColor }]}>

      {/* ── Presence zone — top 60% ─────────────────────────────────────── */}
      <View style={[styles.presenceZone, { paddingTop: insets.top + webTopPad + 40 }]}>
        <PresenceShape
          voiceState={voice.voiceState}
          size={240}
          amplitude={voice.amplitude}
        />

        {/* State label */}
        {stateLabel ? (
          <Text style={[styles.stateLabel, { color: colors.tertiary }]}>
            {stateLabel}
          </Text>
        ) : null}

        {/* Amplitude indicator dots — visible while listening */}
        {voice.voiceState === 'listening' && (
          <View style={styles.ampDots}>
            {[0.15, 0.45, 0.75].map((threshold, i) => (
              <View
                key={i}
                style={[
                  styles.ampDot,
                  {
                    backgroundColor:
                      voice.amplitude >= threshold
                        ? PreludeColors.calm
                        : isDark
                        ? 'rgba(255,255,255,0.12)'
                        : 'rgba(0,0,0,0.12)',
                    transform: [{ scale: voice.amplitude >= threshold ? 1.3 : 1 }],
                  },
                ]}
              />
            ))}
          </View>
        )}
      </View>

      {/* ── Ground zone — bottom 40% ────────────────────────────────────── */}
      <View style={styles.groundZone}>
        {/* Agent text */}
        {voice.agentText ? (
          <Animated.View style={[styles.agentTextWrapper, agentTextStyle]}>
            <Text style={[styles.agentText, { color: colors.primary }]}>
              {voice.agentText}
            </Text>
          </Animated.View>
        ) : null}

        {/* Transcript: committed lines + live partial */}
        {(voice.transcriptLines.length > 0 || voice.liveTranscript) && (
          <ScrollView
            ref={transcriptScrollRef}
            style={styles.transcriptScroll}
            showsVerticalScrollIndicator={false}
            contentContainerStyle={styles.transcriptContent}
          >
            {voice.transcriptLines.map((line, i) => (
              <Text
                key={i}
                style={[styles.transcriptLine, { color: colors.tertiary }]}
              >
                {line}
              </Text>
            ))}
            {voice.liveTranscript ? (
              <Text style={[styles.transcriptLive, { color: colors.secondary }]}>
                {voice.liveTranscript}
              </Text>
            ) : null}
          </ScrollView>
        )}
      </View>

      {/* ── Controls ────────────────────────────────────────────────────── */}
      <Animated.View
        style={[
          styles.controls,
          controlsStyle,
          { paddingBottom: insets.bottom + webBottomPad + 16 },
        ]}
      >
        <TouchableOpacity
          onPress={handlePauseResume}
          activeOpacity={0.7}
          style={styles.controlBtn}
          accessibilityLabel={voice.voiceState === 'paused' ? 'Resume session' : 'Pause session'}
          accessibilityRole="button"
          hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
        >
          <Feather
            name={voice.voiceState === 'paused' ? 'play' : 'pause'}
            size={22}
            color={colors.secondary}
          />
        </TouchableOpacity>

        <TouchableOpacity
          onPress={confirmEndSession}
          activeOpacity={0.7}
          style={styles.endBtn}
          accessibilityLabel="End session"
          accessibilityRole="button"
        >
          <Text style={[styles.endBtnText, { color: colors.secondary }]}>
            End session
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          onPress={handleCrisisResource}
          activeOpacity={0.7}
          style={styles.controlBtn}
          accessibilityLabel="Crisis resource — 988 Lifeline"
          accessibilityRole="button"
          hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
        >
          <Text style={[styles.crisisText, { color: colors.tertiary }]}>?</Text>
        </TouchableOpacity>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },

  presenceZone: {
    flex: 0.6,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 20,
  },
  stateLabel: {
    fontSize: 11,
    fontWeight: '500',
    letterSpacing: 1.8,
    fontFamily: 'Inter_500Medium',
    textTransform: 'uppercase',
  },
  ampDots: {
    flexDirection: 'row',
    gap: 7,
    alignItems: 'center',
    height: 12,
  },
  ampDot: {
    width: 5,
    height: 5,
    borderRadius: 3,
  },

  groundZone: {
    flex: 0.4,
    paddingHorizontal: 32,
    justifyContent: 'flex-start',
    paddingTop: 4,
  },
  agentTextWrapper: { marginBottom: 16 },
  agentText: {
    fontSize: 17,
    lineHeight: 28,
    textAlign: 'center',
    fontFamily: Platform.OS === 'ios' ? 'NewYorkSmall-Regular' : undefined,
    letterSpacing: 0.2,
  },
  transcriptScroll: { maxHeight: 68, opacity: 0.55 },
  transcriptContent: { paddingBottom: 4 },
  transcriptLine: {
    fontSize: 12,
    lineHeight: 18,
    fontFamily: Platform.OS === 'ios' ? 'Menlo-Regular' : 'monospace',
    marginBottom: 2,
  },
  transcriptLive: {
    fontSize: 12,
    lineHeight: 18,
    fontFamily: Platform.OS === 'ios' ? 'Menlo-Regular' : 'monospace',
    fontStyle: 'italic',
  },

  controls: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 32,
    paddingTop: 12,
  },
  controlBtn: {
    width: 44,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  endBtn: {
    paddingHorizontal: 24,
    paddingVertical: 12,
    minWidth: 110,
    alignItems: 'center',
  },
  endBtnText: {
    fontSize: 14,
    fontFamily: 'Inter_400Regular',
    letterSpacing: 0.2,
  },
  crisisText: {
    fontSize: 18,
    fontFamily: 'Inter_400Regular',
    fontWeight: '300',
    lineHeight: 22,
  },

  centeredState: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 40,
    gap: 16,
  },
  permissionTitle: {
    fontSize: 20,
    fontWeight: '500',
    fontFamily: 'Inter_500Medium',
    textAlign: 'center',
    marginTop: 8,
  },
  permissionBody: {
    fontSize: 15,
    lineHeight: 23,
    fontFamily: 'Inter_400Regular',
    textAlign: 'center',
  },
  backBtn: {
    marginTop: 8,
    paddingVertical: 12,
    paddingHorizontal: 24,
  },
  backLabel: {
    fontSize: 16,
    fontWeight: '500',
    fontFamily: 'Inter_500Medium',
  },
});
