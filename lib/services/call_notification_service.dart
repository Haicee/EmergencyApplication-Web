import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_database/firebase_database.dart';

/// Handles push notifications for incoming calls, including full-screen alerts on Android.
class CallNotificationService {
  static final CallNotificationService _instance = CallNotificationService._internal();
  factory CallNotificationService() => _instance;
  CallNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();

  static const String androidChannelId = 'emergency_calls';
  static const String androidChannelName = 'Emergency Calls';
  static const String androidChannelDesc = 'High priority incoming emergency calls';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Request permissions (iOS + Android 13+)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
    );

    // Android: setup notification channel with max importance + full-screen intent
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidInit);

    await _fln.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Tapping the notification should bring app to foreground; UI can listen to FCM open events.
      },
    );

    if (!kIsWeb && Platform.isAndroid) {
      await _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
        const AndroidNotificationChannel(
          androidChannelId,
          androidChannelName,
          description: androidChannelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
    }

    // Foreground messages: show our own full-screen style notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'incoming_call') {
        _showIncomingCallNotification(
          title: message.notification?.title ?? 'Incoming Emergency Call',
          body: message.notification?.body ?? 'Tap to answer',
          payload: message.data,
        );
      }
    });

    // When app opened from background by tapping notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      // App-specific routing can be done by UI layer if needed.
    });

    _initialized = true;
  }

  Future<void> _showIncomingCallNotification({required String title, required String body, Map<String, dynamic>? payload}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      androidChannelId,
      androidChannelName,
      channelDescription: androidChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.call,
      ticker: 'incoming_call',
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _fln.show(
      1001,
      title,
      body,
      platformDetails,
      payload: payload != null ? payload.toString() : null,
    );
  }

  /// Dismiss the incoming call notification if it is showing
  Future<void> dismissIncomingCallNotification() async {
    try {
      await _fln.cancel(1001);
    } catch (e) {
      debugPrint('Error cancelling incoming call notification: $e');
    }
  }

  /// Dismiss all notifications as a safety net
  Future<void> dismissAllNotifications() async {
    try {
      await _fln.cancelAll();
    } catch (e) {
      debugPrint('Error cancelling all notifications: $e');
    }
  }

  /// Save FCM token under users/{username}/fcmToken so server can send notifications.
  Future<void> saveFcmTokenForUser(String username) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      final ref = FirebaseDatabase.instance.ref('users/$username');
      await ref.update({'fcmToken': token});
      // Ensure token refresh persists
      _messaging.onTokenRefresh.listen((newToken) async {
        try { await ref.update({'fcmToken': newToken}); } catch (_) {}
      });
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }
}
