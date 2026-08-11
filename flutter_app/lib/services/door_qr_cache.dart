import 'package:shared_preferences/shared_preferences.dart';

/// QR token is public by design. Caching it avoids issuing a new public QR
/// every time the owner reopens the printable template screen.
class DoorQrCache {
  static String _key(String doorId) => 'door_qr_token:$doorId';

  static Future<String?> read(String doorId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_key(doorId));
  }

  static Future<void> save(String doorId, String token) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(doorId), token);
  }

  static Future<void> remove(String doorId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(doorId));
  }
}
