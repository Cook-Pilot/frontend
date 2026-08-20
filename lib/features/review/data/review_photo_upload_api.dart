import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_config.dart';
import '../../auth/data/auth_session.dart';
import '../application/review_photo_upload_port.dart';

/// 제안 계약(docs/feat-review-photo-#47.md) 기준 HTTP 어댑터.
///
/// 경로·파트명은 백엔드 확정 시 이 파일의 상수만 바꾸면 되도록 여기 국소화한다.
final class ReviewPhotoUploadApi implements ReviewPhotoUploadPort {
  ReviewPhotoUploadApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? cookPilotApiBaseUrl();

  static const _path = '/api/v1/reviews/photos';
  static const _filePartName = 'file';
  static const _timeout = Duration(seconds: 8);

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<String> upload(String absolutePath) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl$_path'))
      ..headers.addAll(AuthSession.requestHeaders);
    request.files.add(
      await http.MultipartFile.fromPath(_filePartName, absolutePath),
    );

    final http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw const ReviewPhotoUploadException('서버 응답 시간이 초과되었습니다.');
    } on http.ClientException {
      throw const ReviewPhotoUploadException('서버에 연결하지 못했습니다.');
    }

    if (response.statusCode != 201) {
      throw ReviewPhotoUploadException(
        '사진을 업로드하지 못했습니다. (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const ReviewPhotoUploadException('사진 업로드 응답 형식이 올바르지 않습니다.');
    }
    if (decoded case {'url': final String url} when url.isNotEmpty) {
      return url;
    }
    throw const ReviewPhotoUploadException('사진 업로드 응답 형식이 올바르지 않습니다.');
  }
}
