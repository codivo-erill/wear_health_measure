import 'measure_data_type.dart';

/// Base class of all errors raised by this plugin.
sealed class WearHealthMeasureException implements Exception {
  const WearHealthMeasureException(this.message);

  /// Human readable description.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Health Services is not available on this device.
///
/// Raised on non-Wear devices, on watches without the Health Services app,
/// or when the connection to Health Services fails.
final class HealthServicesUnavailableException
    extends WearHealthMeasureException {
  /// Creates the exception.
  const HealthServicesUnavailableException(super.message);
}

/// The requested data type cannot be measured on this device.
///
/// Check [WearHealthMeasure.getCapabilities] before measuring.
final class UnsupportedDataTypeException extends WearHealthMeasureException {
  /// Creates the exception.
  const UnsupportedDataTypeException(this.type, super.message);

  /// The data type that is not supported.
  final MeasureDataType type;
}

/// The app does not hold the runtime permission required for the data type.
///
/// The plugin never requests permissions; the host app must request
/// [permission] before calling [WearHealthMeasure.measure].
final class PermissionDeniedException extends WearHealthMeasureException {
  /// Creates the exception.
  const PermissionDeniedException(this.type, this.permission, super.message);

  /// The data type that was requested.
  final MeasureDataType type;

  /// The missing Android permission, e.g. `android.permission.BODY_SENSORS`.
  final String permission;
}

/// Health Services rejected the callback registration
/// (`MeasureCallback.onRegistrationFailed`), or registering threw.
final class MeasureRegistrationFailedException
    extends WearHealthMeasureException {
  /// Creates the exception.
  const MeasureRegistrationFailedException(this.type, super.message);

  /// The data type that was requested.
  final MeasureDataType type;
}
