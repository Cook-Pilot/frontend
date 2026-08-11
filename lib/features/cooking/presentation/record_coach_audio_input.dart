import 'dart:typed_data';

import 'package:record/record.dart';

import '../application/cooking_ports.dart';

/// record 패키지로 마이크 PCM16 16kHz 모노 스트림을 캡처한다.
///
/// 에코 캔슬을 켠다 — 스피커로 나가는 코치 음성이 마이크로 되돌아가
/// 모델이 자기 말에 barge-in 당하는 것을 완화한다.
final class RecordCoachAudioInput implements CoachAudioInputPort {
  AudioRecorder? _recorder;

  @override
  Future<Stream<Uint8List>> start() async {
    await stop();
    final recorder = AudioRecorder();
    _recorder = recorder;
    if (!await recorder.hasPermission()) {
      await stop();
      throw const CoachMicrophonePermissionDenied();
    }
    return recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        // 기본 소스에서는 하드웨어 AEC가 안 걸려 코치 음성이 마이크로 되돌아
        // self barge-in 된다(실기기 확인). 통화용 경로로 바꿔 AEC가 재생
        // 신호를 참조하게 한다. speakerphone은 조리 중 사용 형태(폰을 두고
        // 스피커로 듣기) 그대로다.
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceCommunication,
          audioManagerMode: AudioManagerMode.modeInCommunication,
          speakerphone: true,
        ),
      ),
    );
  }

  @override
  Future<void> stop() async {
    final recorder = _recorder;
    _recorder = null;
    if (recorder == null) {
      return;
    }
    await recorder.stop();
    await recorder.dispose();
  }
}
