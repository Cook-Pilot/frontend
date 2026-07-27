import 'package:cookpilot/core/network/dio_provider.dart';
import 'package:cookpilot/data/models/ai_feedback.dart';
import 'package:cookpilot/data/models/cook_session.dart';
import 'package:cookpilot/data/models/review.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// cooksession / review / ai — 조리 흐름 엔드포인트 (backend docs/08).
class CookSessionRepository {
  const CookSessionRepository(this._dio);

  final Dio _dio;

  Future<CookSession> create(String recipeId, {String? personalVersionId}) =>
      guardApi(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/cook-sessions',
          data: {'recipeId': recipeId, 'personalVersionId': ?personalVersionId},
        );
        return CookSession.fromJson(res.data!);
      });

  Future<CookSession> find(String sessionId) => guardApi(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/cook-sessions/$sessionId',
    );
    return CookSession.fromJson(res.data!);
  });

  Future<CookSession> moveStep(
    String sessionId, {
    required bool next,
    String source = 'BUTTON',
  }) => guardApi(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/cook-sessions/$sessionId/step',
      data: {'direction': next ? 'NEXT' : 'PREV', 'source': source},
    );
    return CookSession.fromJson(res.data!);
  });

  /// 상태를 REVIEW로 바꾼다. 리뷰 저장은 이 이후에만 가능하다.
  Future<CookSession> complete(String sessionId) => guardApi(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/cook-sessions/$sessionId/complete',
    );
    return CookSession.fromJson(res.data!);
  });

  Future<CookSession> abort(String sessionId) => guardApi(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/cook-sessions/$sessionId/abort',
    );
    return CookSession.fromJson(res.data!);
  });

  Future<CookSessionEvent> addEvent(
    String sessionId, {
    required String eventType,
    int? stepIndex,
    String source = 'CLIENT',
    Map<String, dynamic>? payload,
  }) => guardApi(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/cook-sessions/$sessionId/events',
      data: {
        'eventType': eventType,
        'stepIndex': ?stepIndex,
        'source': source,
        'payload': ?payload,
      },
    );
    return CookSessionEvent.fromJson(res.data!);
  });

  Future<List<CookSessionEvent>> events(String sessionId) => guardApi(() async {
    final res = await _dio.get<List<dynamic>>(
      '/cook-sessions/$sessionId/events',
    );
    return res.data!
        .map((e) => CookSessionEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  });

  /// 세션이 REVIEW 상태여야 한다(409 방지). 저장 시 개인 버전이 자동 생성된다.
  Future<PostCookReview> submitReview(
    String sessionId, {
    required int rating,
    String? comment,
    String? nextTimeNote,
  }) => guardApi(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/cook-sessions/$sessionId/review',
      data: {
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        if (nextTimeNote != null && nextTimeNote.isNotEmpty)
          'nextTimeNote': nextTimeNote,
      },
    );
    return PostCookReview.fromJson(res.data!);
  });

  Future<PostCookReview> review(String sessionId) => guardApi(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/cook-sessions/$sessionId/review',
    );
    return PostCookReview.fromJson(res.data!);
  });

  /// AI 미확정 — 서버가 목데이터를 돌려주고 AI_FEEDBACK_REQUESTED 이벤트를 기록한다.
  Future<AiFeedback> aiFeedback(String sessionId, String userSpeech) =>
      guardApi(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/cook-sessions/$sessionId/ai-feedback',
          data: {'userSpeech': userSpeech},
        );
        return AiFeedback.fromJson(res.data!);
      });
}

final cookSessionRepositoryProvider = Provider<CookSessionRepository>(
  (ref) => CookSessionRepository(ref.watch(dioProvider)),
);
