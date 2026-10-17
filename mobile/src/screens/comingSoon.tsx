import React from 'react';
import { AppText } from '../components/AppText';
import { Screen } from '../components/Screen';
import { StateView } from '../components/StateView';

/** Honest placeholder for a destination whose stage has not been built yet. Stores and shows nothing. */
export function comingSoon(title: string, stage: number, message: string, underHeader: boolean) {
  return function ComingSoon() {
    return (
      <Screen inset={!underHeader}>
        {underHeader ? null : <AppText variant="title">{title}</AppText>}
        <StateView kind="empty" title="Not built yet" message={`${message} Arrives in Stage ${stage}.`} />
      </Screen>
    );
  };
}
