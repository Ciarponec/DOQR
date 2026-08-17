import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'doqr_api.dart';

const _ringChannel = AndroidNotificationChannel(
  'doqr_rings',
  'Kapı zili',
  description: 'Yeni ziyaretçi ve dijital zil bildirimleri',
  importance: Importance.max,
  playSound: true,
);
const _ringNotificationId = 0;
const _defaultRingTimeoutMilliseconds = 30000;
const _insistentNotificationFlag = 4;
final _backgroundNotifications = FlutterLocalNotificationsPlugin();

String? _ringId(RemoteMessage message) => message.data['ring_id'];

String? _ringTag(String? ringId) =>
    ringId == null || ringId.isEmpty ? null : 'ring-$ringId';

int _ringTimeout(RemoteMessage message) {
  final seconds = int.tryParse(message.data['ring_timeout_seconds'] ?? '');
  return ((seconds ?? (_defaultRingTimeoutMilliseconds ~/ 1000)).clamp(5, 60) *
          1000)
      .toInt();
}

NotificationDetails _ringNotificationDetails(RemoteMessage message) =>
    NotificationDetails(
      android: AndroidNotificationDetails(
        _ringChannel.id,
        _ringChannel.name,
        channelDescription: _ringChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.call,
        fullScreenIntent: false,
        ongoing: true,
        autoCancel: true,
        timeoutAfter: _ringTimeout(message),
        tag: _ringTag(_ringId(message)),
        additionalFlags:
            Int32List.fromList(const <int>[_insistentNotificationFlag]),
        actions: message.data['courier_note_available'] == 'true'
            ? const [
                AndroidNotificationAction(
                  'share_delivery_code',
                  'Teslimat kodunu gönder',
                  showsUserInterface: true,
                ),
              ]
            : const [],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

Future<void> _showDoorbellNotification(
  FlutterLocalNotificationsPlugin notifications,
  RemoteMessage message,
) =>
    notifications.show(
      id: _ringNotificationId,
      title: message.notification?.title ??
          message.data['notification_title'] ??
          'DOQR: Zil çalıyor',
      body: message.notification?.body ??
          message.data['notification_body'] ??
          'Kapıda bir ziyaretçi var',
      notificationDetails: _ringNotificationDetails(message),
      payload: _ringId(message),
    );

Future<void> _cancelDoorbellNotification(
  FlutterLocalNotificationsPlugin notifications,
  String? ringId,
) =>
    notifications.cancel(id: _ringNotificationId, tag: _ringTag(ringId));

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  if (defaultTargetPlatform != TargetPlatform.android) return;
  await _backgroundNotifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );
  if (message.data['type'] == 'doorbell_status') {
    await _cancelDoorbellNotification(
        _backgroundNotifications, _ringId(message));
    return;
  }
  if (message.data['type'] != 'doorbell_ring') return;
  await _backgroundNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_ringChannel);
  await _showDoorbellNotification(_backgroundNotifications, message);
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _local = FlutterLocalNotificationsPlugin();
  Future<void>? _initializationFuture;
  GlobalKey<NavigatorState>? _navigatorKey;
  String? _pendingRingId;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  RealtimeChannel? _foregroundRingChannel;
  Timer? _registrationRetryTimer;
  int _registrationRetryAttempt = 0;
  String? _currentToken;
  DoqrApi? _api;
  String? _visibleRingId;

  bool get isConfigured =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (!isConfigured) return;
    final initialization = _initializationFuture ??= _initialize();
    try {
      await initialization;
    } catch (_) {
      if (identical(_initializationFuture, initialization)) {
        _initializationFuture = null;
      }
      rethrow;
    }
  }

  Future<void> _initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId == 'share_delivery_code') {
          unawaited(_shareDeliveryCode(response.payload));
        } else {
          _openRing(response.payload);
        }
      },
    );
    final launchDetails = await _local.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _pendingRingId = launchDetails?.notificationResponse?.payload;
    }
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_ringChannel);
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
    await initialize();
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
      await _registerToken(api, _currentToken!, locale);
    }
    await _tokenSubscription?.cancel();
    _tokenSubscription =
        FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      _currentToken = token;
      final currentApi = _api;
      if (currentApi != null) await _registerToken(currentApi, token, locale);
    });
    await _foregroundSubscription?.cancel();
    _foregroundSubscription =
        FirebaseMessaging.onMessage.listen((message) async {
      if (message.data['type'] == 'doorbell_status') {
        await cancelRingNotification(_ringId(message));
        return;
      }
      if (message.data['type'] != 'doorbell_ring') return;
      await _showDoorbellNotification(_local, message);
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
    _registrationRetryTimer?.cancel();
    _registrationRetryTimer = null;
    _registrationRetryAttempt = 0;
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _foregroundRingChannel?.unsubscribe();
    _foregroundRingChannel = null;
  }

  Future<void> _shareDeliveryCode(String? ringId) async {
    if (ringId == null || ringId.isEmpty || _api == null) return;
    try {
      await _api!.ringAction(ringId: ringId, action: 'reveal_note');
    } catch (_) {
      // The session may have ended, or this courier note may not contain a
      // delivery code. Opening the visit gives the host a clear next step.
      _openRing(ringId);
    }
  }

  Future<void> cancelRingNotification(String? ringId) async {
    if (!isConfigured) return;
    await initialize();
    await _cancelDoorbellNotification(_local, ringId);
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

  Future<void> _registerToken(DoqrApi api, String token, Locale locale) async {
    try {
      await api.registerPushToken(token, locale: locale.toLanguageTag());
      _registrationRetryTimer?.cancel();
      _registrationRetryTimer = null;
      _registrationRetryAttempt = 0;
    } catch (error) {
      if (!identical(_api, api) || _currentToken != token) return;
      const delays = <Duration>[
        Duration(seconds: 5),
        Duration(seconds: 15),
        Duration(minutes: 1),
        Duration(minutes: 5),
      ];
      final retryIndex =
          _registrationRetryAttempt.clamp(0, delays.length - 1).toInt();
      final delay = delays[retryIndex];
      _registrationRetryAttempt++;
      _registrationRetryTimer?.cancel();
      _registrationRetryTimer = Timer(delay, () {
        if (identical(_api, api) && _currentToken == token) {
          unawaited(_registerToken(api, token, locale));
        }
      });
      if (kDebugMode) {
        debugPrint(
            'Push token registration failed; retrying in $delay: $error');
      }
    }
  }

  void _openRing(String? ringId) {
    if (ringId == null || ringId.isEmpty) return;
    unawaited(cancelRingNotification(ringId));
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
