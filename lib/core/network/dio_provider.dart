import 'package:cookpilot/core/config/api_config.dart';
import 'package:cookpilot/core/network/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앱 전역 Dio. 모든 요청은 `{baseUrl}/api/v1` 아래로 나간다.
/// 인증이 확정되면 여기 Authorization 인터셉터를 추가한다.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.apiBaseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );

  // DioException을 화면이 다루는 ApiException으로 바꿔서 올려보낸다.
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (e, handler) => handler.reject(
        DioException(
          requestOptions: e.requestOptions,
          response: e.response,
          type: e.type,
          error: ApiException.fromDio(e),
        ),
      ),
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true),
    );
  }

  ref.onDispose(dio.close);
  return dio;
});

/// repository에서 공통으로 쓰는 호출 래퍼. Dio 에러를 ApiException으로 정규화한다.
Future<T> guardApi<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    final error = e.error;
    throw error is ApiException ? error : ApiException.fromDio(e);
  }
}
