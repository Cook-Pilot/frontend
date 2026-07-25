import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_config.dart';

const cookPilotUserIdHeader = 'X-CookPilot-User-Id';
const anonymousUserIdempotencyHeader = 'Idempotency-Key';

const _userIdStorageKey = 'cookpilot_beta_user_id';
const _installationIdStorageKey = 'cookpilot_beta_installation_id';

class BetaUser {
  const BetaUser({
    required this.id,
    required this.displayName,
    required this.betaNumber,
  });

  factory BetaUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final displayName = json['displayName'];
    final betaNumber = json['betaNumber'];
    if (id is! String ||
        id.isEmpty ||
        displayName is! String ||
        betaNumber is! num) {
      throw const BetaUserException('사용자 발급 응답 형식이 올바르지 않습니다.');
    }
    return BetaUser(
      id: id,
      displayName: displayName,
      betaNumber: betaNumber.toInt(),
    );
  }

  final String id;
  final String displayName;
  final int betaNumber;
}

class BetaUserException implements Exception {
  const BetaUserException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BetaUserSession {
  static BetaUser? _currentUser;

  static BetaUser? get currentUser => _currentUser;
  static String? get userId => _currentUser?.id;

  static Map<String, String> get requestHeaders {
    final id = userId;
    return id == null ? const {} : {cookPilotUserIdHeader: id};
  }

  static void setCurrentUser(BetaUser user) {
    _currentUser = user;
  }

  static void clear() {
    _currentUser = null;
  }
}

abstract interface class BetaUserStorage {
  Future<String?> readUserId();

  Future<bool> writeUserId(String userId);

  Future<bool> removeUserId();

  Future<String?> readInstallationId();

  Future<bool> writeInstallationId(String installationId);
}

class SharedPreferencesBetaUserStorage implements BetaUserStorage {
  const SharedPreferencesBetaUserStorage();

  Future<SharedPreferences> _preferences() => SharedPreferences.getInstance();

  @override
  Future<String?> readUserId() async {
    return (await _preferences()).getString(_userIdStorageKey);
  }

  @override
  Future<bool> writeUserId(String userId) async {
    return (await _preferences()).setString(_userIdStorageKey, userId);
  }

  @override
  Future<bool> removeUserId() async {
    return (await _preferences()).remove(_userIdStorageKey);
  }

  @override
  Future<String?> readInstallationId() async {
    return (await _preferences()).getString(_installationIdStorageKey);
  }

  @override
  Future<bool> writeInstallationId(String installationId) async {
    return (await _preferences()).setString(
      _installationIdStorageKey,
      installationId,
    );
  }
}

class BetaUserRepository {
  BetaUserRepository({
    http.Client? client,
    String? baseUrl,
    BetaUserStorage? storage,
    this.requestTimeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? cookPilotApiBaseUrl(),
       _storage = storage ?? const SharedPreferencesBetaUserStorage();

  static Future<BetaUser>? _pendingUser;

  final http.Client _client;
  final String _baseUrl;
  final BetaUserStorage _storage;
  final Duration requestTimeout;

  Future<BetaUser> ensureUser() {
    final current = BetaUserSession.currentUser;
    if (current != null) return Future.value(current);

    final pending = _pendingUser;
    if (pending != null) return pending;

    late final Future<BetaUser> request;
    request = _ensureUser().whenComplete(() {
      if (identical(_pendingUser, request)) {
        _pendingUser = null;
      }
    });
    _pendingUser = request;
    return request;
  }

  Future<BetaUser> _ensureUser() async {
    final savedId = await _storage.readUserId();
    if (savedId != null && savedId.isNotEmpty) {
      final savedUser = await _findSavedUser(savedId);
      if (savedUser != null) {
        BetaUserSession.setCurrentUser(savedUser);
        return savedUser;
      }
      await _storage.removeUserId();
    }

    final installationId = await _ensureInstallationId();
    final createdUser = await _createAnonymousUser(installationId);
    final persisted = await _storage.writeUserId(createdUser.id);
    if (!persisted) {
      throw const BetaUserException('사용자 정보를 기기에 저장하지 못했습니다.');
    }
    BetaUserSession.setCurrentUser(createdUser);
    return createdUser;
  }

  Future<String> _ensureInstallationId() async {
    final savedId = await _storage.readInstallationId();
    if (savedId != null && _isUuid(savedId)) {
      return savedId;
    }

    final installationId = _generateUuidV4();
    final persisted = await _storage.writeInstallationId(installationId);
    if (!persisted) {
      throw const BetaUserException('기기 식별 정보를 저장하지 못했습니다.');
    }
    return installationId;
  }

  Future<BetaUser?> _findSavedUser(String userId) async {
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/api/v1/users/me'),
          headers: {cookPilotUserIdHeader: userId},
        )
        .timeout(requestTimeout);

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw BetaUserException(
        '저장된 사용자 정보를 확인하지 못했습니다. (${response.statusCode})',
      );
    }
    return _decodeUser(response.body);
  }

  Future<BetaUser> _createAnonymousUser(String installationId) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/api/v1/users/anonymous'),
          headers: {anonymousUserIdempotencyHeader: installationId},
        )
        .timeout(requestTimeout);

    if (response.statusCode != 201) {
      throw BetaUserException('베타 사용자 발급에 실패했습니다. (${response.statusCode})');
    }
    return _decodeUser(response.body);
  }

  BetaUser _decodeUser(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const BetaUserException('사용자 발급 응답 형식이 올바르지 않습니다.');
    }
    return BetaUser.fromJson(decoded);
  }

  bool _isUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
      r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
