import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// backend `com.cookpilot.backend.user.User`.
/// 인증 미확정 — 서버는 고정 목유저 1명을 돌려준다.
@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String displayName,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
