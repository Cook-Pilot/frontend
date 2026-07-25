import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_config.dart';

const cookPilotUserIdHeader = 'X-CookPilot-User-Id';

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

class BetaUserRepository {
  BetaUserRepository({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? cookPilotApiBaseUrl();

  static const _userIdStorageKey = 'cookpilot_beta_user_id';
  static Future<BetaUser>? _pendingUser;

  final http.Client _client;
  final String _baseUrl;

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
    final preferences = await SharedPreferences.getInstance();
    final savedId = preferences.getString(_userIdStorageKey);
    if (savedId != null && savedId.isNotEmpty) {
      final savedUser = await _findSavedUser(savedId);
      if (savedUser != null) {
        BetaUserSession.setCurrentUser(savedUser);
        return savedUser;
      }
      await preferences.remove(_userIdStorageKey);
    }

    final createdUser = await _createAnonymousUser();
    await preferences.setString(_userIdStorageKey, createdUser.id);
    BetaUserSession.setCurrentUser(createdUser);
    return createdUser;
  }

  Future<BetaUser?> _findSavedUser(String userId) async {
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/api/v1/users/me'),
          headers: {cookPilotUserIdHeader: userId},
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw BetaUserException(
        '저장된 사용자 정보를 확인하지 못했습니다. (${response.statusCode})',
      );
    }
    return _decodeUser(response.body);
  }

  Future<BetaUser> _createAnonymousUser() async {
    final response = await _client
        .post(Uri.parse('$_baseUrl/api/v1/users/anonymous'))
        .timeout(const Duration(seconds: 8));

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
}
