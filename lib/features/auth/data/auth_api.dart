import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_config.dart';

/// 로그인 결과. token 은 이후 모든 요청의 Authorization 헤더에 실린다.
class AuthSessionToken {
  const AuthSessionToken({
    required this.token,
    required this.expiresAt,
    required this.userId,
    required this.displayName,
  });

  factory AuthSessionToken.fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    final userId = json['userId'];
    final expiresAt = json['expiresAt'];
    if (token is! String || token.isEmpty || userId is! String) {
      throw const AuthException('로그인 응답 형식이 올바르지 않습니다.');
    }
    return AuthSessionToken(
      token: token,
      expiresAt: expiresAt is String
          ? DateTime.tryParse(expiresAt) ?? _fallbackExpiry()
          : _fallbackExpiry(),
      userId: userId,
      displayName: json['displayName'] is String
          ? json['displayName'] as String
          : '쿡파일럿 사용자',
    );
  }

  /// 서버가 만료를 안 주면 보수적으로 짧게 잡는다 — 만료를 모르는 채 오래 쓰는 것보다 낫다.
  static DateTime _fallbackExpiry() =>
      DateTime.now().toUtc().add(const Duration(days: 1));

  final String token;
  final DateTime expiresAt;
  final String userId;
  final String displayName;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());

  Map<String, dynamic> toJson() => {
    'token': token,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'userId': userId,
    'displayName': displayName,
  };
}

class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// 서버 인증 API. 소셜 제공자 토큰이나 개발자 시크릿을 우리 세션 토큰으로 바꾼다.
class AuthApi {
  AuthApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? cookPilotApiBaseUrl();

  static const _timeout = Duration(seconds: 8);

  final http.Client _client;
  final String _baseUrl;

  /// [provider] 는 서버 경로에 그대로 들어간다: google, kakao, naver.
  Future<AuthSessionToken> loginWithProvider(
    String provider,
    String providerToken,
  ) {
    return _post('/api/v1/auth/$provider', {'token': providerToken});
  }

  Future<AuthSessionToken> loginAsDeveloper(String secret) {
    return _post('/api/v1/auth/dev', {'secret': secret});
  }

  Future<AuthSessionToken> _post(String path, Map<String, String> body) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AuthException('서버 응답 시간이 초과되었습니다.');
    } on http.ClientException {
      throw const AuthException('서버에 연결하지 못했습니다.');
    }

    if (response.statusCode != 200) {
      throw AuthException(
        _messageFor(response.statusCode),
        statusCode: response.statusCode,
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const AuthException('로그인 응답 형식이 올바르지 않습니다.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AuthException('로그인 응답 형식이 올바르지 않습니다.');
    }
    return AuthSessionToken.fromJson(decoded);
  }

  String _messageFor(int statusCode) => switch (statusCode) {
    401 => '로그인 정보가 올바르지 않습니다.',
    429 => '요청이 너무 많아요. 잠시 후 다시 시도해 주세요.',
    >= 500 => '서버에 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.',
    _ => '로그인하지 못했습니다. ($statusCode)',
  };
}
