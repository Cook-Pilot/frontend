/// 후기 사진 한 장을 서버에 올리고 공개 URL을 받는 포트.
///
/// 서버 계약(제안): POST /api/v1/reviews/photos, multipart 파트명 "file",
/// 201 응답 {"url": "..."} — 반환된 문자열을 그대로 리뷰 제출의 photoUrls에
/// 넣는다. 프론트는 저장소(S3 등)의 존재를 모른다. 백엔드 엔드포인트가
/// 확정되기 전까지 화면은 fake 구현으로 동작한다.
abstract interface class ReviewPhotoUploadPort {
  /// [absolutePath]의 파일을 업로드하고 공개 URL을 반환한다.
  /// 실패는 [ReviewPhotoUploadException]으로 던진다.
  Future<String> upload(String absolutePath);
}

final class ReviewPhotoUploadException implements Exception {
  const ReviewPhotoUploadException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
