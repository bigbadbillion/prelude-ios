import { Feather } from '@expo/vector-icons';
import React from 'react';
import { StyleSheet, Text, View, useColorScheme } from 'react-native';
import type { CardType } from '@/context/AppContext';
import { getColors } from '@/constants/colors';
import { TypeScale } from '@/constants/typography';

interface BriefCardProps {
  type: CardType;
  text: string;
  isUserWords?: boolean;
}

const cardConfig: Record<CardType, { icon: string; label: string }> = {
  emotionalState: { icon: 'activity', label: 'How I showed up' },
  mainConcern: { icon: 'cloud', label: 'Weighing on me' },
  keyEmotion: { icon: 'heart', label: 'Key emotion' },
  whatToSay: { icon: 'message-circle', label: 'What I need to say' },
  unresolvedThread: { icon: 'git-pull-request', label: 'Unresolved thread' },
  therapyGoal: { icon: 'compass', label: 'What I hope for today' },
  patternNote: { icon: 'repeat', label: 'A pattern worth noting' },
};

export default function BriefCard({ type, text, isUserWords }: BriefCardProps) {
  const isDark = useColorScheme() === 'dark';
  const colors = getColors(isDark);
  const config = cardConfig[type] ?? { icon: 'circle', label: 'Note' };

  return (
    <View
      style={[
        styles.card,
        {
          backgroundColor: isDark
            ? 'rgba(37,32,24,0.85)'
            : 'rgba(240,235,227,0.85)',
          borderColor: colors.border,
        },
      ]}
    >
      {/* Header row */}
      <View style={styles.header}>
        <Feather
          name={config.icon as any}
          size={14}
          color={colors.amber}
          style={styles.icon}
        />
        <Text style={[styles.label, { color: colors.tertiary }]}>
          {config.label.toUpperCase()}
        </Text>
      </View>

      {/* Content */}
      {isUserWords ? (
        <View style={[styles.quotedWrapper, { borderLeftColor: colors.amber }]}>
          <Text
            style={[
              styles.quotedText,
              { color: colors.primary, ...TypeScale.cardBody },
            ]}
          >
            {text}
          </Text>
        </View>
      ) : (
        <Text
          style={[
            styles.bodyText,
            { color: colors.primary, ...TypeScale.cardBody },
          ]}
        >
          {text}
        </Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: 20,
    borderWidth: 1,
    padding: 22,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.12,
    shadowRadius: 12,
    elevation: 3,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 14,
  },
  icon: {
    marginRight: 8,
  },
  label: {
    fontSize: 11,
    letterSpacing: 1.2,
    fontWeight: '500',
  },
  bodyText: {
    lineHeight: 26,
  },
  quotedWrapper: {
    borderLeftWidth: 2,
    paddingLeft: 14,
  },
  quotedText: {
    fontStyle: 'italic',
    lineHeight: 26,
    fontSize: 17,
  },
});
