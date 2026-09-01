import 'package:shared_preferences/shared_preferences.dart';

/// QR token is public by design. Caching it avoids issuing a new public QR
/// every time the owner reopens the printable template screen.
class DoorQrCache {
  static String _key(String doorId) => 'door_qr_token:$doorId';
  static String _idKey(String doorId) => 'door_qr_token_id:$doorId';

  static Future<String?> read(String doorId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_key(doorId));
  }

  static Future<String?> readTokenId(String doorId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_idKey(doorId));
  }

  static Future<void> save(
    String doorId,
    String token, {
    required String tokenId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(doorId), token);
    await preferences.setString(_idKey(doorId), tokenId);
  }

  static Future<void> remove(String doorId) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.remove(_key(doorId)),
      preferences.remove(_idKey(doorId)),
    ]);
  }
}
