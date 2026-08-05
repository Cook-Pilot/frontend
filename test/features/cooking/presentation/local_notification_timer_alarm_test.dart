import 'package:cookpilot/features/cooking/presentation/local_notification_timer_alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final testCase in <({bool? permission, String scheduleMode})>[
    (permission: true, scheduleMode: 'exactAllowWhileIdle'),
    (permission: false, scheduleMode: 'inexactAllowWhileIdle'),
    (permission: null, scheduleMode: 'inexactAllowWhileIdle'),
  ]) {
    test('Android exact permission ${testCase.permission}은 '
        '${testCase.scheduleMode}로 예약한다', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      final calls = <MethodCall>[];
      final flowEvents = <bool>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'initialize' => true,
              'requestNotificationsPermission' => true,
              'requestExactAlarmsPermission' => testCase.permission,
              'zonedSchedule' => null,
              _ => null,
            };
          });

      final alarm = await LocalNotificationTimerAlarm.initialize(
        onPermissionFlowChanged: flowEvents.add,
      );
      await alarm.scheduleTimerElapsed(
        DateTime.now().add(const Duration(minutes: 1)),
      );

      expect(flowEvents, <bool>[true, false]);
      expect(calls.take(3).map((call) => call.method), <String>[
        'initialize',
        'requestNotificationsPermission',
        'requestExactAlarmsPermission',
      ]);
      final scheduleCall = calls.singleWhere(
        (call) => call.method == 'zonedSchedule',
      );
      final arguments = Map<Object?, Object?>.from(
        scheduleCall.arguments as Map<Object?, Object?>,
      );
      final platformSpecifics = Map<Object?, Object?>.from(
        arguments['platformSpecifics'] as Map<Object?, Object?>,
      );
      expect(platformSpecifics['scheduleMode'], testCase.scheduleMode);
    });
  }

  test('Android permission channel 실패도 finally에서 owned flow를 닫는다', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final flowEvents = <bool>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'requestExactAlarmsPermission') {
            throw PlatformException(code: 'exact_alarm_request_failed');
          }
          return true;
        });

    await expectLater(
      LocalNotificationTimerAlarm.initialize(
        onPermissionFlowChanged: flowEvents.add,
      ),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'exact_alarm_request_failed',
        ),
      ),
    );
    expect(flowEvents, <bool>[true, false]);
  });

  test('iOS는 initialize 자동 요청을 끄고 explicit 권한 flow를 알린다', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    final calls = <MethodCall>[];
    final flowEvents = <bool>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });

    await LocalNotificationTimerAlarm.initialize(
      onPermissionFlowChanged: flowEvents.add,
    );

    expect(flowEvents, <bool>[true, false]);
    expect(calls.map((call) => call.method), <String>[
      'initialize',
      'requestPermissions',
    ]);
    final initialization = Map<Object?, Object?>.from(
      calls.first.arguments as Map<Object?, Object?>,
    );
    expect(initialization['requestAlertPermission'], isFalse);
    expect(initialization['requestBadgePermission'], isFalse);
    expect(initialization['requestSoundPermission'], isFalse);
    final explicitRequest = Map<Object?, Object?>.from(
      calls.last.arguments as Map<Object?, Object?>,
    );
    expect(explicitRequest['alert'], isTrue);
    expect(explicitRequest['badge'], isTrue);
    expect(explicitRequest['sound'], isTrue);
  });
}
