import 'dart:async';

import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/cooking/presentation/timer_alarm_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared 초기화는 listener fan-out과 active late replay를 제공한다', () async {
    final completion = Completer<TimerAlarmPort>();
    late TimerAlarmPermissionFlowChanged broadcast;
    var initializeCount = 0;
    final provider = TimerAlarmProvider(
      initialize: (onPermissionFlowChanged) {
        initializeCount++;
        broadcast = onPermissionFlowChanged;
        return completion.future;
      },
    );
    final firstEvents = <bool>[];
    final lateEvents = <bool>[];

    final first = provider.resolve(onPermissionFlowChanged: firstEvents.add);
    broadcast(true);
    final late = provider.resolve(onPermissionFlowChanged: lateEvents.add);

    expect(initializeCount, 1);
    expect(firstEvents, <bool>[true]);
    expect(lateEvents, <bool>[true]);

    broadcast(false);
    completion.complete(const SilentTimerAlarm());
    await Future.wait(<Future<TimerAlarmPort>>[first.alarm, late.alarm]);
    expect(firstEvents, <bool>[true, false]);
    expect(lateEvents, <bool>[true, false]);
  });

  test('명시 cancel은 shared 초기화를 유지하고 해당 listener만 즉시 제거한다', () async {
    final completion = Completer<TimerAlarmPort>();
    late TimerAlarmPermissionFlowChanged broadcast;
    final provider = TimerAlarmProvider(
      initialize: (onPermissionFlowChanged) {
        broadcast = onPermissionFlowChanged;
        return completion.future;
      },
    );
    final cancelledEvents = <bool>[];
    final retainedEvents = <bool>[];
    final cancelled = provider.resolve(
      onPermissionFlowChanged: cancelledEvents.add,
    );
    final retained = provider.resolve(
      onPermissionFlowChanged: retainedEvents.add,
    );

    cancelled.cancel();
    cancelled.cancel();
    broadcast(true);
    broadcast(false);
    completion.complete(const SilentTimerAlarm());
    await Future.wait(<Future<TimerAlarmPort>>[
      cancelled.alarm,
      retained.alarm,
    ]);

    expect(cancelledEvents, isEmpty);
    expect(retainedEvents, <bool>[true, false]);
  });

  test('성공 완료는 모든 listener를 자동 정리한다', () async {
    final completion = Completer<TimerAlarmPort>();
    late TimerAlarmPermissionFlowChanged broadcast;
    final provider = TimerAlarmProvider(
      initialize: (onPermissionFlowChanged) {
        broadcast = onPermissionFlowChanged;
        return completion.future;
      },
    );
    final events = <bool>[];
    final registration = provider.resolve(onPermissionFlowChanged: events.add);

    completion.complete(const SilentTimerAlarm());
    await registration.alarm;
    broadcast(true);

    expect(events, isEmpty);
  });

  test('실패 완료도 listener를 자동 정리하고 원래 오류를 보존한다', () async {
    final completion = Completer<TimerAlarmPort>();
    late TimerAlarmPermissionFlowChanged broadcast;
    final provider = TimerAlarmProvider(
      initialize: (onPermissionFlowChanged) {
        broadcast = onPermissionFlowChanged;
        return completion.future;
      },
    );
    final events = <bool>[];
    final registration = provider.resolve(onPermissionFlowChanged: events.add);
    final failure = StateError('alarm init failed');
    final expectation = expectLater(registration.alarm, throwsA(same(failure)));

    completion.completeError(failure);
    await expectation;
    broadcast(true);

    expect(events, isEmpty);
  });

  test('한 listener 예외가 다른 listener fan-out을 막지 않는다', () async {
    final completion = Completer<TimerAlarmPort>();
    late TimerAlarmPermissionFlowChanged broadcast;
    final provider = TimerAlarmProvider(
      initialize: (onPermissionFlowChanged) {
        broadcast = onPermissionFlowChanged;
        return completion.future;
      },
    );
    final events = <bool>[];
    final faulty = provider.resolve(
      onPermissionFlowChanged: (_) => throw StateError('disposed listener'),
    );
    final healthy = provider.resolve(onPermissionFlowChanged: events.add);

    broadcast(true);
    broadcast(false);
    completion.complete(const SilentTimerAlarm());
    await Future.wait(<Future<TimerAlarmPort>>[faulty.alarm, healthy.alarm]);

    expect(events, <bool>[true, false]);
  });
}
