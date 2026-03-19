import AsyncStorage from '@react-native-async-storage/async-storage';
import React, { createContext, useCallback, useContext, useEffect, useState } from 'react';

// Types
export type EmotionLabel =
  | 'anxious'
  | 'sad'
  | 'angry'
  | 'confused'
  | 'hopeful'
  | 'overwhelmed'
  | 'frustrated'
  | 'neutral'
  | 'grieving';

export type CardType =
  | 'emotionalState'
  | 'mainConcern'
  | 'keyEmotion'
  | 'whatToSay'
  | 'unresolvedThread'
  | 'therapyGoal'
  | 'patternNote';

export type VoiceState =
  | 'idle'
  | 'listening'
  | 'processing'
  | 'speaking'
  | 'paused'
  | 'ended';

export interface Insight {
  id: string;
  text: string;
  emotion: EmotionLabel;
  theme: string;
  importance: 1 | 2 | 3;
  sessionId: string;
  timestamp: string;
}

export interface SessionCard {
  id: string;
  type: CardType;
  text: string;
  sessionId: string;
}

export interface SessionBrief {
  id: string;
  sessionId: string;
  generatedAt: string;
  emotionalState: string;
  themes: string[];
  patientWords: string;
  focusItems: string[];
  patternNote?: string;
}

export interface Session {
  id: string;
  startedAt: string;
  completedAt?: string;
  durationSeconds: number;
  phase: string;
  insights: Insight[];
  cards: SessionCard[];
  brief?: SessionBrief;
  dominantEmotion?: EmotionLabel;
}

export interface WeeklyBrief {
  id: string;
  weekStart: string;
  summary: string;
  themes: string[];
  dominantEmotion: EmotionLabel;
  suggestions: string[];
  sessionIds: string[];
  generatedAt: string;
}

// Emotion to color mapping
export const emotionColors: Record<EmotionLabel, string> = {
  anxious: '#B5835A',
  sad: '#6B8CAE',
  angry: '#AE6B6B',
  confused: '#8C7BAE',
  hopeful: '#7A9E7E',
  overwhelmed: '#AE8C6B',
  frustrated: '#C4734B',
  neutral: '#9E9485',
  grieving: '#7B8CAE',
};

// Mock data for demo
function generateMockSessions(): Session[] {
  const sessions: Session[] = [
    {
      id: '1',
      startedAt: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
      completedAt: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000 + 9 * 60 * 1000).toISOString(),
      durationSeconds: 540,
      phase: 'closing',
      dominantEmotion: 'anxious',
      insights: [],
      cards: [],
      brief: {
        id: 'b1',
        sessionId: '1',
        generatedAt: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
        emotionalState: 'Tender and a little fragile',
        themes: ['Work pressure', 'Family distance', 'Self-doubt'],
        patientWords: "I keep feeling like I'm holding everything together but I'm about to drop it all.",
        focusItems: [
          'The argument with my manager last Tuesday',
          'Why I cancel plans when I feel overwhelmed',
          'Whether I actually want to stay in this role',
        ],
        patternNote: 'This is the third time you\'ve described feeling like "the responsible one" who can\'t ask for help.',
      },
    },
    {
      id: '2',
      startedAt: new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString(),
      completedAt: new Date(Date.now() - 14 * 24 * 60 * 60 * 1000 + 11 * 60 * 1000).toISOString(),
      durationSeconds: 660,
      phase: 'closing',
      dominantEmotion: 'hopeful',
      insights: [],
      cards: [],
      brief: {
        id: 'b2',
        sessionId: '2',
        generatedAt: new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString(),
        emotionalState: 'Cautiously hopeful',
        themes: ['New opportunities', 'Relationship patterns', 'Identity'],
        patientWords: "I think I've been chasing what I thought I should want, not what I actually want.",
        focusItems: [
          'The decision about the new job offer',
          'How I talk to myself when things go wrong',
          'What "rest" actually means to me',
        ],
      },
    },
    {
      id: '3',
      startedAt: new Date(Date.now() - 21 * 24 * 60 * 60 * 1000).toISOString(),
      completedAt: new Date(Date.now() - 21 * 24 * 60 * 60 * 1000 + 8 * 60 * 1000).toISOString(),
      durationSeconds: 480,
      phase: 'closing',
      dominantEmotion: 'sad',
      insights: [],
      cards: [],
      brief: {
        id: 'b3',
        sessionId: '3',
        generatedAt: new Date(Date.now() - 21 * 24 * 60 * 60 * 1000).toISOString(),
        emotionalState: 'Carrying a quiet sadness',
        themes: ['Grief', 'Disconnection', 'Longing'],
        patientWords: "I miss who I was before everything changed.",
        focusItems: [
          'My relationship with my father',
          'The version of myself I feel I\'ve lost',
          'Whether I\'m allowed to still be sad about this',
        ],
      },
    },
  ];
  return sessions;
}

function generateMockWeeklyBrief(): WeeklyBrief {
  return {
    id: 'w1',
    weekStart: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
    summary:
      "This week carried a familiar tension — the gap between how capable you appear to others and how precarious things feel from the inside. You returned, again, to the theme of carrying responsibility quietly, of being the one who keeps things together while quietly fraying at the edges.\n\nThere was also something new this week: a flicker of clarity about what you actually want, beneath the noise of what you think you should want. That\'s worth sitting with.\n\nYour emotional range moved from anxious at the start of the week to something closer to resolve by the end — not peace, but groundedness.",
    themes: ['Responsibility and burden', 'Authentic desire', 'Emotional self-concealment'],
    dominantEmotion: 'anxious',
    suggestions: ['What would it look like to ask for help from one specific person this week?'],
    sessionIds: ['1'],
    generatedAt: new Date().toISOString(),
  };
}

interface AppContextValue {
  sessions: Session[];
  weeklyBrief: WeeklyBrief | null;
  userName: string;
  voiceState: VoiceState;
  currentSession: Session | null;
  hasSeenDisclaimer: boolean;
  setVoiceState: (state: VoiceState) => void;
  startSession: () => Session;
  endSession: (session: Session) => void;
  setHasSeenDisclaimer: (v: boolean) => void;
  setUserName: (name: string) => void;
}

const AppContext = createContext<AppContextValue | null>(null);

const STORAGE_KEYS = {
  sessions: '@prelude/sessions',
  userName: '@prelude/userName',
  disclaimer: '@prelude/disclaimer',
  weeklyBrief: '@prelude/weeklyBrief',
};

export function AppProvider({ children }: { children: React.ReactNode }) {
  const [sessions, setSessions] = useState<Session[]>([]);
  const [weeklyBrief, setWeeklyBrief] = useState<WeeklyBrief | null>(null);
  const [userName, setUserNameState] = useState('');
  const [voiceState, setVoiceState] = useState<VoiceState>('idle');
  const [currentSession, setCurrentSession] = useState<Session | null>(null);
  const [hasSeenDisclaimer, setHasSeenDisclaimerState] = useState(false);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [storedSessions, storedName, storedDisclaimer, storedWeekly] = await Promise.all([
        AsyncStorage.getItem(STORAGE_KEYS.sessions),
        AsyncStorage.getItem(STORAGE_KEYS.userName),
        AsyncStorage.getItem(STORAGE_KEYS.disclaimer),
        AsyncStorage.getItem(STORAGE_KEYS.weeklyBrief),
      ]);

      if (storedSessions) {
        setSessions(JSON.parse(storedSessions));
      } else {
        // Seed with mock data for demo
        const mock = generateMockSessions();
        setSessions(mock);
        await AsyncStorage.setItem(STORAGE_KEYS.sessions, JSON.stringify(mock));
      }

      if (storedWeekly) {
        setWeeklyBrief(JSON.parse(storedWeekly));
      } else {
        const mock = generateMockWeeklyBrief();
        setWeeklyBrief(mock);
        await AsyncStorage.setItem(STORAGE_KEYS.weeklyBrief, JSON.stringify(mock));
      }

      if (storedName) setUserNameState(storedName);
      if (storedDisclaimer) setHasSeenDisclaimerState(storedDisclaimer === 'true');
    } catch (e) {
      console.error('Failed to load data', e);
    }
  };

  const setUserName = useCallback(async (name: string) => {
    setUserNameState(name);
    await AsyncStorage.setItem(STORAGE_KEYS.userName, name);
  }, []);

  const setHasSeenDisclaimer = useCallback(async (v: boolean) => {
    setHasSeenDisclaimerState(v);
    await AsyncStorage.setItem(STORAGE_KEYS.disclaimer, String(v));
  }, []);

  const startSession = useCallback((): Session => {
    const newSession: Session = {
      id: Date.now().toString() + Math.random().toString(36).substring(2, 9),
      startedAt: new Date().toISOString(),
      durationSeconds: 0,
      phase: 'warmOpen',
      insights: [],
      cards: [],
    };
    setCurrentSession(newSession);
    return newSession;
  }, []);

  const endSession = useCallback(
    async (session: Session) => {
      const completed: Session = {
        ...session,
        completedAt: new Date().toISOString(),
        durationSeconds: Math.round(
          (Date.now() - new Date(session.startedAt).getTime()) / 1000
        ),
        phase: 'closing',
        dominantEmotion: 'neutral',
        brief: {
          id: Date.now().toString(),
          sessionId: session.id,
          generatedAt: new Date().toISOString(),
          emotionalState: 'Reflective and present',
          themes: ['Connection', 'Boundaries', 'Self-awareness'],
          patientWords: "I think I just needed to say it out loud to understand it.",
          focusItems: [
            "The conversation you've been avoiding",
            "What you actually need right now",
            "The pattern worth naming with your therapist",
          ],
        },
      };

      const updated = [completed, ...sessions];
      setSessions(updated);
      setCurrentSession(null);
      setVoiceState('ended');

      try {
        await AsyncStorage.setItem(STORAGE_KEYS.sessions, JSON.stringify(updated));
      } catch (e) {
        console.error('Failed to save session', e);
      }
    },
    [sessions]
  );

  return (
    <AppContext.Provider
      value={{
        sessions,
        weeklyBrief,
        userName,
        voiceState,
        currentSession,
        hasSeenDisclaimer,
        setVoiceState,
        startSession,
        endSession,
        setHasSeenDisclaimer,
        setUserName,
      }}
    >
      {children}
    </AppContext.Provider>
  );
}

export function useApp() {
  const ctx = useContext(AppContext);
  if (!ctx) throw new Error('useApp must be used within AppProvider');
  return ctx;
}
