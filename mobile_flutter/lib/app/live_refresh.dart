import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_controller.dart';
import 'app_data.dart';
import 'session.dart';

/// Keeps server data current without push notifications.
///
/// The server's push channel is Expo-only, so the app polls instead: today's
/// attendance and the inbox every [interval] while signed in, and
/// everything when the app returns to the foreground. A tap on the RFID
/// reader therefore shows up within one interval.
class LiveRefresh extends ConsumerStatefulWidget {
  const LiveRefresh({
    super.key,
    required this.child,
    this.interval = const Duration(seconds: 30),
  });

  final Widget child;
  final Duration interval;

  @override
  ConsumerState<LiveRefresh> createState() => _LiveRefreshState();
}

class _LiveRefreshState extends ConsumerState<LiveRefresh> {
  Timer? _timer;
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () {
      if (_signedIn) refreshServerData(ref.invalidate);
      _sync();
    },
    onPause: _stop,
  );

  bool get _signedIn => ref.read(authStatusProvider) == AuthStatus.signedIn;

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _sync();
  }

  @override
  void dispose() {
    _stop();
    _lifecycle.dispose();
    super.dispose();
  }

  void _sync() {
    if (_signedIn) {
      // Providers no screen is watching only refetch when next read, so
      // this costs one request per region actually on screen.
      _timer ??= Timer.periodic(widget.interval, (_) {
        ref.invalidate(todayAttendanceProvider);
        ref.invalidate(recentAttendanceProvider);
        ref.invalidate(unreadCountProvider);
        ref.invalidate(inboxProvider);
      });
    } else {
      _stop();
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStatusProvider, (_, _) => _sync());
    return widget.child;
  }
}
