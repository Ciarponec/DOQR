import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message_item.dart';
import '../models/door_item.dart';
import '../models/ring_item.dart';

class DoqrApi {
  final SupabaseClient client;
  DoqrApi(this.client);

  Future<List<DoorItem>> listDoors() async {
    final rows = await client.from('doors').select().order('label');
    return (rows as List).cast<Map<String, dynamic>>().map(DoorItem.fromJson).toList();
  }

  Future<DoorItem> createDoor({required String label, String? addressText}) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final row = await client
        .from('doors')
        .insert({'owner_user_id': uid, 'label': label, 'address_text': addressText})
        .select()
        .single();
    return DoorItem.fromJson(row);
  }

  Future<List<RingItem>> listRings() async {
    final rows = await client.from('rings').select().order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>().map(RingItem.fromJson).toList();
  }

  Stream<List<ChatMessageItem>> watchChat(String ringId) {
    return client.from('chat_messages').stream(primaryKey: ['id']).eq('ring_id', ringId).order('created_at').map((rows) => rows.map(ChatMessageItem.fromJson).toList());
  }

  Future<Map<String, dynamic>> ringFromQr({required String qrToken, String? visitorAlias}) async {
    final res = await client.functions.invoke('qr-ring-create', body: {'qr_token': qrToken, 'visitor_alias': visitorAlias});
    if (res.status != 200) throw Exception(res.data.toString());
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> sendOwnerMessage({required String ringId, required String message}) async {
    final res = await client.functions.invoke('chat-send', body: {'ring_id': ringId, 'message_text': message});
    if (res.status != 200) throw Exception(res.data.toString());
  }

  Future<void> sendVisitorMessage({required String ringId, required String visitorSessionToken, required String message}) async {
    final res = await client.functions.invoke('visitor-chat-send', body: {'ring_id': ringId, 'visitor_session_token': visitorSessionToken, 'message_text': message});
    if (res.status != 200) throw Exception(res.data.toString());
  }

  Future<void> acceptShareToken({required String token, String? pin}) async {
    final res = await client.functions.invoke('door-share-accept', body: {'share_token': token, 'pin': pin});
    if (res.status != 200) throw Exception(res.data.toString());
  }

  Future<Map<String, dynamic>> createShareToken({required String doorId, String? pin, int maxUses = 1, int expiresMinutes = 1440}) async {
    final res = await client.functions.invoke('door-share-create', body: {
      'door_id': doorId,
      'pin': pin,
      'max_uses': maxUses,
      'expires_minutes': expiresMinutes,
    });
    if (res.status != 200) throw Exception(res.data.toString());
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> createQrToken({required String doorId, int expiresMinutes = 43200}) async {
    final res = await client.functions.invoke('door-qr-token-create', body: {'door_id': doorId, 'expires_minutes': expiresMinutes});
    if (res.status != 200) throw Exception(res.data.toString());
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> revokeQrToken({required String tokenId}) async {
    final res = await client.functions.invoke('door-qr-token-revoke', body: {'token_id': tokenId});
    if (res.status != 200) throw Exception(res.data.toString());
  }

  Future<void> requestUnlock({required String doorId, String? reason}) async {
    final res = await client.functions.invoke('door-unlock-request', body: {'door_id': doorId, 'reason': reason, 'ttl_seconds': 30});
    if (res.status != 200) throw Exception(res.data.toString());
  }
}
