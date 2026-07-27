import 'package:dio/dio.dart';

/// 백엔드 에러를 화면이 다룰 수 있는 형태로 정규화한다.
/// 서버는 RFC7807 ProblemDetail을 반환한다 (backend docs/08_mvp_api.md).
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.detail,
  });

  /// 서버에 닿지 못한 경우 (미기동, 타임아웃, DNS 등).
  const ApiException.network(this.message)
    : statusCode = 0,
      detail = null;

  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    if (response == null) {
      return ApiException.network(_networkMessage(e));
    }

    final data = response.data;
    String? detail;
    if (data is Map) {
      final raw = data['detail'] ?? data['title'];
      if (raw is String && raw.isNotEmpty) detail = raw;
    }

    final status = response.statusCode ?? 0;
    return ApiException(
      statusCode: status,
      message: detail ?? _statusMessage(status),
      detail: detail,
    );
  }

  final int statusCode;
  final String message;
  final String? detail;

  bool get isNetwork => statusCode == 0;
  bool get isNotFound => statusCode == 404;
  bool get isBadRequest => statusCode == 400;

  /// 409: 상태 위반 (진행 중이 아닌 세션 조작, 완료 전 리뷰, 중복 리뷰).
  bool get isConflict => statusCode == 409;

  @override
  String toString() => message;

  static String _networkMessage(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => '서버 응답이 없습니다. 잠시 후 다시 시도해 주세요.',
    DioExceptionType.connectionError => '서버에 연결할 수 없습니다.',
    _ => '통신 중 문제가 발생했습니다. (${e.message ?? e.type.name})',
  };

  static String _statusMessage(int status) => switch (status) {
    400 => '요청 값이 올바르지 않습니다.',
    404 => '요청한 데이터를 찾을 수 없습니다.',
    409 => '지금은 처리할 수 없는 상태입니다.',
    _ => '요청이 실패했습니다. (HTTP $status)',
  };
}
