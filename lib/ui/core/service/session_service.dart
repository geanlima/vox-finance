import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  SessionService._();
  static final instance = SessionService._();

  static const _kIsLoggedIn = 'isLoggedIn';
  static const _kLoginType = 'loginType'; // 'local' | 'firebase'
  static const _kUid = 'uid'; // firebase uid (quando loginType=firebase)

  Future<void> saveLogin({required String loginType, String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsLoggedIn, true);
    await prefs.setString(_kLoginType, loginType);
    if (uid != null) {
      await prefs.setString(_kUid, uid);
    } else {
      await prefs.remove(_kUid);
    }
  }

  Future<void> clearLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsLoggedIn, false);
    await prefs.remove(_kLoginType);
    await prefs.remove(_kUid);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIsLoggedIn) ?? false;
  }

  Future<String?> getLoginType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLoginType);
  }

  Future<String?> getUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUid);
  }
}
