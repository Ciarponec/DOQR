import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../l10n/app_language.dart';
import '../models/chat_message_item.dart';
import '../models/courier_note_item.dart';
import '../models/door_item.dart';
import '../models/ring_item.dart';

class RtcConfig {
  final List<Map<String, dynamic>> iceServers;
  final DateTime? mediaDeadline;
  final int? maxSessionSeconds;

  const RtcConfig({
    required this.iceServers,
    required this.mediaDeadline,
    required this.maxSessionSeconds,
  });
}

class DoqrApi {
  final SupabaseClient client;
  static const _uuid = Uuid();
  DoqrApi(this.client);

  Never _throw(FunctionResponse response) {
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    throw Exception(appText('İstek başarısız (${response.status})',
        'Request failed (${response.status})'));
  }

  Future<Map<String, dynamic>> verifyStorePurchase({
    required String provider,
    required String productId,
    required String verificationData,
  }) async {
    final response =
        await client.functions.invoke('store-purchase-verify', body: {
      'provider': provider,
      'product_id': productId,
      'verification_data': verificationData,
    });
    if (response.status != 200) _throw(response);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> deleteAccount() async {
    final response = await client.functions.invoke('account-delete', body: {});
    if (response.status != 200) _throw(response);
  }

  Future<DoorListResult> listDoors() async {
    final response =
        await client.functions.invoke('door-list', method: HttpMethod.get);
    if (response.status != 200) _throw(response);
    final map = Map<String, dynamic>.from(response.data as Map);
    final plan = PlanItem.fromJson(
        Map<String, dynamic>.from(map['account_plan'] as Map));
    final doors = (map['doors'] as List)
        .map((row) => DoorItem.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
    return DoorListResult(doors, plan);
  }

  Future<DoorItem> createDoor(
      {required String label, String? addressText}) async {
    final response = await client.functions.invoke('door-create', body: {
      'label': label,
      'address_text': addressText,
    });
    if (response.status != 201) _throw(response);
    final map = Map<String, dynamic>.from(response.data as Map);
    map['plan'] ??= {'id': map['plan_id'] ?? 'free'};
    return DoorItem.fromJson(map);
  }

  Future<DoorItem> updateDoor({
    required DoorItem door,
    required String label,
    String? addressText,
    String? welcomeMessage,
    required bool textEnabled,
    required bool audioEnabled,
    required bool videoEnabled,
    required bool requireVisitorName,
    required int ringTimeoutSeconds,
    required bool isActive,
  }) async {
    final response = await client.functions.invoke('door-update', body: {
      'door_id': door.id,
      'label': label,
      'address_text': addressText,
      'welcome_message': welcomeMessage,
      'text_enabled': textEnabled,
      'audio_enabled': audioEnabled,
      'video_enabled': videoEnabled,
      'require_visitor_name': requireVisitorName,
      'ring_timeout_seconds': ringTimeoutSeconds,
      'is_active': isActive,
    });
    if (response.status != 200) _throw(response);
    final map = Map<String, dynamic>.from(response.data as Map);
    map['role'] = door.role;
    map['plan'] = {
      'id': map['plan_id'] ?? door.plan.id,
      'display_name': door.plan.displayName,
      'annual_price_usd_cents': door.plan.annualPriceUsdCents,
      'max_doors': door.plan.maxDoors,
      'max_hosts_per_door': door.plan.maxHostsPerDoor,
      'log_retention_days': door.plan.logRetentionDays,
      'log_retention_count': door.plan.logRetentionCount,
      'monthly_audio_seconds': door.plan.monthlyAudioSeconds,
      'monthly_video_seconds': door.plan.monthlyVideoSeconds,
      'features': door.plan.features,
      'subscription_status': door.plan.subscriptionStatus,
      'current_period_end': door.plan.currentPeriodEnd?.toIso8601String(),
      'trial_ends_at': door.plan.trialEndsAt?.toIso8601String(),
      'is_trial': door.plan.isTrial,
    };
    return DoorItem.fromJson(map);
  }

  Future<List<RingItem>> listRings() async {
    final rows = await client
        .from('rings')
        .select(
            'id, door_id, status, requested_mode, accepted_mode, visitor_kind, visitor_alias, courier_code, courier_note_id, client_metadata, created_at, answered_at, closed_at')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => RingItem.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<RingItem> getRing(String ringId) async {
    final row = await client
        .from('rings')
        .select(
            'id, door_id, status, requested_mode, accepted_mode, visitor_kind, visitor_alias, courier_code, courier_note_id, client_metadata, created_at, answered_at, closed_at')
        .eq('id', ringId)
        .single();
    return RingItem.fromJson(Map<String, dynamic>.from(row));
  }

  Stream<List<RingItem>> watchRing(String ringId) => client
      .from('rings')
      .stream(primaryKey: ['id'])
      .eq('id', ringId)
      .map((rows) => rows.map(RingItem.fromJson).toList());

  Stream<List<ChatMessageItem>> watchChat(String ringId) => client
      .from('chat_messages')
      .stream(primaryKey: ['id'])
      .eq('ring_id', ringId)
      .order('created_at')
      .map((rows) => rows.map(ChatMessageItem.fromJson).toList());

  Future<void> sendHostMessage(
      {required String ringId, required String message}) async {
    final response = await client.functions.invoke('chat-send', body: {
      'ring_id': ringId,
      'message_text': message,
      'client_message_id': _uuid.v4(),
    });
    if (response.status != 200 && response.status != 201) _throw(response);
  }

  Future<RingItem> ringAction(
      {required String ringId, required String action}) async {
    final response = await client.functions
        .invoke('ring-action', body: {'ring_id': ringId, 'action': action});
    if (response.status != 200) _throw(response);
    return getRing(ringId);
  }

  Future<RtcConfig> rtcConfig(String ringId) async {
    final response =
        await client.functions.invoke('rtc-config', body: {'ring_id': ringId});
    if (response.status != 200) _throw(response);
    final map = Map<String, dynamic>.from(response.data as Map);
    return RtcConfig(
      iceServers: (map['ice_servers'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
      mediaDeadline: map['media_deadline'] is String
          ? DateTime.tryParse(map['media_deadline'] as String)?.toUtc()
          : null,
      maxSessionSeconds: (map['max_session_seconds'] as num?)?.toInt(),
    );
  }

  Future<Map<String, dynamic>> createQrToken({required String doorId}) async {
    final response =
        await client.functions.invoke('door-qr-token-create', body: {
      'door_id': doorId,
    });
    if (response.status != 201) _throw(response);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> revokeQrToken({required String tokenId}) async {
    final response = await client.functions
        .invoke('door-qr-token-revoke', body: {'token_id': tokenId});
    if (response.status != 200) _throw(response);
  }

  Future<List<CourierNoteItem>> listCourierNotes(String doorId) async {
    final response = await client.functions.invoke(
      'courier-notes',
      method: HttpMethod.get,
      queryParameters: {'door_id': doorId},
    );
    if (response.status != 200) _throw(response);
    final rows = (response.data as Map)['notes'] as List;
    return rows
        .map((row) =>
            CourierNoteItem.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> saveCourierNote({
    required String doorId,
    String? id,
    required String courierCode,
    required String courierLabel,
    required String title,
    required String message,
    String? deliveryCode,
    bool isActive = true,
  }) async {
    final response = await client.functions.invoke('courier-notes', body: {
      'action': 'save',
      'door_id': doorId,
      'id': id,
      'courier_code': courierCode,
      'courier_label': courierLabel,
      'title': title,
      'message_text': message,
      'delivery_code': deliveryCode,
      'is_active': isActive,
    });
    if (response.status != 200 && response.status != 201) _throw(response);
  }

  Future<void> deleteCourierNote(String doorId, String noteId) async {
    final response = await client.functions.invoke('courier-notes', body: {
      'action': 'delete',
      'door_id': doorId,
      'id': noteId,
    });
    if (response.status != 200) _throw(response);
  }

  Future<void> registerPushToken(String token,
      {String? appVersion, String? locale}) async {
    final response =
        await client.functions.invoke('register-push-token', body: {
      'action': 'register',
      'fcm_token': token,
      'platform':
          defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      'app_version': appVersion,
      'locale': locale,
    });
    if (response.status != 200) _throw(response);
  }

  Future<void> unregisterPushToken(String token) async {
    final response =
        await client.functions.invoke('register-push-token', body: {
      'action': 'unregister',
      'fcm_token': token,
    });
    if (response.status != 200) _throw(response);
  }

  Future<void> blockVisitor(
      {required String ringId,
      required String scope,
      int networkHours = 24}) async {
    final response = await client.functions.invoke('visitor-block', body: {
      'ring_id': ringId,
      'scope': scope,
      'network_hours': networkHours,
    });
    if (response.status != 200) _throw(response);
  }

  Future<List<Map<String, dynamic>>> listDoorBlocks(String doorId) async {
    final response = await client.functions.invoke(
      'visitor-block',
      method: HttpMethod.get,
      queryParameters: {'door_id': doorId},
    );
    if (response.status != 200) _throw(response);
    return ((response.data as Map)['blocks'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> removeDoorBlock(String doorId, String blockId) async {
    final response = await client.functions.invoke('visitor-block', body: {
      'action': 'unblock',
      'door_id': doorId,
      'block_id': blockId,
    });
    if (response.status != 200) _throw(response);
  }
}
