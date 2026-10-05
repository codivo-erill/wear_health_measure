import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wear_health_measure/wear_health_measure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel(WearHealthMeasure.methodChannelName);

  EventChannel channelFor(MeasureDataType type) =>
      EventChannel('${WearHealthMeasure.eventChannelPrefix}${type.nativeName}');

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    for (final type in MeasureDataType.values) {
      messenger.setMockStreamHandler(channelFor(type), null);
    }
  });

  group('getCapabilities', () {
    test(
      'maps native names to MeasureDataType and ignores unknown ones',
      () async {
        messenger.setMockMethodCallHandler(methods, (call) async {
          expect(call.method, 'getCapabilities');
          return ['HEART_RATE_BPM', 'STEPS', 'SOMETHING_NEW', 'LOCATION'];
        });

        final caps = await const WearHealthMeasure().getCapabilities();

        expect(caps, {MeasureDataType.heartRateBpm, MeasureDataType.steps});
      },
    );

    test('maps notAvailable to HealthServicesUnavailableException', () async {
      messenger.setMockMethodCallHandler(methods, (call) async {
        throw PlatformException(code: 'notAvailable', message: 'no HS');
      });

      await expectLater(
        const WearHealthMeasure().getCapabilities(),
        throwsA(
          isA<HealthServicesUnavailableException>().having(
            (e) => e.message,
            'message',
            'no HS',
          ),
        ),
      );
    });
  });

  group('measure event mapping', () {
    test('sample of a double type', () async {
      // Each test uses its own data type: the stream cache is engine-global.
      const type = MeasureDataType.heartRateBpm;
      messenger.setMockStreamHandler(
        channelFor(type),
        MockStreamHandler.inline(
          onListen: (_, events) {
            events.success({
              'event': 'sample',
              'type': 'HEART_RATE_BPM',
              'value': 72.0,
              'timestamp': 1700000000000,
            });
            events.endOfStream();
          },
        ),
      );

      final events = await const WearHealthMeasure().measure(type).toList();

      expect(events, hasLength(1));
      final sample = events.single as MeasureSample;
      expect(sample.type, type);
      expect(sample.value, isA<double>().having((v) => v, 'value', 72.0));
      expect(
        sample.timestamp,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      expect(sample.intervalStart, isNull);
    });

    test(
      'interval sample of a long type keeps int and interval start',
      () async {
        const type = MeasureDataType.steps;
        messenger.setMockStreamHandler(
          channelFor(type),
          MockStreamHandler.inline(
            onListen: (_, events) {
              events.success({
                'event': 'sample',
                'type': 'STEPS',
                'value': 12,
                'timestamp': 2000,
                'intervalStart': 1000,
              });
              events.endOfStream();
            },
          ),
        );

        final sample =
            (await const WearHealthMeasure().measure(type).first)
                as MeasureSample;

        expect(sample.value, isA<int>().having((v) => v, 'value', 12));
        expect(sample.intervalStart, DateTime.fromMillisecondsSinceEpoch(1000));
        expect(sample.timestamp, DateTime.fromMillisecondsSinceEpoch(2000));
      },
    );

    test('availability change, including unknown names', () async {
      const type = MeasureDataType.speed;
      messenger.setMockStreamHandler(
        channelFor(type),
        MockStreamHandler.inline(
          onListen: (_, events) {
            events.success({
              'event': 'availability',
              'type': 'SPEED',
              'availability': 'ACQUIRING',
            });
            events.success({
              'event': 'availability',
              'type': 'SPEED',
              'availability': 'UNAVAILABLE_DEVICE_OFF_BODY',
            });
            events.success({
              'event': 'availability',
              'type': 'SPEED',
              'availability': 'FROM_THE_FUTURE',
            });
            events.endOfStream();
          },
        ),
      );

      final events = await const WearHealthMeasure().measure(type).toList();

      expect(
        events.cast<MeasureAvailabilityChanged>().map((e) => e.availability),
        [
          MeasureAvailability.acquiring,
          MeasureAvailability.unavailableDeviceOffBody,
          MeasureAvailability.unknown,
        ],
      );
    });
  });

  group('measure error mapping', () {
    Future<Object> firstError(MeasureDataType type, PlatformException e) {
      messenger.setMockStreamHandler(
        channelFor(type),
        MockStreamHandler.inline(
          onListen: (_, events) {
            events.error(code: e.code, message: e.message, details: e.details);
            events.endOfStream();
          },
        ),
      );
      final completer = Completer<Object>();
      const WearHealthMeasure()
          .measure(type)
          .listen(null, onError: completer.complete, cancelOnError: true);
      return completer.future;
    }

    test('permissionDenied', () async {
      final error = await firstError(
        MeasureDataType.distance,
        PlatformException(
          code: 'permissionDenied',
          message: 'needs permission',
          details: {
            'type': 'DISTANCE',
            'permission': 'android.permission.ACTIVITY_RECOGNITION',
          },
        ),
      );

      expect(
        error,
        isA<PermissionDeniedException>()
            .having((e) => e.type, 'type', MeasureDataType.distance)
            .having(
              (e) => e.permission,
              'permission',
              'android.permission.ACTIVITY_RECOGNITION',
            )
            .having((e) => e.message, 'message', 'needs permission'),
      );
    });

    test('unsupportedType', () async {
      final error = await firstError(
        MeasureDataType.pace,
        PlatformException(code: 'unsupportedType', message: 'nope'),
      );

      expect(
        error,
        isA<UnsupportedDataTypeException>().having(
          (e) => e.type,
          'type',
          MeasureDataType.pace,
        ),
      );
    });

    test('registrationFailed', () async {
      final error = await firstError(
        MeasureDataType.calories,
        PlatformException(code: 'registrationFailed', message: 'HS said no'),
      );

      expect(
        error,
        isA<MeasureRegistrationFailedException>().having(
          (e) => e.message,
          'message',
          'HS said no',
        ),
      );
    });

    test('notAvailable and unknown codes', () async {
      expect(
        await firstError(
          MeasureDataType.floors,
          PlatformException(code: 'notAvailable', message: 'phone'),
        ),
        isA<HealthServicesUnavailableException>(),
      );
      expect(
        await firstError(
          MeasureDataType.vo2Max,
          PlatformException(code: 'somethingElse'),
        ),
        isA<HealthServicesUnavailableException>(),
      );
    });
  });

  group('listener ref-counting', () {
    test('listeners share one native registration', () async {
      const type = MeasureDataType.absoluteElevation;
      var listens = 0;
      var cancels = 0;
      MockStreamHandlerEventSink? sink;
      messenger.setMockStreamHandler(
        channelFor(type),
        MockStreamHandler.inline(
          onListen: (_, events) {
            listens++;
            sink = events;
          },
          onCancel: (_) => cancels++,
        ),
      );
      Map<String, Object?> sample(double v) => {
        'event': 'sample',
        'type': type.nativeName,
        'value': v,
        'timestamp': 0,
      };

      final a = <MeasureEvent>[];
      final b = <MeasureEvent>[];
      // Two different client instances must still share the stream.
      final subA = const WearHealthMeasure().measure(type).listen(a.add);
      await pumpEventQueue();
      expect(listens, 1);

      final subB = const WearHealthMeasure().measure(type).listen(b.add);
      await pumpEventQueue();
      expect(listens, 1, reason: 'second listener must not re-register');

      sink!.success(sample(1));
      await pumpEventQueue();
      expect(a, hasLength(1));
      expect(b, hasLength(1));

      await subA.cancel();
      await pumpEventQueue();
      expect(cancels, 0, reason: 'one listener left');

      sink!.success(sample(2));
      await pumpEventQueue();
      expect(a, hasLength(1));
      expect(b, hasLength(2));

      await subB.cancel();
      await pumpEventQueue();
      expect(cancels, 1, reason: 'last listener unregisters');

      // Listening again re-registers.
      final subC = const WearHealthMeasure().measure(type).listen((_) {});
      await pumpEventQueue();
      expect(listens, 2);
      await subC.cancel();
      await pumpEventQueue();
      expect(cancels, 2);
    });

    test('each data type has its own channel', () async {
      final listened = <String>[];
      for (final type in [
        MeasureDataType.stepsDaily,
        MeasureDataType.floorsDaily,
      ]) {
        messenger.setMockStreamHandler(
          channelFor(type),
          MockStreamHandler.inline(
            onListen: (_, events) => listened.add(type.nativeName),
          ),
        );
      }

      final s1 = const WearHealthMeasure()
          .measure(MeasureDataType.stepsDaily)
          .listen((_) {});
      final s2 = const WearHealthMeasure()
          .measure(MeasureDataType.floorsDaily)
          .listen((_) {});
      await pumpEventQueue();

      expect(listened, ['STEPS_DAILY', 'FLOORS_DAILY']);
      await s1.cancel();
      await s2.cancel();
    });
  });

  test('every MeasureDataType round-trips through fromNativeName', () {
    for (final type in MeasureDataType.values) {
      expect(MeasureDataType.fromNativeName(type.nativeName), type);
    }
    expect(MeasureDataType.fromNativeName('LOCATION'), isNull);
    expect(MeasureDataType.fromNativeName(null), isNull);
  });
}
