import 'dart:async';
import 'dart:io';

import 'package:cookpilot/features/review/application/review_photo_upload_port.dart';
import 'package:cookpilot/features/review/data/review_photo_upload_api.dart';
import 'package:cookpilot/features/user/data/beta_user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const userId = '90000000-0000-0000-0000-000000000001';
  late Directory temp;
  late String photoPath;

  setUp(() async {
    BetaUserSession.setCurrentUser(
      const BetaUser(id: userId, displayName: '베타 사용자', betaNumber: 1),
    );
    temp = await Directory.systemTemp.createTemp('review_photo_upload');
    final file = File('${temp.path}/photo.jpg');
    await file.writeAsBytes([1, 2, 3]);
    photoPath = file.path;
  });

  tearDown(() async {
    BetaUserSession.clear();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('멀티파트 file 파트와 유저 헤더로 업로드하고 201의 url을 반환한다', () async {
    late http.BaseRequest captured;
    final api = ReviewPhotoUploadApi(
      baseUrl: 'http://example.test',
      client: MockClient.streaming((request, bodyStream) async {
        captured = request;
        final body = await bodyStream.toBytes();
        expect(String.fromCharCodes(body), contains('name="file"'));
        return http.StreamedResponse(
          Stream.value('{"url": "https://cdn.example.test/a.jpg"}'.codeUnits),
          201,
        );
      }),
    );

    final url = await api.upload(photoPath);

    expect(url, 'https://cdn.example.test/a.jpg');
    expect(captured.method, 'POST');
    expect(
      captured.url.toString(),
      'http://example.test/api/v1/reviews/photos',
    );
    expect(captured.headers[cookPilotUserIdHeader], userId);
    expect(captured.headers['Content-Type'], startsWith('multipart/form-data'));
  });

  test('비201·잘못된 응답·전송 오류를 ReviewPhotoUploadException으로 번역한다', () async {
    Future<void> expectUploadFailure(
      MockClientStreamHandler handler, {
      int? statusCode,
    }) async {
      final api = ReviewPhotoUploadApi(
        baseUrl: 'http://example.test',
        client: MockClient.streaming(handler),
      );
      await expectLater(
        api.upload(photoPath),
        throwsA(
          isA<ReviewPhotoUploadException>().having(
            (exception) => exception.statusCode,
            'statusCode',
            statusCode,
          ),
        ),
      );
    }

    await expectUploadFailure(
      (request, bodyStream) async =>
          http.StreamedResponse(Stream.value('oops'.codeUnits), 500),
      statusCode: 500,
    );
    await expectUploadFailure(
      (request, bodyStream) async =>
          http.StreamedResponse(Stream.value('not-json'.codeUnits), 201),
    );
    await expectUploadFailure(
      (request, bodyStream) async =>
          http.StreamedResponse(Stream.value('{"link": "x"}'.codeUnits), 201),
    );
    await expectUploadFailure(
      (request, bodyStream) async => throw http.ClientException('refused'),
    );
  });
}
