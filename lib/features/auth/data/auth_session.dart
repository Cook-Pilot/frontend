import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_api.dart';

/// 세션 토큰 보관소. 토큰은 비밀번호에 준하므로 평문 SharedPreferences 가 아니라
/// OS 보안 저장소(Android KeyStore / iOS Keychain)에 둔다.
abstract interface class AuthTokenStorage {
  Future<AuthSessionToken?> read();

  Future<void> write(AuthSessionToken token);

  Future<void> clear();
}

class SecureAuthTokenStorage implements AuthTokenStorage {
  const SecureAuthTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'cookpilot_session_token';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSessionToken?> read() async {
    // 저장소 접근 자체가 실패할 수 있다(키체인 잠김, 플러그인 미가용 등).
    // 앱 시작 경로에서 호출되므로 여기서 던지면 앱이 아예 뜨지 않는다 —
    // 읽지 못하면 '로그인 안 됨'으로 보고 로그인 화면에서 복구시킨다.
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return AuthSessionToken.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(AuthSessionToken token) {
    return _storage.write(key: _key, value: jsonEncode(token.toJson()));
  }

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// 현재 로그인 세션. API 호출부는 [requestHeaders] 만 본다.
///
/// 익명 발급에서 소셜 로그인으로 넘어가는 동안 두 방식이 함께 산다 —
/// 토큰이 있으면 Bearer 를, 없으면 기존 익명 헤더를 쓴다(서버도 같은 규칙).
class AuthSession {
  static AuthSessionToken? _token;
  static AuthTokenStorage _storage = const SecureAuthTokenStorage();

  static AuthSessionToken? get current => _token;

  static bool get isLoggedIn => _token != null && !_token!.isExpired;

  /// 앱 시작 시 한 번 호출한다. 저장된 토큰이 있으면 세션을 복원한다.
  static Future<bool> restore() async {
    final stored = await _storage.read();
    if (stored == null) return false;
    if (stored.isExpired) {
      await _storage.clear();
      return false;
    }
    _token = stored;
    return true;
  }

  static Future<void> save(AuthSessionToken token) async {
    _token = token;
    await _storage.write(token);
  }

  static Future<void> signOut() async {
    _token = null;
    await _storage.clear();
  }

  /// 토큰이 있으면 Bearer 헤더. 없으면 빈 맵 — 호출부가 익명 헤더로 떨어진다.
  static Map<String, String> get requestHeaders {
    final token = _token;
    if (token == null || token.isExpired) return const {};
    return {'Authorization': 'Bearer ${token.token}'};
  }

  /// 테스트 전용. 저장소를 갈아끼운다.
  static void debugUseStorage(AuthTokenStorage storage) {
    _storage = storage;
  }

  /// 테스트 전용. 메모리 상태만 비운다.
  static void debugReset() {
    _token = null;
    _storage = const SecureAuthTokenStorage();
  }
}
