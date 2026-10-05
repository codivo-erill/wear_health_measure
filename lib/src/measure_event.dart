import 'measure_data_type.dart';

/// Availability of a sensor-backed [MeasureDataType].
///
/// Mirrors Health Services' `DataTypeAvailability`.
enum MeasureAvailability {
  /// Availability is unknown, or a value this plugin version cannot parse.
  unknown,

  /// Data is available and samples are being delivered.
  available,

  /// The sensor is warming up; data will follow shortly.
  acquiring,

  /// The data type is currently unavailable.
  unavailable,

  /// The device is not worn (no skin contact), so no data can be measured.
  unavailableDeviceOffBody;

  /// Maps the native name (e.g. `AVAILABLE`) to an enum value.
  ///
  /// Unknown names map to [unknown].
  static MeasureAvailability fromNativeName(String? name) => switch (name) {
    'AVAILABLE' => available,
    'ACQUIRING' => acquiring,
    'UNAVAILABLE' => unavailable,
    'UNAVAILABLE_DEVICE_OFF_BODY' => unavailableDeviceOffBody,
    _ => unknown,
  };
}

/// An event emitted by [WearHealthMeasure.measure].
///
/// Either a [MeasureSample] carrying a value or a
/// [MeasureAvailabilityChanged] notification.
sealed class MeasureEvent {
  const MeasureEvent(this.type);

  /// The data type this event belongs to.
  final MeasureDataType type;
}

/// A single measured value.
///
/// For sample data types (e.g. heart rate) [timestamp] is the time of the
/// reading and [intervalStart] is `null`. For interval data types (e.g. steps,
/// distance) the value covers the interval from [intervalStart] to
/// [timestamp].
final class MeasureSample extends MeasureEvent {
  /// Creates a sample.
  const MeasureSample(
    super.type, {
    required this.value,
    required this.timestamp,
    this.intervalStart,
  });

  /// The measured value.
  ///
  /// A `double` for `Double` data types and an `int` for `Long` data types;
  /// see [MeasureDataType.isIntegral].
  final num value;

  /// Time of the reading, or the end of the interval for interval data types.
  final DateTime timestamp;

  /// Start of the interval for interval data types, otherwise `null`.
  final DateTime? intervalStart;

  @override
  String toString() =>
      'MeasureSample(${type.name}, $value, $timestamp'
      '${intervalStart == null ? '' : ', from $intervalStart'})';
}

/// Notification that the sensor availability of a data type changed.
final class MeasureAvailabilityChanged extends MeasureEvent {
  /// Creates an availability notification.
  const MeasureAvailabilityChanged(super.type, this.availability);

  /// The new availability.
  final MeasureAvailability availability;

  @override
  String toString() =>
      'MeasureAvailabilityChanged(${type.name}, ${availability.name})';
}
