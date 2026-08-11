import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../application/cooking_ports.dart';

/// 테스트에서 실제 WebSocket을 대체하기 위한 최소 전송 경계.
abstract interface class GeminiLiveConnection {
  Stream<dynamic> get messages;
  void send(String message);
  Future<void> close();
}

typedef GeminiLiveConnector =
    Future<GeminiLiveConnection> Function(Uri endpoint);

/// Gemini Live WebSocket 세션(v1beta Constrained, ephemeral token 인증).
///
/// 모델·응답 모달리티(AUDIO)·systemInstruction은 토큰에 잠겨 있으므로 setup
/// 에는 모델 이름만 보낸다. 오디오는 16kHz PCM16 모노로 올리고 24kHz PCM16
/// 모노로 받는다.
final class GeminiLiveCoachSession implements CoachLiveSessionPort {
  GeminiLiveCoachSession({
    GeminiLiveConnector? connector,
    this.setupTimeout = const Duration(seconds: 10),
  }) : _connector = connector ?? _connectWebSocket;

  final GeminiLiveConnector _connector;
  final Duration setupTimeout;

  GeminiLiveConnection? _connection;
  StreamSubscription<dynamic>? _subscription;
  bool _closedLocally = false;

  // ephemeral token은 v1beta의 Constrained 메서드에서만 인증된다 —
  // 일반 BidiGenerateContent는 1008(unregistered callers)로 거절한다(실측).
  static Uri endpointFor(String token) => Uri.parse(
    'wss://generativelanguage.googleapis.com/ws/'
    'google.ai.generativelanguage.v1beta.GenerativeService.'
    'BidiGenerateContentConstrained?access_token=$token',
  );

  @override
  Future<void> open({
    required AiLiveSessionGrant grant,
    required void Function(Uint8List pcm) onAudio,
    required void Function() onInterrupted,
    required void Function() onEnded,
    void Function()? onTurnComplete,
  }) async {
    assert(_connection == null, '세션은 1회용이다 — 재연결은 새 인스턴스로 한다.');
    final connection = await _connector(endpointFor(grant.token));
    _connection = connection;

    final setupComplete = Completer<void>();
    _subscription = connection.messages.listen(
      (raw) {
        final message = _decodeMessage(raw);
        if (message == null) {
          return;
        }
        if (message.containsKey('setupComplete')) {
          if (!setupComplete.isCompleted) {
            setupComplete.complete();
          }
          return;
        }
        final serverContent = message['serverContent'];
        if (serverContent is! Map<String, dynamic>) {
          return;
        }
        if (serverContent['interrupted'] == true) {
          onInterrupted();
        }
        if (serverContent['turnComplete'] == true) {
          onTurnComplete?.call();
        }
        final modelTurn = serverContent['modelTurn'];
        if (modelTurn is Map<String, dynamic>) {
          final parts = modelTurn['parts'];
          if (parts is List) {
            for (final part in parts) {
              if (part is! Map<String, dynamic>) {
                continue;
              }
              final inlineData = part['inlineData'];
              if (inlineData is Map<String, dynamic> &&
                  inlineData['data'] is String) {
                onAudio(base64Decode(inlineData['data'] as String));
              }
            }
          }
        }
      },
      onError: (Object _) {
        if (!setupComplete.isCompleted) {
          setupComplete.completeError(
            const CoachSessionException('코치 연결이 끊어졌어요.'),
          );
          return;
        }
        if (!_closedLocally) {
          onEnded();
        }
      },
      onDone: () {
        if (!setupComplete.isCompleted) {
          setupComplete.completeError(
            const CoachSessionException('코치 연결이 끊어졌어요.'),
          );
          return;
        }
        if (!_closedLocally) {
          onEnded();
        }
      },
    );

    connection.send(
      jsonEncode(<String, Object?>{
        'setup': <String, Object?>{'model': 'models/${grant.model}'},
      }),
    );

    try {
      await setupComplete.future.timeout(setupTimeout);
    } on TimeoutException {
      await close();
      throw const CoachSessionException('코치 연결이 준비되지 않았어요.');
    } on Object {
      await close();
      rethrow;
    }
  }

  @override
  void sendAudioChunk(Uint8List pcm) {
    final connection = _connection;
    if (connection == null || _closedLocally) {
      return;
    }
    connection.send(
      jsonEncode(<String, Object?>{
        'realtimeInput': <String, Object?>{
          'audio': <String, Object?>{
            'data': base64Encode(pcm),
            'mimeType': 'audio/pcm;rate=16000',
          },
        },
      }),
    );
  }

  @override
  Future<void> close() async {
    if (_closedLocally) {
      return;
    }
    _closedLocally = true;
    await _subscription?.cancel();
    _subscription = null;
    final connection = _connection;
    _connection = null;
    if (connection != null) {
      try {
        await connection.close();
      } catch (_) {
        // 이미 끊어진 연결을 닫다 실패해도 화면 흐름을 막지 않는다.
      }
    }
  }

  Map<String, dynamic>? _decodeMessage(Object? raw) {
    final String text;
    if (raw is String) {
      text = raw;
    } else if (raw is List<int>) {
      text = utf8.decode(raw, allowMalformed: true);
    } else {
      return null;
    }
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}

Future<GeminiLiveConnection> _connectWebSocket(Uri endpoint) async {
  final channel = WebSocketChannel.connect(endpoint);
  await channel.ready;
  return _WebSocketGeminiLiveConnection(channel);
}

final class _WebSocketGeminiLiveConnection implements GeminiLiveConnection {
  _WebSocketGeminiLiveConnection(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<dynamic> get messages => _channel.stream;

  @override
  void send(String message) {
    _channel.sink.add(message);
  }

  @override
  Future<void> close() async {
    await _channel.sink.close();
  }
}
