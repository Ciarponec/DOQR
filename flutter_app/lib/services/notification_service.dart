import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'doqr_api.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _local = FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;
  String? _pendingRingId;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  RealtimeChannel? _foregroundRingChannel;
  String? _currentToken;
  DoqrApi? _api;
  String? _visibleRingId;

  bool get isConfigured =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (!isConfigured) return;
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _openRing(response.payload),
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'doqr_rings',
          'Kapı zili',
          description: 'Yeni ziyaretçi ve dijital zil bildirimleri',
          importance: Importance.max,
          playSound: true,
        ));
  }

  void attachNavigator(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
    if (_pendingRingId != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _openRing(_pendingRingId));
    }
  }

  Future<void> startForUser(DoqrApi api, Locale locale) async {
    if (!isConfigured) return;
    _api = api;
    await _foregroundRingChannel?.unsubscribe();
    _foregroundRingChannel = api.client
        .channel('foreground-rings:${api.client.auth.currentUser?.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'rings',
          filter: const PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'status',
            value: 'pending',
          ),
          callback: (payload) => _openRing(payload.newRecord['id']?.toString()),
        )..subscribe();
    await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true, provisional: false);
    _currentToken = await _getTokenWhenReady();
    if (_currentToken != null) {
      await api.registerPushToken(_currentToken!,
          locale: locale.toLanguageTag());
    }
    await _tokenSubscription?.cancel();
    _tokenSubscription =
        FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      _currentToken = token;
      await _api?.registerPushToken(token, locale: locale.toLanguageTag());
    });
    await _foregroundSubscription?.cancel();
    _foregroundSubscription =
        FirebaseMessaging.onMessage.listen((message) async {
      if (message.data['type'] != 'doorbell_ring') return;
      await _local.show(
        id: message.data['ring_id']?.hashCode ?? message.hashCode,
        title: message.notification?.title ?? 'DOQR: Zil çalıyor',
        body: message.notification?.body ?? 'Kapıda bir ziyaretçi var',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'doqr_rings',
            'Kapı zili',
            channelDescription: 'Yeni ziyaretçi ve dijital zil bildirimleri',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.call,
            fullScreenIntent: true,
          ),
          iOS: DarwinNotificationDetails(
              presentAlert: true, presentBadge: true, presentSound: true),
        ),
        payload: message.data['ring_id'],
      );
      _openRing(message.data['ring_id']);
    });
    await _openedSubscription?.cancel();
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp
        .listen((message) => _openRing(message.data['ring_id']));
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _openRing(initial.data['ring_id']);
  }

  Future<void> stopForLogout() async {
    if (_currentToken != null && _api != null) {
      try {
        await _api!.unregisterPushToken(_currentToken!);
      } catch (_) {
        // Token removal is best effort; server also removes invalid FCM tokens.
      }
    }
    _api = null;
    _currentToken = null;
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _foregroundRingChannel?.unsubscribe();
    _foregroundRingChannel = null;
  }

  Future<String?> _getTokenWhenReady() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      for (var attempt = 0; attempt < 10; attempt++) {
        if (await FirebaseMessaging.instance.getAPNSToken() != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return FirebaseMessaging.instance.getToken();
  }

  void _openRing(String? ringId) {
    if (ringId == null || ringId.isEmpty) return;
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      _pendingRingId = ringId;
      return;
    }
    if (_visibleRingId == ringId) return;
    _pendingRingId = null;
    _visibleRingId = ringId;
    navigator
        .pushNamed('/ring', arguments: ringId)
        .whenComplete(() => _visibleRingId = null);
  }
}
