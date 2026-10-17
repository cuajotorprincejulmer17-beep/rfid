import React from 'react';
import { ScrollView, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../theme/ThemeProvider';
import { spacing } from '../theme/tokens';

interface Props {
  children: React.ReactNode;
  scroll?: boolean;
  /** false when a native header already sits above (stack screens). */
  inset?: boolean;
}

export function Screen({ children, scroll = true, inset = true }: Props) {
  const { theme } = useTheme();
  const insets = useSafeAreaInsets();
  const pad = {
    paddingTop: (inset ? insets.top : 0) + spacing.lg,
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.xl,
  };
  if (!scroll) return <View style={[{ flex: 1, backgroundColor: theme.bg }, pad]}>{children}</View>;
  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: theme.bg }}
      contentContainerStyle={[pad, { gap: spacing.lg }]}
      keyboardShouldPersistTaps="handled"
    >
      {children}
    </ScrollView>
  );
}
