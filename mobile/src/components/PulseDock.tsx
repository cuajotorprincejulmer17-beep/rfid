import React from 'react';
import { View } from 'react-native';
import { BTN, BTN_TOP, CRADLE } from '../navigation/pulseCore';
import { mix } from '../theme/color';
import { useTheme } from '../theme/ThemeProvider';
import { PulseButton } from './PulseButton';

/** The raised, circular cradle that visually seats Pulse Core in the bottom dock. */
export function PulseDock({ closing, onPress }: { closing: boolean; onPress: () => void }) {
  const { theme } = useTheme();
  const centerY = BTN_TOP + BTN / 2;
  return (
    <>
      <View
        pointerEvents="none"
        style={{ position: 'absolute', alignSelf: 'center', top: centerY - CRADLE / 2, width: CRADLE, height: CRADLE / 2, overflow: 'hidden' }}
      >
        <View
          style={{
            width: CRADLE, height: CRADLE, borderRadius: CRADLE / 2, backgroundColor: theme.surface,
            borderWidth: 1, borderColor: mix(theme.border, theme.primary, 0.7),
          }}
        />
      </View>
      <View style={{ position: 'absolute', alignSelf: 'center', top: BTN_TOP }}>
        <PulseButton closing={closing} onPress={onPress} />
      </View>
    </>
  );
}
