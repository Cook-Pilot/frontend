import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/cooking/data/gemini_live_coach_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const grant = AiLiveSessionGrant(
    token: 'auth_tokens/test-token',
    model: 'gemini-live-test',
  );

  test('토큰은 access_token 쿼리로 v1beta Constrained 엔드포인트에 붙는다', () {
    final endpoint = GeminiLiveCoachSession.endpointFor(grant.token);

    expect(endpoint.scheme, 'wss');
    expect(endpoint.path, contains('v1beta'));
    expect(endpoint.path, contains('BidiGenerateContentConstrained'));
    expect(endpoint.queryParameters['access_token'], grant.token);
  });

  test('setup에는 모델만 보내고, 오디오 조각을 base64로 올린다', () async {
    final connection = _FakeGeminiLiveConnection();
    final session = GeminiLiveCoachSession(connector: (_) async => connection);

    await session.open(
      grant: grant,
      onAudio: (_) {},
      onInterrupted: () {},
      onEnded: () {},
    );
    session.sendAudioChunk(Uint8List.fromList(<int>[1, 2, 3, 4]));

    final setup = connection.decodedSent.first['setup'] as Map<String, dynamic>;
    expect(setup, <String, Object?>{'model': 'models/gemini-live-test'});

    final realtimeInput =
        connection.decodedSent.last['realtimeInput'] as Map<String, dynamic>;
    final audio = realtimeInput['audio'] as Map<String, dynamic>;
    expect(audio['mimeType'], 'audio/pcm;rate=16000');
    expect(base64Decode(audio['data'] as String), <int>[1, 2, 3, 4]);

    await session.close();
    expect(connection.closed, isTrue);
  });

  test('inlineData 오디오 조각과 interrupted 신호를 콜백으로 전달한다', () async {
    final connection = _FakeGeminiLiveConnection();
    final session = GeminiLiveCoachSession(connector: (_) async => connection);
    final received = <List<int>>[];
    var interrupted = 0;

    await session.open(
      grant: grant,
      onAudio: received.add,
      onInterrupted: () => interrupted++,
      onEnded: () {},
    );
    connection.emitServerAudio(<int>[10, 20]);
    connection.emitServerAudio(<int>[30], binaryFrame: true);
    connection.emitInterrupted();
    await _drainMicrotasks();

    expect(received, <List<int>>[
      <int>[10, 20],
      <int>[30],
    ]);
    expect(interrupted, 1);
    await session.close();
  });

  test('turnComplete 신호를 콜백으로 전달한다', () async {
    final connection = _FakeGeminiLiveConnection();
    final session = GeminiLiveCoachSession(connector: (_) async => connection);
    var turnCompletes = 0;

    await session.open(
      grant: grant,
      onAudio: (_) {},
      onInterrupted: () {},
      onEnded: () {},
      onTurnComplete: () => turnCompletes++,
    );
    connection.emitTurnComplete();
    await _drainMicrotasks();

    expect(turnCompletes, 1);
    await session.close();
  });

  test('setupComplete가 오지 않으면 준비 실패로 던지고 연결을 닫는다', () async {
    final connection = _FakeGeminiLiveConnection(autoSetupComplete: false);
    final session = GeminiLiveCoachSession(
      connector: (_) async => connection,
      setupTimeout: const Duration(milliseconds: 50),
    );

    await expectLater(
      session.open(
        grant: grant,
        onAudio: (_) {},
        onInterrupted: () {},
        onEnded: () {},
      ),
      throwsA(
        isA<CoachSessionException>().having(
          (e) => e.message,
          'message',
          '코치 연결이 준비되지 않았어요.',
        ),
      ),
    );
    expect(connection.closed, isTrue);
  });

  test('서버가 연결을 끝내면 onEnded가 오고, 내가 닫을 때는 오지 않는다', () async {
    final serverClosed = _FakeGeminiLiveConnection();
    final session = GeminiLiveCoachSession(
      connector: (_) async => serverClosed,
    );
    var ended = 0;
    await session.open(
      grant: grant,
      onAudio: (_) {},
      onInterrupted: () {},
      onEnded: () => ended++,
    );
    serverClosed.endStream();
    await _drainMicrotasks();
    expect(ended, 1);

    final locallyClosed = _FakeGeminiLiveConnection();
    final second = GeminiLiveCoachSession(
      connector: (_) async => locallyClosed,
    );
    await second.open(
      grant: grant,
      onAudio: (_) {},
      onInterrupted: () {},
      onEnded: () => fail('close() 후에는 onEnded가 오면 안 된다'),
    );
    await second.close();
    locallyClosed.endStream();
    await _drainMicrotasks();
  });
}

Future<void> _drainMicrotasks() => Future<void>.delayed(Duration.zero);

final class _FakeGeminiLiveConnection implements GeminiLiveConnection {
  _FakeGeminiLiveConnection({this.autoSetupComplete = true});

  final bool autoSetupComplete;
  final List<Map<String, dynamic>> decodedSent = <Map<String, dynamic>>[];
  final StreamController<dynamic> _incoming = StreamController<dynamic>();
  bool closed = false;

  @override
  Stream<dynamic> get messages => _incoming.stream;

  @override
  void send(String message) {
    final decoded = jsonDecode(message) as Map<String, dynamic>;
    decodedSent.add(decoded);
    if (autoSetupComplete && decoded.containsKey('setup')) {
      _emit(<String, Object?>{'setupComplete': <String, Object?>{}});
    }
  }

  @override
  Future<void> close() async {
    closed = true;
    if (!_incoming.isClosed) {
      await _incoming.close();
    }
  }

  void emitServerAudio(List<int> pcm, {bool binaryFrame = false}) {
    _emit(<String, Object?>{
      'serverContent': <String, Object?>{
        'modelTurn': <String, Object?>{
          'parts': <Object?>[
            <String, Object?>{
              'inlineData': <String, Object?>{
                'mimeType': 'audio/pcm;rate=24000',
                'data': base64Encode(pcm),
              },
            },
          ],
        },
      },
    }, binaryFrame: binaryFrame);
  }

  void emitInterrupted() {
    _emit(<String, Object?>{
      'serverContent': <String, Object?>{'interrupted': true},
    });
  }

  void emitTurnComplete() {
    _emit(<String, Object?>{
      'serverContent': <String, Object?>{'turnComplete': true},
    });
  }

  void endStream() {
    if (!_incoming.isClosed) {
      unawaited(_incoming.close());
    }
  }

  void _emit(Map<String, Object?> message, {bool binaryFrame = false}) {
    final encoded = jsonEncode(message);
    _incoming.add(binaryFrame ? utf8.encode(encoded) : encoded);
  }
}
