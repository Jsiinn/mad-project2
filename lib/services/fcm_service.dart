import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize FCM handlers for all app states
  void initialize() {
    // Foreground messages — app is open
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM Foreground: ${message.notification?.title}');
      // In a real app, show in-app notification banner here
      _handleMessage(message);
    });

    // Background → app opened via notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM Opened from background: ${message.data}');
      _handleMessage(message);
    });

    // Terminated → app launched from notification tap
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('FCM Launched app: ${message.data}');
        _handleMessage(message);
      }
    });
  }

  void _handleMessage(RemoteMessage message) {
    final type = message.data['type'];
    switch (type) {
      case 'challenge_alert':
        // Navigate to challenge screen
        debugPrint('Challenge alert: ${message.data['challengeId']}');
        break;
      case 'milestone':
        debugPrint('Milestone achieved: ${message.data['milestone']}');
        break;
      case 'reminder':
        debugPrint('Workout reminder received');
        break;
      default:
        debugPrint('Unknown FCM type: $type');
    }
  }
}
