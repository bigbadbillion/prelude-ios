/**
 * useVoiceEngine — Phase 2 Voice System
 *
 * Manages the complete voice turn-taking loop:
 *   idle → speaking (agent TTS) → listening (user STT + amplitude)
 *   → processing (silence detected) → speaking → ...
 *
 * STT:       Web Speech API on web; native-ready architecture for iOS
 * TTS:       expo-speech (AVSpeechSynthesizer on iOS, speechSynthesis on web)
 * Amplitude: Web Audio API AnalyserNode on web; expo-av metering on native
 * Silence:   800ms threshold — configurable
 */

import * as Speech from 'expo-speech';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Platform } from 'react-native';
import type { VoiceState } from '@/context/AppContext';

export interface VoiceEngineOptions {
  /**
   * Called when the user's silence is detected after speaking.
   * Receives the final transcript of the user's turn.
   * Should return the agent's next spoken response, or null to end session.
   */
  onUserTurnComplete: (transcript: string) => Promise<string | null>;

  /** Called when the agent finishes speaking its closing line. */
  onSessionEnd: () => void;

  /** Called whenever the live transcript updates mid-speech. */
  onLiveTranscript?: (partial: string) => void;

  /** Silence threshold in ms. Default: 800 */
  silenceThresholdMs?: number;
}

export interface VoiceEngineState {
  voiceState: VoiceState;
  /** Microphone amplitude, 0–1. Drives PresenceShape. */
  amplitude: number;
  /** The agent's currently displayed text. */
  agentText: string;
  /** Committed user transcript lines (one per turn). */
  transcriptLines: string[];
  /** Live in-progress transcript (current user turn). */
  liveTranscript: string;
  isPermissionGranted: boolean | null;
  error: string | null;
  start: () => void;
  pause: () => void;
  resume: () => void;
  end: () => void;
}

// ─── Web Speech API types (available in browsers) ────────────────────────────
type SpeechRecognitionInstance = {
  continuous: boolean;
  interimResults: boolean;
  lang: string;
  onresult: ((e: SpeechRecognitionEvent) => void) | null;
  onerror: ((e: SpeechRecognitionErrorEvent) => void) | null;
  onend: (() => void) | null;
  start: () => void;
  stop: () => void;
  abort: () => void;
};
type SpeechRecognitionEvent = {
  resultIndex: number;
  results: {
    length: number;
    [i: number]: { isFinal: boolean; 0: { transcript: string } };
  };
};
type SpeechRecognitionErrorEvent = { error: string };

function getSpeechRecognitionCtor(): (new () => SpeechRecognitionInstance) | null {
  if (typeof window === 'undefined') return null;
  return (
    (window as unknown as Record<string, unknown>)['SpeechRecognition'] as
      | (new () => SpeechRecognitionInstance)
      | null
  ) ??
    (
      (window as unknown as Record<string, unknown>)['webkitSpeechRecognition'] as
        | (new () => SpeechRecognitionInstance)
        | null
    ) ??
    null;
}

// ─── Amplitude via Web Audio API ──────────────────────────────────────────────
async function createAmplitudeAnalyser(): Promise<{
  analyser: AnalyserNode;
  stream: MediaStream;
  context: AudioContext;
} | null> {
  if (typeof navigator === 'undefined' || !navigator.mediaDevices) return null;
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true, video: false });
    const context = new (window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext)();
    const source = context.createMediaStreamSource(stream);
    const analyser = context.createAnalyser();
    analyser.fftSize = 256;
    analyser.smoothingTimeConstant = 0.8;
    source.connect(analyser);
    return { analyser, stream, context };
  } catch {
    return null;
  }
}

function readAmplitude(analyser: AnalyserNode): number {
  const data = new Uint8Array(analyser.frequencyBinCount);
  analyser.getByteFrequencyData(data);
  let sum = 0;
  for (let i = 0; i < data.length; i++) sum += data[i];
  const avg = sum / data.length;
  return Math.min(avg / 80, 1); // normalise 0–1
}

// ─── TTS helpers ──────────────────────────────────────────────────────────────

// iOS: premium voices need to be downloaded in
// Settings → Accessibility → Spoken Content → Voices → English
// These are checked in priority order.
const PREMIUM_VOICES_IOS = [
  'com.apple.voice.premium.en-US.Zoe',    // Premium — best quality
  'com.apple.voice.premium.en-US.Evan',
  'com.apple.voice.premium.en-US.Nicky',
  'com.apple.voice.enhanced.en-US.Zoe',   // Enhanced — good quality
  'com.apple.voice.enhanced.en-US.Evan',
  'com.apple.voice.enhanced.en-US.Nicky',
  'com.apple.ttsbundle.Samantha-premium',  // Older premium name
  'com.apple.ttsbundle.Samantha-compact',
];

// Web: voice names in priority order (macOS/iOS Safari have the best ones)
const WEB_VOICE_PRIORITY = [
  // macOS / iOS system voices (available in Safari, Chrome on Mac)
  'Samantha',          // macOS — warm, natural
  'Karen',             // Australian English — clear
  'Moira',             // Irish English — warm
  'Tessa',             // South African — pleasant
  'Veena',
  // Chrome neural voices (available in Chrome on Mac/Windows)
  'Google US English',
  'Google UK English Female',
  // Windows voices
  'Microsoft Zira',
  'Microsoft Aria',
  'Microsoft Jenny',
];

/**
 * Waits for browser voices to load, then returns the best available voice.
 * Voices load asynchronously — calling getVoices() synchronously usually
 * returns an empty array on first load.
 */
let cachedWebVoice: SpeechSynthesisVoice | null | undefined = undefined;

function getBestWebVoice(): Promise<SpeechSynthesisVoice | null> {
  return new Promise((resolve) => {
    if (cachedWebVoice !== undefined) {
      resolve(cachedWebVoice);
      return;
    }

    function pickVoice(voices: SpeechSynthesisVoice[]): SpeechSynthesisVoice | null {
      // Try priority list first
      for (const name of WEB_VOICE_PRIORITY) {
        const match = voices.find((v) => v.name.includes(name));
        if (match) return match;
      }
      // Fall back to any en-US voice that isn't the default (default is usually the worst)
      const enUS = voices.filter((v) => v.lang.startsWith('en') && !v.default);
      return enUS[0] ?? voices[0] ?? null;
    }

    const synth = window.speechSynthesis;
    const existing = synth.getVoices();
    if (existing.length > 0) {
      cachedWebVoice = pickVoice(existing);
      resolve(cachedWebVoice);
      return;
    }

    // Voices not loaded yet — wait for the event (fires once on first load)
    const onChanged = () => {
      synth.removeEventListener('voiceschanged', onChanged);
      const loaded = synth.getVoices();
      cachedWebVoice = pickVoice(loaded);
      resolve(cachedWebVoice);
    };
    synth.addEventListener('voiceschanged', onChanged);

    // Safety timeout — if event never fires, resolve with null
    setTimeout(() => {
      synth.removeEventListener('voiceschanged', onChanged);
      if (cachedWebVoice === undefined) {
        cachedWebVoice = null;
        resolve(null);
      }
    }, 3000);
  });
}

async function findPremiumVoice(): Promise<string | undefined> {
  if (Platform.OS === 'web') return undefined; // web uses getBestWebVoice() instead
  try {
    const voices = await Speech.getAvailableVoicesAsync();
    for (const preferred of PREMIUM_VOICES_IOS) {
      if (voices.find((v) => v.identifier === preferred)) return preferred;
    }
  } catch {
    /* ignore */
  }
  return undefined;
}

function speakText(
  text: string,
  voiceId: string | undefined,
  onDone: () => void
): () => void {
  let cancelled = false;

  if (Platform.OS === 'web' && typeof window !== 'undefined' && window.speechSynthesis) {
    window.speechSynthesis.cancel();

    // Async: wait for voices to load before speaking
    getBestWebVoice().then((voice) => {
      if (cancelled) return;
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.rate = 0.88;   // slightly slower than default — unhurried
      utterance.pitch = 0.95;  // slightly lower — warmer tone
      utterance.volume = 0.92;
      if (voice) utterance.voice = voice;
      utterance.onend = () => { if (!cancelled) onDone(); };
      utterance.onerror = () => { if (!cancelled) onDone(); };
      window.speechSynthesis.speak(utterance);
    });
  } else {
    Speech.speak(text, {
      voice: voiceId,
      rate: 0.48,    // AVSpeechSynthesizer rate (0=slowest, 1=fastest, default~0.5)
      pitch: 0.95,
      volume: 0.9,
      onDone: () => { if (!cancelled) onDone(); },
      onError: () => { if (!cancelled) onDone(); },
    });
  }

  return () => {
    cancelled = true;
    if (Platform.OS === 'web' && typeof window !== 'undefined') {
      window.speechSynthesis?.cancel();
    } else {
      Speech.stop();
    }
  };
}

// ─── Hook ─────────────────────────────────────────────────────────────────────
export function useVoiceEngine({
  onUserTurnComplete,
  onSessionEnd,
  onLiveTranscript,
  silenceThresholdMs = 800,
}: VoiceEngineOptions): VoiceEngineState {
  const [voiceState, setVoiceState] = useState<VoiceState>('idle');
  const [amplitude, setAmplitude] = useState(0);
  const [agentText, setAgentText] = useState('');
  const [transcriptLines, setTranscriptLines] = useState<string[]>([]);
  const [liveTranscript, setLiveTranscript] = useState('');
  const [isPermissionGranted, setIsPermissionGranted] = useState<boolean | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Refs that survive re-renders without causing them
  const voiceStateRef = useRef<VoiceState>('idle');
  const recognitionRef = useRef<SpeechRecognitionInstance | null>(null);
  const silenceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const amplitudeTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const cancelTTSRef = useRef<(() => void) | null>(null);
  const premiumVoiceRef = useRef<string | undefined>(undefined);
  const currentTurnTranscriptRef = useRef('');
  const isStartedRef = useRef(false);

  function updateVoiceState(s: VoiceState) {
    voiceStateRef.current = s;
    setVoiceState(s);
  }

  // ── Amplitude polling ──────────────────────────────────────────────────────
  function startAmplitudePolling() {
    if (amplitudeTimerRef.current) return;
    amplitudeTimerRef.current = setInterval(() => {
      if (analyserRef.current) {
        const amp = readAmplitude(analyserRef.current);
        setAmplitude(amp);
      }
    }, 50);
  }

  function stopAmplitudePolling() {
    if (amplitudeTimerRef.current) {
      clearInterval(amplitudeTimerRef.current);
      amplitudeTimerRef.current = null;
    }
    setAmplitude(0);
  }

  // ── Silence detection ──────────────────────────────────────────────────────
  function resetSilenceTimer() {
    if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);
    silenceTimerRef.current = setTimeout(() => {
      if (voiceStateRef.current === 'listening') {
        handleSilenceDetected();
      }
    }, silenceThresholdMs);
  }

  function clearSilenceTimer() {
    if (silenceTimerRef.current) {
      clearTimeout(silenceTimerRef.current);
      silenceTimerRef.current = null;
    }
  }

  // ── STT ───────────────────────────────────────────────────────────────────
  function startListening() {
    const Ctor = getSpeechRecognitionCtor();
    if (!Ctor) {
      // No STT available — simulate with silence after 4s for demo
      setError(null);
      updateVoiceState('listening');
      startAmplitudePolling();
      silenceTimerRef.current = setTimeout(() => {
        if (voiceStateRef.current === 'listening') handleSilenceDetected();
      }, 4000);
      return;
    }

    const rec = new Ctor();
    rec.continuous = true;
    rec.interimResults = true;
    rec.lang = 'en-US';
    recognitionRef.current = rec;
    currentTurnTranscriptRef.current = '';

    rec.onresult = (e: SpeechRecognitionEvent) => {
      let interim = '';
      let final = '';
      for (let i = e.resultIndex; i < e.results.length; i++) {
        const t = e.results[i][0].transcript;
        if (e.results[i].isFinal) {
          final += t;
        } else {
          interim += t;
        }
      }
      const combined = (currentTurnTranscriptRef.current + final).trim();
      if (final) currentTurnTranscriptRef.current = combined;
      const display = combined + (interim ? ' ' + interim : '');
      setLiveTranscript(display);
      onLiveTranscript?.(display);
      resetSilenceTimer(); // voice activity — reset silence clock
    };

    rec.onerror = (e: SpeechRecognitionErrorEvent) => {
      if (e.error === 'not-allowed') {
        setIsPermissionGranted(false);
        setError('Microphone access is required for voice sessions.');
      } else if (e.error !== 'aborted' && e.error !== 'no-speech') {
        setError(`Voice recognition error: ${e.error}`);
      }
    };

    rec.onend = () => {
      // Auto-restarts if still listening (browser stops after silence)
      if (voiceStateRef.current === 'listening') {
        try { rec.start(); } catch { /* already started */ }
      }
    };

    try {
      rec.start();
      updateVoiceState('listening');
      startAmplitudePolling();
      setIsPermissionGranted(true);
      // Start silence timer immediately so an initial long pause still progresses
      resetSilenceTimer();
    } catch (err) {
      setError('Could not start voice recognition.');
    }
  }

  function stopListening() {
    clearSilenceTimer();
    stopAmplitudePolling();
    const rec = recognitionRef.current;
    if (rec) {
      rec.onend = null;
      try { rec.abort(); } catch { /* ignore */ }
      recognitionRef.current = null;
    }
    setLiveTranscript('');
  }

  // ── Agent speaking ─────────────────────────────────────────────────────────
  function agentSpeak(text: string, onComplete: () => void) {
    if (cancelTTSRef.current) cancelTTSRef.current();
    setAgentText(text);
    updateVoiceState('speaking');
    cancelTTSRef.current = speakText(text, premiumVoiceRef.current, onComplete);
  }

  // ── Turn handling ──────────────────────────────────────────────────────────
  async function handleSilenceDetected() {
    if (voiceStateRef.current !== 'listening') return;
    clearSilenceTimer();
    stopListening();

    const transcript = currentTurnTranscriptRef.current || '…';
    setTranscriptLines((prev) => (transcript.trim() ? [...prev, transcript] : prev));
    currentTurnTranscriptRef.current = '';

    updateVoiceState('processing');

    try {
      const agentResponse = await onUserTurnComplete(transcript);
      if (agentResponse === null) {
        onSessionEnd();
        return;
      }
      agentSpeak(agentResponse, () => {
        if (voiceStateRef.current !== 'paused' && voiceStateRef.current !== 'ended') {
          startListening();
        }
      });
    } catch (err) {
      setError('Agent error. Please try again.');
      updateVoiceState('idle');
    }
  }

  // ── Audio setup ────────────────────────────────────────────────────────────
  async function setupAudio() {
    const result = await createAmplitudeAnalyser();
    if (result) {
      analyserRef.current = result.analyser;
      streamRef.current = result.stream;
      audioContextRef.current = result.context;
      setIsPermissionGranted(true);
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────
  const start = useCallback(async () => {
    if (isStartedRef.current) return;
    isStartedRef.current = true;
    premiumVoiceRef.current = await findPremiumVoice();
    await setupAudio();
  }, []);

  const pause = useCallback(() => {
    if (voiceStateRef.current === 'listening') {
      clearSilenceTimer();
      stopListening();
    }
    if (cancelTTSRef.current) cancelTTSRef.current();
    updateVoiceState('paused');
  }, []);

  const resume = useCallback(() => {
    if (voiceStateRef.current !== 'paused') return;
    startListening();
  }, []);

  const end = useCallback(() => {
    clearSilenceTimer();
    stopListening();
    stopAmplitudePolling();
    if (cancelTTSRef.current) cancelTTSRef.current();
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((t) => t.stop());
      streamRef.current = null;
    }
    if (audioContextRef.current) {
      audioContextRef.current.close();
      audioContextRef.current = null;
    }
    updateVoiceState('ended');
    isStartedRef.current = false;
  }, []);

  // ── Cleanup on unmount ─────────────────────────────────────────────────────
  useEffect(() => {
    return () => {
      clearSilenceTimer();
      stopAmplitudePolling();
      if (recognitionRef.current) {
        recognitionRef.current.onend = null;
        try { recognitionRef.current.abort(); } catch { /* ignore */ }
      }
      if (cancelTTSRef.current) cancelTTSRef.current();
      if (streamRef.current) {
        streamRef.current.getTracks().forEach((t) => t.stop());
      }
      if (audioContextRef.current) {
        audioContextRef.current.close();
      }
    };
  }, []);

  /**
   * Imperatively make the agent speak `text`, then hand control back
   * to the user (starts STT listening when TTS finishes).
   * Use this to trigger the opening line after `start()` resolves.
   */
  const speakAgent = useCallback((text: string) => {
    agentSpeak(text, () => {
      if (voiceStateRef.current !== 'paused' && voiceStateRef.current !== 'ended') {
        startListening();
      }
    });
  }, []);

  return {
    voiceState,
    amplitude,
    agentText,
    transcriptLines,
    liveTranscript,
    isPermissionGranted,
    error,
    start,
    speakAgent,
    pause,
    resume,
    end,
  };
}
