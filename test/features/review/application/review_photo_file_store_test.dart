import 'dart:io';

import 'package:cookpilot/features/review/application/review_photo_file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sessionId = '40000000-0000-0000-0000-000000000001';

  late Directory documents;
  late Directory pickerCache;
  late ReviewPhotoFileStore store;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('review_photo_docs');
    pickerCache = await Directory.systemTemp.createTemp('review_photo_cache');
    store = ReviewPhotoFileStore(
      documentsDirectoryLoader: () async => documents,
    );
  });

  tearDown(() async {
    for (final directory in [documents, pickerCache]) {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });

  Future<String> writePickedFile(String name, String content) async {
    final file = File('${pickerCache.path}/$name');
    await file.writeAsString(content);
    return file.path;
  }

  test('픽커 캐시 파일을 세션 디렉토리로 복사하고 상대경로를 반환한다', () async {
    final sourcePath = await writePickedFile('picked.jpg', 'jpeg-bytes');

    final relativePath = await store.importPhoto(
      clientSessionId: sessionId,
      sourcePath: sourcePath,
    );

    expect(relativePath, startsWith('review_photos/$sessionId/'));
    expect(relativePath, endsWith('.jpg'));
    final copied = File('${documents.path}/$relativePath');
    expect(await copied.readAsString(), 'jpeg-bytes');
    // 원본(캐시)이 지워져도 복사본은 남는다.
    await File(sourcePath).delete();
    expect(await copied.exists(), isTrue);
    expect(await store.resolveAbsolutePath(relativePath), copied.path);
  });

  test('pruneMissing은 실제 존재하는 경로만 순서를 보존해 돌려준다', () async {
    final first = await store.importPhoto(
      clientSessionId: sessionId,
      sourcePath: await writePickedFile('a.jpg', 'a'),
    );
    final second = await store.importPhoto(
      clientSessionId: sessionId,
      sourcePath: await writePickedFile('b.jpg', 'b'),
    );
    await File('${documents.path}/$first').delete();

    expect(await store.pruneMissing([first, second]), [second]);
  });

  test('deletePhoto는 파일이 없어도 던지지 않고, clearSession은 디렉토리를 지운다', () async {
    final relativePath = await store.importPhoto(
      clientSessionId: sessionId,
      sourcePath: await writePickedFile('a.jpg', 'a'),
    );

    await store.deletePhoto(relativePath);
    expect(await File('${documents.path}/$relativePath').exists(), isFalse);
    // 이미 지운 경로를 다시 지워도 조용히 넘어간다.
    await store.deletePhoto(relativePath);

    await store.importPhoto(
      clientSessionId: sessionId,
      sourcePath: await writePickedFile('b.jpg', 'b'),
    );
    await store.clearSession(sessionId);
    expect(
      await Directory('${documents.path}/review_photos/$sessionId').exists(),
      isFalse,
    );
    // 세션 디렉토리가 없어도 clearSession은 던지지 않는다.
    await store.clearSession(sessionId);
  });
}
