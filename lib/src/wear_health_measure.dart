import 'package:flutter/services.dart';

import 'exceptions.dart';
import 'measure_data_type.dart';
import 'measure_event.dart';

/// Access to the Wear OS Health Services `MeasureClient`.
///
/// Live sensor readings without an exercise session. Data is only delivered
/// while the app is in the foreground; Health Services stops delivering when
/// the app goes to the background.
class WearHealthMeasure {
  /// Creates a client. Instances are cheap and share native state through
  /// the plugin's channels.
  const WearHealthMeasure();

  /// Name of the method channel.
  static const String methodChannelName = 'wear_health_measure/methods';

  /// Prefix of the per-data-type event channels; the data type's
  /// [MeasureDataType.nativeName] is appended.
  static const String eventChannelPrefix = 'wear_health_measure/events/';

  static const MethodChannel _methods = MethodChannel(methodChannelName);

  /// One broadcast stream per data type for the whole engine.
  ///
  /// Channel names are global per engine, and a second
  /// `receiveBroadcastStream()` on the same channel would replace the first
  /// one's message handler. Caching here is what makes several Dart
  /// listeners share a single native registration.
  static final Map<MeasureDataType, Stream<MeasureEvent>> _streams = {};

  /// The data types this watch can measure.
  ///
  /// Throws [HealthServicesUnavailableException] when Health Services is not
  /// available, e.g. on a phone.
  Future<Set<MeasureDataType>> getCapabilities() async {
    final List<Object?>? names;
    try {
      names = await _methods.invokeListMethod<Object?>('getCapabilities');
    } on PlatformException catch (e) {
      throw _mapException(e, null);
    }
    return {
      for (final name in names ?? const [])
        ?MeasureDataType.fromNativeName(name as String?),
    };
  }

  /// A stream of [MeasureEvent]s for [type].
  ///
  /// The first listener registers a native `MeasureCallback`, the last
  /// listener to cancel unregisters it. Additional listeners share the
  /// registration. Keep subscriptions short: a registered callback raises
  /// the sensor sampling rate and power consumption.
  ///
  /// Errors are delivered as [WearHealthMeasureException] subclasses, after
  /// which the stream closes:
  /// - [HealthServicesUnavailableException]
  /// - [UnsupportedDataTypeException]
  /// - [PermissionDeniedException]
  /// - [MeasureRegistrationFailedException]
  Stream<MeasureEvent> measure(MeasureDataType type) =>
      _streams.putIfAbsent(type, () => _createStream(type));

  static Stream<MeasureEvent> _createStream(MeasureDataType type) {
    final channel = EventChannel('$eventChannelPrefix${type.nativeName}');
    return channel
        .receiveBroadcastStream()
        .map((event) => _mapEvent(type, event))
        .handleError(
          (Object error) =>
              throw _mapException(error as PlatformException, type),
          test: (error) => error is PlatformException,
        );
  }

  static MeasureEvent _mapEvent(MeasureDataType type, Object? raw) {
    final map = (raw as Map).cast<String, Object?>();
    switch (map['event']) {
      case 'sample':
        final value = map['value'] as num;
        final intervalStart = map['intervalStart'] as int?;
        return MeasureSample(
          type,
          value: type.isIntegral ? value.toInt() : value.toDouble(),
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            map['timestamp'] as int,
          ),
          intervalStart: intervalStart == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(intervalStart),
        );
      case 'availability':
        return MeasureAvailabilityChanged(
          type,
          MeasureAvailability.fromNativeName(map['availability'] as String?),
        );
      case final other:
        throw StateError('Unknown measure event "$other"');
    }
  }

  static WearHealthMeasureException _mapException(
    PlatformException e,
    MeasureDataType? type,
  ) {
    final message = e.message ?? e.code;
    final details = e.details is Map
        ? (e.details as Map).cast<String, Object?>()
        : const <String, Object?>{};
    final resolvedType =
        type ?? MeasureDataType.fromNativeName(details['type'] as String?);
    return switch (e.code) {
      'unsupportedType' when resolvedType != null =>
        UnsupportedDataTypeException(resolvedType, message),
      'permissionDenied' when resolvedType != null => PermissionDeniedException(
        resolvedType,
        details['permission'] as String? ?? 'unknown',
        message,
      ),
      'registrationFailed' when resolvedType != null =>
        MeasureRegistrationFailedException(resolvedType, message),
      _ => HealthServicesUnavailableException(message),
    };
  }
}
