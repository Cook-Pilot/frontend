import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_config.dart';
import 'beta_user_repository.dart';

/// `GET/PATCH /api/v1/users/me`로 성별·연령대 온보딩 상태를 다룬다.
class UserProfileRepository {
  UserProfileRepository({
    http.Client? client,
    String? baseUrl,
    this.requestTimeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? cookPilotApiBaseUrl();

  final http.Client _client;
  final String _baseUrl;
  final Duration requestTimeout;

  Uri get _meUri => Uri.parse('$_baseUrl/api/v1/users/me');

  /// profileAskedAt이 null이면 아직 온보딩을 물어보지 않은 것이다.
  /// 필드 자체가 없는 구버전 서버 응답에는 온보딩을 띄우지 않는다.
  Future<bool> needsOnboarding() async {
    final response = await _client
        .get(_meUri, headers: BetaUserSession.requestHeaders)
        .timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw BetaUserException('사용자 프로필을 확인하지 못했습니다. (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> &&
        decoded.containsKey('profileAskedAt') &&
        decoded['profileAskedAt'] == null;
  }

  /// gender("M"|"F"|"N")·ageGroup(10~60)을 저장한다.
  /// 둘 다 null이면 빈 body를 보내 "물어봤음"만 기록한다(건너뛰기).
  Future<void> updateProfile({String? gender, int? ageGroup}) async {
    final response = await _client
        .patch(
          _meUri,
          headers: {
            ...BetaUserSession.requestHeaders,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'gender': ?gender, 'ageGroup': ?ageGroup}),
        )
        .timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw BetaUserException('프로필 저장에 실패했습니다. (${response.statusCode})');
    }
  }
}
