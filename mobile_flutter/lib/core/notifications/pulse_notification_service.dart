import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';
import '../api/api_client.dart';

/// Receives Firebase Cloud Messaging events for the student app.
///
/// Firebase supplies notifications in the background. When the app is open,
/// Android does not show a system banner by default, so this service displays a
/// local notification for the same message. Registration with the school API
/// is kept separate: it needs a server that can send FCM notifications.
class PulseNotificationService {
  PulseNotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  static const _channel = AndroidNotificationChannel(
    'pulse_updates',
    'PULSE updates',
    description: 'Attendance, campus and verified activity updates.',
    importance: Importance.high,
  );

  /// Requests notification permission and configures foreground delivery.
  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      settings: const InitializationSettings(android: android),
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_channel);

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _foregroundSubscription ??= FirebaseMessaging.onMessage.listen(
      _showForeground,
    );
  }

  /// Sends this installation's FCM token to the authenticated school server.
  ///
  /// The API call intentionally fails silently here: FCM delivery is optional
  /// and must never interrupt sign-in or the rest of the student app.
  Future<void> registerCurrentDevice(ApiClient api) async {
    try {
      _tokenRefreshSubscription ??= _messaging.onRegistered.listen(
        (installationId) => unawaited(_registerToken(api, installationId)),
      );
      await _messaging.register();
    } catch (error, stackTrace) {
      // Push registration is optional and must never surface as an unhandled
      // error while the student is signing in.
      debugPrint('PULSE Firebase registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _registerToken(ApiClient api, String token) async {
    try {
      await api.postJson('/devices', <String, dynamic>{
        'token': token,
        'platform': 'android',
        'transport': 'fcm',
      });
    } catch (error, stackTrace) {
      // The current server may still be configured for Expo tokens. Do not
      // represent notifications as enabled until its push sender is migrated.
      debugPrint('PULSE push registration was not accepted: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'PULSE',
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'pulse_updates',
          'PULSE updates',
          channelDescription:
              'Attendance, campus and verified activity updates.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: message.data['notificationId']?.toString(),
    );
  }

  void dispose() {
    _foregroundSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
  }
}

/// FCM invokes this from a background isolate. It must be a top-level entry
/// point and must initialize Firebase before touching the message payload.
@pragma('vm:entry-point')
Future<void> pulseFirebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
