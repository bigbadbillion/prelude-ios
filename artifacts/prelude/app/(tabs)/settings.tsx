import { Feather } from '@expo/vector-icons';
import * as Speech from 'expo-speech';
import React, { useEffect, useState } from 'react';
import {
  Alert,
  Linking,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
  useColorScheme,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { getColors, PreludeColors } from '@/constants/colors';
import { useApp } from '@/context/AppContext';

type VoiceQuality = 'premium' | 'enhanced' | 'standard' | 'checking';

async function detectVoiceQuality(): Promise<VoiceQuality> {
  if (Platform.OS !== 'ios') return 'standard';
  try {
    const voices = await Speech.getAvailableVoicesAsync();
    if (voices.some((v) => v.identifier.includes('.premium.'))) return 'premium';
    if (voices.some((v) => v.identifier.includes('.enhanced.'))) return 'enhanced';
  } catch {
    /* ignore */
  }
  return 'standard';
}

const VOICE_QUALITY_LABEL: Record<VoiceQuality, string> = {
  premium:  'Premium · Neural',
  enhanced: 'Enhanced',
  standard: 'Standard',
  checking: '···',
};

const VOICE_QUALITY_COLOR: Record<VoiceQuality, string> = {
  premium:  '#7A9E7E',  // preludeSage — good
  enhanced: '#7A9E7E',
  standard: '#C8873A',  // preludeAmber — needs attention
  checking: '#999',
};

interface SettingsRowProps {
  icon: string;
  label: string;
  value?: string;
  valueColor?: string;
  onPress?: () => void;
  destructive?: boolean;
  chevron?: boolean;
  colors: ReturnType<typeof getColors>;
  isDark: boolean;
  sublabel?: string;
}

function SettingsRow({
  icon,
  label,
  value,
  valueColor,
  onPress,
  destructive,
  chevron = true,
  colors,
  isDark,
  sublabel,
}: SettingsRowProps) {
  return (
    <TouchableOpacity
      onPress={onPress}
      activeOpacity={onPress ? 0.6 : 1}
      style={[styles.row, { borderBottomColor: colors.border }]}
      accessibilityRole={onPress ? 'button' : 'text'}
      accessibilityLabel={label}
    >
      <View style={styles.rowLeft}>
        <Feather
          name={icon as any}
          size={17}
          color={destructive ? '#AE6B6B' : colors.amber}
          style={styles.rowIcon}
        />
        <View style={{ flex: 1 }}>
          <Text
            style={[
              styles.rowLabel,
              { color: destructive ? '#AE6B6B' : colors.primary },
            ]}
          >
            {label}
          </Text>
          {sublabel ? (
            <Text style={[styles.rowSublabel, { color: colors.tertiary }]}>
              {sublabel}
            </Text>
          ) : null}
        </View>
      </View>
      <View style={styles.rowRight}>
        {value ? (
          <Text
            style={[
              styles.rowValue,
              { color: valueColor ?? colors.secondary },
            ]}
            numberOfLines={1}
          >
            {value}
          </Text>
        ) : null}
        {chevron && onPress ? (
          <Feather name="chevron-right" size={15} color={colors.tertiary} />
        ) : null}
      </View>
    </TouchableOpacity>
  );
}

interface VoiceSectionProps {
  colors: ReturnType<typeof getColors>;
  isDark: boolean;
}

function VoiceSection({ colors, isDark }: VoiceSectionProps) {
  const [quality, setQuality] = useState<VoiceQuality>('checking');

  useEffect(() => {
    detectVoiceQuality().then(setQuality);
  }, []);

  function openVoiceSettings() {
    if (Platform.OS !== 'ios') return;

    // iOS 26 renamed "Spoken Content" to "Read & Speak".
    // Platform.Version on iOS is a string like "18.3.2" or "26.0".
    const majorVersion =
      typeof Platform.Version === 'string'
        ? parseInt(Platform.Version.split('.')[0], 10)
        : (Platform.Version as number);

    // iOS 26 uses new naming; iOS 18 and earlier use "Spoken Content"
    const sectionName = majorVersion >= 19 ? 'Read & Speak' : 'Spoken Content';

    const VOICE_INSTRUCTIONS =
      `In the Settings app:\n\n` +
      `Accessibility → ${sectionName} → Voices → English\n\n` +
      `Tap "Zoe" or "Evan", then tap the download button next to it. ` +
      `Once installed, Prelude will use it automatically.`;

    // iOS 26 has revoked most prefs: deep links. Try anyway in case they work,
    // then fall back to showing clear written instructions.
    Linking.openURL('prefs:root=ACCESSIBILITY&path=SPEECH_TITLE/QuickSpeakAccents')
      .catch(() => Linking.openURL('prefs:root=ACCESSIBILITY&path=SPEECH_TITLE'))
      .catch(() => Linking.openURL('prefs:root=ACCESSIBILITY'))
      .catch(() => {
        Alert.alert('Download a Premium Voice', VOICE_INSTRUCTIONS, [
          { text: 'Got it' },
        ]);
      });
  }

  const needsImprovement = quality === 'standard';

  return (
    <>
      <Text style={[styles.sectionLabel, { color: colors.tertiary }]}>VOICE</Text>
      <View
        style={[
          styles.section,
          {
            backgroundColor: colors.surface,
            borderColor: colors.border,
          },
        ]}
      >
        <SettingsRow
          icon="mic"
          label="Voice Quality"
          value={VOICE_QUALITY_LABEL[quality]}
          valueColor={VOICE_QUALITY_COLOR[quality]}
          onPress={undefined}
          chevron={false}
          colors={colors}
          isDark={isDark}
        />

        {Platform.OS === 'ios' && needsImprovement ? (
          <SettingsRow
            icon="download"
            label="Improve Voice"
            sublabel="Opens Accessibility → Spoken Content → Voices"
            onPress={openVoiceSettings}
            colors={colors}
            isDark={isDark}
          />
        ) : null}

        {Platform.OS === 'ios' && !needsImprovement && quality !== 'checking' ? (
          <SettingsRow
            icon="check-circle"
            label="Premium Voice Active"
            sublabel="Prelude will speak in high-quality neural voice"
            onPress={undefined}
            chevron={false}
            colors={colors}
            isDark={isDark}
          />
        ) : null}

        {Platform.OS === 'web' ? (
          <SettingsRow
            icon="info"
            label="Voice on Web"
            sublabel="Web preview uses your browser's built-in voices. The iOS app uses Apple neural TTS."
            onPress={undefined}
            chevron={false}
            colors={colors}
            isDark={isDark}
          />
        ) : null}
      </View>
    </>
  );
}

export default function SettingsScreen() {
  const isDark = useColorScheme() === 'dark';
  const colors = getColors(isDark);
  const insets = useSafeAreaInsets();
  const { userName, setUserName } = useApp();
  const [editingName, setEditingName] = useState(false);
  const [nameInput, setNameInput] = useState(userName);

  const webTopPad = Platform.OS === 'web' ? 67 : 0;
  const webBottomPad = Platform.OS === 'web' ? 34 : 0;

  function showDisclaimer() {
    Alert.alert(
      'About Prelude',
      'Prelude is a personal reflection and preparation tool. It is not therapy, and it is not a substitute for professional mental health care.\n\nIf you are in crisis, please contact the 988 Suicide & Crisis Lifeline by calling or texting 988.',
      [{ text: 'Understood', style: 'default' }]
    );
  }

  function call988() {
    Alert.alert(
      '988 Suicide & Crisis Lifeline',
      'You can call or text 988 to reach the Suicide & Crisis Lifeline. Would you like to call now?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Call 988', onPress: () => Linking.openURL('tel:988') },
      ]
    );
  }

  function saveName() {
    setUserName(nameInput.trim());
    setEditingName(false);
  }

  return (
    <View
      style={[
        styles.container,
        { backgroundColor: isDark ? PreludeColors.depth.dark : PreludeColors.depth.light },
      ]}
    >
      <View
        style={[
          styles.header,
          {
            paddingTop: insets.top + webTopPad + 16,
            borderBottomColor: colors.border,
          },
        ]}
      >
        <Text style={[styles.title, { color: colors.primary }]}>Settings</Text>
      </View>

      <ScrollView
        style={styles.scroll}
        contentContainerStyle={{
          paddingBottom: insets.bottom + webBottomPad + 100,
        }}
        showsVerticalScrollIndicator={false}
        contentInsetAdjustmentBehavior="automatic"
      >
        {/* Profile */}
        <Text style={[styles.sectionLabel, { color: colors.tertiary }]}>PROFILE</Text>
        <View
          style={[
            styles.section,
            {
              backgroundColor: colors.surface,
              borderColor: colors.border,
            },
          ]}
        >
          {editingName ? (
            <View style={[styles.row, { borderBottomColor: colors.border }]}>
              <TextInput
                style={[styles.nameInput, { color: colors.primary, borderBottomColor: colors.amber }]}
                value={nameInput}
                onChangeText={setNameInput}
                autoFocus
                placeholder="Your first name"
                placeholderTextColor={colors.tertiary}
                returnKeyType="done"
                onSubmitEditing={saveName}
                onBlur={saveName}
                maxLength={40}
              />
            </View>
          ) : (
            <SettingsRow
              icon="user"
              label="Your Name"
              value={userName || 'Not set'}
              onPress={() => {
                setNameInput(userName);
                setEditingName(true);
              }}
              colors={colors}
              isDark={isDark}
            />
          )}
        </View>

        {/* Voice */}
        <VoiceSection colors={colors} isDark={isDark} />

        {/* AI & Privacy */}
        <Text style={[styles.sectionLabel, { color: colors.tertiary }]}>
          AI & PRIVACY
        </Text>
        <View
          style={[
            styles.section,
            {
              backgroundColor: colors.surface,
              borderColor: colors.border,
            },
          ]}
        >
          <SettingsRow
            icon="cpu"
            label="Apple Intelligence"
            value="On-Device"
            onPress={undefined}
            chevron={false}
            colors={colors}
            isDark={isDark}
          />
          <SettingsRow
            icon="lock"
            label="Data Storage"
            value="On Device Only"
            onPress={undefined}
            chevron={false}
            colors={colors}
            isDark={isDark}
          />
          <SettingsRow
            icon="wifi-off"
            label="Network Access"
            value="Never During Sessions"
            onPress={undefined}
            chevron={false}
            colors={colors}
            isDark={isDark}
          />
        </View>

        {/* Support */}
        <Text style={[styles.sectionLabel, { color: colors.tertiary }]}>SUPPORT</Text>
        <View
          style={[
            styles.section,
            {
              backgroundColor: colors.surface,
              borderColor: colors.border,
            },
          ]}
        >
          <SettingsRow
            icon="info"
            label="About Prelude"
            onPress={showDisclaimer}
            colors={colors}
            isDark={isDark}
          />
          <SettingsRow
            icon="phone"
            label="988 Crisis Lifeline"
            value="Call or Text"
            onPress={call988}
            colors={colors}
            isDark={isDark}
          />
        </View>

        <View style={styles.wordmark}>
          <Text style={[styles.wordmarkText, { color: colors.tertiary }]}>
            Prelude
          </Text>
          <Text style={[styles.versionText, { color: colors.tertiary }]}>
            Version 1.0
          </Text>
        </View>
      </ScrollView>
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
    letterSpacing: 0.2,
  },
  scroll: {
    flex: 1,
  },
  sectionLabel: {
    fontSize: 11,
    fontWeight: '500',
    letterSpacing: 1.2,
    fontFamily: 'Inter_500Medium',
    paddingHorizontal: 24,
    paddingTop: 28,
    paddingBottom: 10,
  },
  section: {
    marginHorizontal: 20,
    borderRadius: 16,
    borderWidth: StyleSheet.hairlineWidth,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.06,
    shadowRadius: 8,
    elevation: 1,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 18,
    paddingVertical: 15,
    minHeight: 52,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  rowLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  rowIcon: {
    marginRight: 12,
    width: 20,
  },
  rowLabel: {
    fontSize: 15,
    fontFamily: 'Inter_400Regular',
  },
  rowSublabel: {
    fontSize: 12,
    fontFamily: 'Inter_400Regular',
    marginTop: 2,
    lineHeight: 16,
  },
  rowRight: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    maxWidth: 160,
  },
  rowValue: {
    fontSize: 14,
    fontFamily: 'Inter_400Regular',
    textAlign: 'right',
  },
  nameInput: {
    flex: 1,
    fontSize: 15,
    fontFamily: 'Inter_400Regular',
    paddingVertical: 8,
    borderBottomWidth: 1,
    marginHorizontal: 18,
    marginVertical: 10,
  },
  wordmark: {
    alignItems: 'center',
    paddingTop: 40,
    paddingBottom: 20,
    gap: 4,
  },
  wordmarkText: {
    fontSize: 17,
    fontFamily: Platform.OS === 'ios' ? 'NewYorkSmall-Regular' : undefined,
    letterSpacing: 1.5,
  },
  versionText: {
    fontSize: 11,
    fontFamily: 'Inter_400Regular',
  },
});
