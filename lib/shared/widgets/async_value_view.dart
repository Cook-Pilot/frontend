import 'package:cookpilot/app/app_theme.dart';
import 'package:cookpilot/core/network/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AsyncValue를 로딩/에러/데이터 3상태로 그린다. 에러엔 재시도 버튼을 붙인다.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.onRetry,
    required this.builder,
    this.loadingHeight = 220,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T data) builder;
  final double loadingHeight;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (data) => builder(context, data),
      loading: () => SizedBox(
        height: loadingHeight,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => ApiErrorView(error: error, onRetry: onRetry),
    );
  }
}

class ApiErrorView extends StatelessWidget {
  const ApiErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;
    final isNetwork = api?.isNetwork ?? true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppColors.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isNetwork ? '서버에 연결할 수 없어요' : '요청을 처리하지 못했어요',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            api?.message ?? error.toString(),
            style: const TextStyle(color: AppColors.slate),
          ),
          if (isNetwork) ...[
            const SizedBox(height: 6),
            const Text(
              '백엔드가 떠 있는지 확인하세요: ../backend → ./gradlew bootRun (8080)',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

/// 조리 중 액션(단계 이동/완료 등) 실패는 스낵바로 알린다.
void showApiError(BuildContext context, Object error) {
  final message = error is ApiException ? error.message : error.toString();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
