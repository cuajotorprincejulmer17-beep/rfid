import NetInfo from '@react-native-community/netinfo';
import { useEffect, useState } from 'react';

/** true = reachable, false = offline, null = not yet known. Never treat null as offline. */
export function useOnline(): boolean | null {
  const [online, setOnline] = useState<boolean | null>(null);
  useEffect(() => {
    return NetInfo.addEventListener((s) => {
      setOnline(s.isInternetReachable === null ? (s.isConnected ?? null) : s.isInternetReachable);
    });
  }, []);
  return online;
}
