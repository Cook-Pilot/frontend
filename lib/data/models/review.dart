import 'package:freezed_annotation/freezed_annotation.dart';

part 'review.freezed.dart';
part 'review.g.dart';

/// backend `PostCookReview`.
/// 저장하면 서버가 세션을 COMPLETED로 바꾸고 개인 레시피 버전을 자동 생성한다.
@freezed
class PostCookReview with _$PostCookReview {
  const factory PostCookReview({
    required String id,
    required String cookSessionId,
    required String userId,
    required String recipeId,
    required int rating,
    String? comment,
    String? nextTimeNote,
    String? createdPersonalVersionId,
    DateTime? createdAt,
  }) = _PostCookReview;

  factory PostCookReview.fromJson(Map<String, dynamic> json) =>
      _$PostCookReviewFromJson(json);
}
