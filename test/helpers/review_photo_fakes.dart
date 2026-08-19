import 'dart:async';

import 'package:cookpilot/features/review/application/review_photo_file_store.dart';
import 'package:cookpilot/features/review/application/review_photo_upload_port.dart';
import 'package:cookpilot/features/review/presentation/review_photo_picker.dart';

/// 지정된 경로를 순서대로 돌려주는 픽커 fake. 큐가 비면 취소(null)로 본다.
final class FakeReviewPhotoPicker implements ReviewPhotoPickerPort {
  final List<String?> queuedResults = [];
  final List<ReviewPhotoSource> requestedSources = [];
  Object? error;

  @override
  Future<String?> pick(ReviewPhotoSource source) async {
    requestedSources.add(source);
    if (error != null) {
      throw error!;
    }
    return queuedResults.isEmpty ? null : queuedResults.removeAt(0);
  }
}

/// 업로드 호출을 기록하고, 지정된 경로는 실패시키는 fake.
final class FakeReviewPhotoUploadPort implements ReviewPhotoUploadPort {
  final List<String> uploadedPaths = [];
  final Set<String> failingPaths = {};
  Object? error;
  Completer<void>? gate;

  @override
  Future<String> upload(String absolutePath) async {
    final pendingGate = gate;
    if (pendingGate != null) {
      await pendingGate.future;
    }
    uploadedPaths.add(absolutePath);
    if (error != null) {
      throw error!;
    }
    if (failingPaths.contains(absolutePath)) {
      throw const ReviewPhotoUploadException('사진을 업로드하지 못했습니다. (500)');
    }
    return 'https://cdn.example.test/${absolutePath.split('/').last}';
  }
}

/// 실제 파일시스템 없이 상대경로만 관리하는 인메모리 파일 보관소.
final class InMemoryReviewPhotoFileStore implements ReviewPhotoFileGateway {
  final Set<String> existingPaths = {};
  final List<String> deletedPaths = [];
  final List<String> clearedSessions = [];
  var importCount = 0;

  @override
  Future<String> importPhoto({
    required String clientSessionId,
    required String sourcePath,
  }) async {
    importCount += 1;
    final relativePath =
        'review_photos/$clientSessionId/imported-$importCount.jpg';
    existingPaths.add(relativePath);
    return relativePath;
  }

  @override
  Future<void> deletePhoto(String relativePath) async {
    existingPaths.remove(relativePath);
    deletedPaths.add(relativePath);
  }

  @override
  Future<void> clearSession(String clientSessionId) async {
    clearedSessions.add(clientSessionId);
    existingPaths.removeWhere(
      (path) => path.startsWith('review_photos/$clientSessionId/'),
    );
  }

  @override
  Future<void> clearAll() async {
    existingPaths.clear();
  }

  @override
  Future<List<String>> pruneMissing(List<String> relativePaths) async {
    return relativePaths.where(existingPaths.contains).toList(growable: false);
  }

  @override
  Future<String> resolveAbsolutePath(String relativePath) async {
    return '/documents/$relativePath';
  }
}
