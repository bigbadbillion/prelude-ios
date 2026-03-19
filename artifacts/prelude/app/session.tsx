import { Feather } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { router } from 'expo-router';
import React, { useEffect, useRef, useState } from 'react';
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
import { useApp, type Session, type VoiceState } from '@/context/AppContext';

// Mock agent responses for demo
const agentTurns: { text: string; delay: number }[] = [
  {
    text: "Take a moment to settle in. There's no hurry here. When you're ready — how are you coming into today?",
    delay: 2000,
  },
  {
    text: "I hear that. When you say things have felt heavy — is there a particular moment this week that sits with you most?",
    delay: 8000,
  },
  {
    text: "It sounds like there's a real weight in that. What emotion is underneath it, if you had to name one?",
    delay: 8000,
  },
  {
    text: "I want to reflect back a few things I heard: a sense of carrying something alone, some uncertainty about what comes next, and underneath it all — a quiet hope that things can shift. Does that feel close?",
    delay: 10000,
  },
  {
    text: "You've been generous in what you've shared today. I'll pull together your brief now. Take it into your session — it's yours.",
    delay: 8000,
  },
];

export default function SessionScreen() {
  const isDark = useColorScheme() === 'dark';
  const colors = getColors(isDark);
  const insets = useSafeAreaInsets();
  const { startSession, endSession, voiceState, setVoiceState } = useApp();

  const [agentText, setAgentText] = useState('');
  const [transcriptLines, setTranscriptLines] = useState<string[]>([]);
  const [sessionStarted, setSessionStarted] = useState(false);
  const [phase, setPhase] = useState(0);
  const sessionRef = useRef<Session | null>(null);
  const turnTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const textOpacity = useSharedValue(0);
  const controlsOpacity = useSharedValue(0);

  const textStyle = useAnimatedStyle(() => ({ opacity: textOpacity.value }));
  const controlsStyle = useAnimatedStyle(() => ({ opacity: controlsOpacity.value }));

  useEffect(() => {
    // Entrance
    controlsOpacity.value = withTiming(1, { duration: 800, easing: Easing.out(Easing.exp) });

    // Start the session
    const s = startSession();
    sessionRef.current = s;

    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setVoiceState('listening');
    setSessionStarted(true);

    // Kick off first agent turn
    scheduleAgentTurn(0);

    return () => {
      if (turnTimerRef.current) clearTimeout(turnTimerRef.current);
    };
  }, []);

  function scheduleAgentTurn(idx: number) {
    if (idx >= agentTurns.length) return;
    const turn = agentTurns[idx];
    turnTimerRef.current = setTimeout(() => {
      speakAgentText(turn.text, idx);
    }, turn.delay);
  }

  function speakAgentText(text: string, idx: number) {
    setVoiceState('speaking');
    textOpacity.value = withTiming(0, { duration: 200 }, () => {
      textOpacity.value = withTiming(1, { duration: 600 });
    });
    setAgentText(text);

    // Simulate listening after agent finishes
    const speakDuration = text.length * 60 + 1000;
    setTimeout(() => {
      if (idx < agentTurns.length - 1) {
        setVoiceState('listening');
        // Add a fake transcript line
        setTranscriptLines((prev) => [
          ...prev,
          idx === 0 ? "I feel like I've been running on empty this week..." :
          idx === 1 ? 'There was a conversation I had that I keep replaying.' :
          idx === 2 ? 'Anxious. Mostly anxious.' :
          'Yeah. That feels right.',
        ]);
        // Process
        setTimeout(() => {
          setVoiceState('processing');
          setTimeout(() => {
            scheduleAgentTurn(idx + 1);
          }, 1200);
        }, 3000);
      } else {
        // Last turn — end session
        handleEndSession();
      }
    }, speakDuration);
  }

  function handlePause() {
    if (voiceState === 'paused') {
      setVoiceState('listening');
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    } else {
      setVoiceState('paused');
      if (turnTimerRef.current) clearTimeout(turnTimerRef.current);
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
  }

  function handleEndSession() {
    if (turnTimerRef.current) clearTimeout(turnTimerRef.current);
    setVoiceState('ended');

    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);

    const session = sessionRef.current;
    if (session) {
      endSession(session);
    }

    // Navigate to brief
    setTimeout(() => {
      router.replace({ pathname: '/brief/[id]', params: { id: sessionRef.current?.id ?? '0' } });
    }, 800);
  }

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

  function confirmEndSession() {
    Alert.alert(
      'End session?',
      "Your brief will be generated from what you've shared so far.",
      [
        { text: 'Keep going', style: 'cancel' },
        { text: 'End session', onPress: handleEndSession, style: 'default' },
      ]
    );
  }

  // Background tint shifts with voice state
  const bgColor =
    voiceState === 'speaking'
      ? isDark ? '#0F0D0A' : '#FAF7F2'
      : voiceState === 'processing'
      ? isDark ? '#100D0A' : '#F8F4EE'
      : isDark ? '#0F0D0A' : '#FAF7F2';

  const stateLabel =
    voiceState === 'listening'
      ? 'Listening'
      : voiceState === 'speaking'
      ? 'Speaking'
      : voiceState === 'processing'
      ? ''
      : voiceState === 'paused'
      ? 'Paused'
      : '';

  const webTopPad = Platform.OS === 'web' ? 67 : 0;
  const webBottomPad = Platform.OS === 'web' ? 34 : 0;

  return (
    <View style={[styles.container, { backgroundColor: bgColor }]}>
      {/* Presence zone — top 60% */}
      <View
        style={[
          styles.presenceZone,
          { paddingTop: insets.top + webTopPad + 40 },
        ]}
      >
        <PresenceShape voiceState={voiceState} size={240} />

        {/* State label — subtle */}
        {stateLabel ? (
          <Text style={[styles.stateLabel, { color: colors.tertiary }]}>
            {stateLabel}
          </Text>
        ) : null}
      </View>

      {/* Ground zone — bottom 40% */}
      <View style={styles.groundZone}>
        {/* Agent text */}
        {agentText ? (
          <Animated.View style={[styles.agentTextWrapper, textStyle]}>
            <Text style={[styles.agentText, { color: colors.primary }]}>
              {agentText}
            </Text>
          </Animated.View>
        ) : null}

        {/* Live transcript */}
        {transcriptLines.length > 0 && (
          <ScrollView
            style={styles.transcriptScroll}
            showsVerticalScrollIndicator={false}
            contentContainerStyle={styles.transcriptContent}
          >
            {transcriptLines.map((line, i) => (
              <Text
                key={i}
                style={[styles.transcriptLine, { color: colors.secondary }]}
              >
                {line}
              </Text>
            ))}
          </ScrollView>
        )}
      </View>

      {/* Controls — bottom edge */}
      <Animated.View
        style={[
          styles.controls,
          controlsStyle,
          { paddingBottom: insets.bottom + webBottomPad + 16 },
        ]}
      >
        {/* Pause */}
        <TouchableOpacity
          onPress={handlePause}
          activeOpacity={0.7}
          style={styles.controlBtn}
          accessibilityLabel={voiceState === 'paused' ? 'Resume session' : 'Pause session'}
          accessibilityRole="button"
          hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
        >
          <Feather
            name={voiceState === 'paused' ? 'play' : 'pause'}
            size={22}
            color={colors.secondary}
          />
        </TouchableOpacity>

        {/* End session */}
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

        {/* Crisis resource */}
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
  container: {
    flex: 1,
  },
  presenceZone: {
    flex: 0.6,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stateLabel: {
    marginTop: 32,
    fontSize: 12,
    fontWeight: '500',
    letterSpacing: 1.5,
    fontFamily: 'Inter_500Medium',
    textTransform: 'uppercase',
  },
  groundZone: {
    flex: 0.4,
    paddingHorizontal: 32,
    justifyContent: 'flex-start',
    paddingTop: 8,
  },
  agentTextWrapper: {
    marginBottom: 16,
  },
  agentText: {
    fontSize: 17,
    lineHeight: 27,
    textAlign: 'center',
    fontFamily: Platform.OS === 'ios' ? 'NewYorkSmall-Regular' : undefined,
    letterSpacing: 0.2,
  },
  transcriptScroll: {
    maxHeight: 80,
    opacity: 0.6,
  },
  transcriptContent: {
    paddingBottom: 4,
  },
  transcriptLine: {
    fontSize: 13,
    lineHeight: 19,
    fontFamily: Platform.OS === 'ios' ? 'Menlo-Regular' : 'monospace',
    marginBottom: 2,
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
});
