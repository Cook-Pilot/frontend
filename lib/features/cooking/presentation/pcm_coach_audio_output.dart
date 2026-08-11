import 'dart:typed_data';

import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

import '../application/cooking_ports.dart';

/// flutter_pcm_sound로 코치 응답 PCM16 24kHz 모노를 재생한다.
///
/// FlutterPcmSound는 전역(static) API라 이 어댑터도 앱에 하나만 두고
/// 조리 화면이 수명을 소유한다.
final class PcmSoundCoachAudioOutput implements CoachAudioOutputPort {
  static const int _sampleRate = 24000;

  bool _started = false;

  @override
  Future<void> start() async {
    await FlutterPcmSound.setLogLevel(LogLevel.none);
    await _setup();
    _started = true;
  }

  @override
  Future<void> feed(Uint8List pcm) async {
    if (!_started) {
      return;
    }
    await FlutterPcmSound.feed(
      PcmArrayInt16(
        bytes: pcm.buffer.asByteData(pcm.offsetInBytes, pcm.lengthInBytes),
      ),
    );
  }

  @override
  Future<void> flush() async {
    if (!_started) {
      return;
    }
    // flutter_pcm_sound에는 큐 비우기 API가 없다 — 재초기화가 유일한 수단.
    await FlutterPcmSound.release();
    await _setup();
  }

  @override
  Future<void> stop() async {
    if (!_started) {
      return;
    }
    _started = false;
    await FlutterPcmSound.release();
  }

  Future<void> _setup() {
    // 마이크 캡처와 동시에 재생해야 하므로 iOS는 playAndRecord가 필수다.
    return FlutterPcmSound.setup(
      sampleRate: _sampleRate,
      channelCount: 1,
      iosAudioCategory: IosAudioCategory.playAndRecord,
    );
  }
}
