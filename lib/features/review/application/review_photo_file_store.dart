import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/identity/uuid_v4.dart';

/// 후기 사진 파일을 앱 문서 디렉토리에 보관하는 게이트웨이.
///
/// 픽커(image_picker)가 돌려주는 경로는 OS가 언제든 지울 수 있는 캐시
/// 디렉토리라, 첨부 즉시 문서 디렉토리로 복사해야 앱 재시작 후에도 남는다.
/// 반환·입력 경로는 모두 문서 디렉토리 기준 상대경로다 — iOS는 앱
/// 업데이트·복원 때 컨테이너 절대경로가 바뀐다.
abstract interface class ReviewPhotoFileGateway {
  /// [sourcePath]의 파일을 세션 디렉토리로 복사하고 상대경로를 반환한다.
  Future<String> importPhoto({
    required String clientSessionId,
    required String sourcePath,
  });

  /// 파일 삭제는 best-effort다 — 실패해도 첨부 목록 정리를 막지 않는다.
  Future<void> deletePhoto(String relativePath);

  /// 세션의 사진 디렉토리 전체를 삭제한다(후기 저장 완료 후 정리).
  Future<void> clearSession(String clientSessionId);

  /// 파일이 실제로 존재하는 경로만 순서를 보존해 돌려준다.
  Future<List<String>> pruneMissing(List<String> relativePaths);

  /// 상대경로를 현재 컨테이너의 절대경로로 푼다.
  Future<String> resolveAbsolutePath(String relativePath);
}

typedef DocumentsDirectoryLoader = Future<Directory> Function();

final class ReviewPhotoFileStore implements ReviewPhotoFileGateway {
  ReviewPhotoFileStore({DocumentsDirectoryLoader? documentsDirectoryLoader})
    : _documentsDirectoryLoader =
          documentsDirectoryLoader ?? getApplicationDocumentsDirectory;

  static const _rootDirectoryName = 'review_photos';

  final DocumentsDirectoryLoader _documentsDirectoryLoader;

  @override
  Future<String> importPhoto({
    required String clientSessionId,
    required String sourcePath,
  }) async {
    final documents = await _documentsDirectoryLoader();
    final relativePath =
        '$_rootDirectoryName/$clientSessionId/${generateUuidV4()}.jpg';
    final destination = File('${documents.path}/$relativePath');
    await destination.parent.create(recursive: true);
    await File(sourcePath).copy(destination.path);
    return relativePath;
  }

  @override
  Future<void> deletePhoto(String relativePath) async {
    try {
      final documents = await _documentsDirectoryLoader();
      await File('${documents.path}/$relativePath').delete();
    } on Object {
      // 이미 없거나 지우지 못한 파일은 다음 clearSession이 정리한다.
    }
  }

  @override
  Future<void> clearSession(String clientSessionId) async {
    final documents = await _documentsDirectoryLoader();
    final directory = Directory(
      '${documents.path}/$_rootDirectoryName/$clientSessionId',
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  @override
  Future<List<String>> pruneMissing(List<String> relativePaths) async {
    final documents = await _documentsDirectoryLoader();
    final existing = <String>[];
    for (final relativePath in relativePaths) {
      if (await File('${documents.path}/$relativePath').exists()) {
        existing.add(relativePath);
      }
    }
    return existing;
  }

  @override
  Future<String> resolveAbsolutePath(String relativePath) async {
    final documents = await _documentsDirectoryLoader();
    return '${documents.path}/$relativePath';
  }
}
