import React, { useState } from 'react';
import {
  FlatList,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  useColorScheme,
  Platform,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { getColors, PreludeColors } from '@/constants/colors';
import { useApp, type Session } from '@/context/AppContext';
import SessionRow from '@/components/SessionRow';

export default function HistoryScreen() {
  const isDark = useColorScheme() === 'dark';
  const colors = getColors(isDark);
  const insets = useSafeAreaInsets();
  const { sessions } = useApp();

  const webTopPad = Platform.OS === 'web' ? 67 : 0;
  const webBottomPad = Platform.OS === 'web' ? 34 : 0;

  function handleSessionPress(session: Session) {
    router.push({ pathname: '/brief/[id]', params: { id: session.id } });
  }

  return (
    <View
      style={[
        styles.container,
        { backgroundColor: isDark ? PreludeColors.depth.dark : PreludeColors.depth.light },
      ]}
    >
      {/* Header */}
      <View
        style={[
          styles.header,
          {
            paddingTop: insets.top + webTopPad + 16,
            borderBottomColor: colors.border,
          },
        ]}
      >
        <Text style={[styles.title, { color: colors.primary }]}>Sessions</Text>
        <Text style={[styles.subtitle, { color: colors.secondary }]}>
          {sessions.length} {sessions.length === 1 ? 'reflection' : 'reflections'}
        </Text>
      </View>

      {sessions.length === 0 ? (
        <View style={styles.emptyState}>
          <Text style={[styles.emptyTitle, { color: colors.secondary }]}>
            Your sessions will appear here
          </Text>
          <Text style={[styles.emptyBody, { color: colors.tertiary }]}>
            After each reflection, you'll find your session and brief waiting for you.
          </Text>
        </View>
      ) : (
        <FlatList
          data={sessions}
          keyExtractor={(item) => item.id}
          renderItem={({ item }) => (
            <SessionRow
              session={item}
              onPress={() => handleSessionPress(item)}
            />
          )}
          contentContainerStyle={[
            styles.list,
            {
              paddingBottom: insets.bottom + webBottomPad + 100,
            },
          ]}
          showsVerticalScrollIndicator={false}
          contentInsetAdjustmentBehavior="automatic"
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    paddingHorizontal: 24,
    paddingBottom: 20,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  title: {
    fontSize: 30,
    fontWeight: '400',
    fontFamily: Platform.OS === 'ios' ? 'NewYorkSmall-Regular' : undefined,
    marginBottom: 4,
    letterSpacing: 0.2,
  },
  subtitle: {
    fontSize: 14,
    fontFamily: 'Inter_400Regular',
    fontWeight: '400',
  },
  list: {
    paddingLeft: 0,
  },
  emptyState: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 40,
    gap: 12,
  },
  emptyTitle: {
    fontSize: 18,
    fontWeight: '500',
    textAlign: 'center',
    fontFamily: 'Inter_500Medium',
  },
  emptyBody: {
    fontSize: 15,
    textAlign: 'center',
    lineHeight: 22,
    fontFamily: 'Inter_400Regular',
  },
});
