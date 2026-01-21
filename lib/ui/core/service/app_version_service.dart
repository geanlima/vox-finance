import 'package:shared_preferences/shared_preferences.dart';

class AppVersionService {
  static const _kPrefVersion = 'vox_app_version';

  static Future<String?> getSelectedVersion() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString(_kPrefVersion);
    return (v == 'v1' || v == 'v2') ? v : null;
  }

  static Future<void> setSelectedVersion(String v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kPrefVersion, v);
  }

  static Future<void> clearSelectedVersion() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kPrefVersion);
  }
}
