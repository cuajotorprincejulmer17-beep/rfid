import React from 'react';
import { Text, TextProps, TextStyle } from 'react-native';
import { useTheme } from '../theme/ThemeProvider';

type Variant = 'title' | 'heading' | 'body' | 'caption';
const styles: Record<Variant, TextStyle> = {
  title: { fontSize: 26, fontWeight: '700', lineHeight: 32 },
  heading: { fontSize: 18, fontWeight: '600', lineHeight: 24 },
  body: { fontSize: 16, lineHeight: 22 },
  caption: { fontSize: 14, lineHeight: 19 },
};

interface Props extends TextProps {
  variant?: Variant;
  muted?: boolean;
  color?: string;
}

export function AppText({ variant = 'body', muted, color, style, ...rest }: Props) {
  const { theme } = useTheme();
  return (
    <Text
      {...rest}
      style={[styles[variant], { color: color ?? (muted ? theme.textMuted : theme.text) }, style]}
    />
  );
}
