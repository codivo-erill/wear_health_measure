# wear_health_measure

[![CI](https://github.com/codivo-erill/wear_health_measure/actions/workflows/ci.yml/badge.svg)](https://github.com/codivo-erill/wear_health_measure/actions/workflows/ci.yml)

Live sensor readings on Wear OS through the Health Services **MeasureClient**:
heart rate, steps, speed and the other numeric delta data types, **without
starting an exercise session**.

Android / Wear OS only (Wear OS 3+, `minSdk 30`).

## When to use this instead of `workout`

[`workout`](https://pub.dev/packages/workout) wraps the Health Services
**ExerciseClient**. That is the right tool when your app *is* a workout app:
one exercise session per device, exercise-type-specific permissions (e.g.
location), and the session interacts with the watch vendor's own activity
tracking. It also ends the exercise when a FlutterEngine detaches, which in
multi-engine apps (e.g. `flutter_foreground_task`) can tear down the workout
when a *background* engine is destroyed.

If you only want to **show a live value** (the current heart rate on a tile or a
screen) you want `MeasureClient`, and that is all this plugin does:

- No exercise session, ever.
- Safe to be attached to several FlutterEngines in one process. Detaching an
  engine only unregisters the callbacks that engine registered.
- Callbacks are delivered on the main thread.
- Several Dart listeners for the same data type share one native registration.

## Foreground only

`MeasureClient` delivers data **only while your app is in the foreground**.
Health Services stops the sensor when the app goes to the background and this
plugin does not try to work around that. For background heart rate you need the
PassiveMonitoringClient or an exercise session, both out of scope here.

Keep subscriptions short: a registered callback raises the sensor sampling rate
and therefore power consumption.

## Permissions

The plugin **does not request permissions**. It checks them before registering
and raises `PermissionDeniedException` with the missing permission name. Your
app declares and requests them.

| Data types | Permission |
|---|---|
| `heartRateBpm` | `android.permission.BODY_SENSORS` on Wear OS 5.1 (API 35) and lower. `android.permission.health.READ_HEART_RATE` on Wear OS 6 (API 36) and higher **when your app targets API 36+**. |
| `steps`, `walkingSteps`, `runningSteps`, `stepsPerMinute`, `distance`, `distanceDaily`, `declineDistance`, `flatGroundDistance`, `inclineDistance`, `speed`, `pace`, `calories`, `caloriesDaily`, `elevationGain`, `elevationLoss`, `floors`, `floorsDaily`, `golfShotCount`, `repCount`, `swimmingLapCount`, `swimmingStrokes`, `stepsDaily` | `android.permission.ACTIVITY_RECOGNITION` |
| `absoluteElevation` | `android.permission.ACCESS_FINE_LOCATION` |
| `vo2Max`, `groundContactTime`, `verticalOscillation`, `verticalRatio`, `strideLength`, `declineDuration`, `flatGroundDuration`, `inclineDuration`, `restingExerciseDuration`, `elevationGainDaily` | Not documented by Google. The plugin performs no pre-check; a missing permission surfaces as `MeasureRegistrationFailedException`. |

Source: [Declare appropriate permissions (Health Services)](https://developer.android.com/health-and-fitness/health-services/permissions)
and [Android 16 behavior changes](https://developer.android.com/about/versions/16/behavior-changes-16).

Manifest for heart rate that works on both sides of the API 36 change:

```xml
<uses-permission android:name="android.permission.BODY_SENSORS"
    android:maxSdkVersion="35" />
<uses-permission android:name="android.permission.health.READ_HEART_RATE" />
```

Request `READ_HEART_RATE` on devices with `Build.VERSION.SDK_INT >= 36`,
`BODY_SENSORS` otherwise (both are regular runtime permissions on Wear OS).

## Usage

```dart
import 'package:wear_health_measure/wear_health_measure.dart';

const measure = WearHealthMeasure();

// What can this watch measure? Many watches only support heart rate.
final types = await measure.getCapabilities();
if (!types.contains(MeasureDataType.heartRateBpm)) return;

// Listening registers the native callback, cancelling the last listener
// unregisters it.
final subscription = measure.measure(MeasureDataType.heartRateBpm).listen(
  (event) {
    switch (event) {
      case MeasureSample(:final value, :final timestamp):
        print('$value bpm at $timestamp');
      case MeasureAvailabilityChanged(:final availability):
        print('sensor: ${availability.name}'); // acquiring, available, ...
    }
  },
  onError: (Object e) {
    switch (e) {
      case PermissionDeniedException(:final permission):
        // request `permission`, then listen again
      case UnsupportedDataTypeException():
      case HealthServicesUnavailableException(): // e.g. running on a phone
      case MeasureRegistrationFailedException():
        print(e);
    }
  },
);

// Later:
await subscription.cancel();
```

### Events

- `MeasureSample(type, value, timestamp, intervalStart)` — `value` is a
  `double` for `Double` data types and an `int` for `Long` data types
  (`MeasureDataType.isIntegral`). Interval types such as `steps` carry the
  interval in `intervalStart`…`timestamp`; sample types such as `heartRateBpm`
  have `intervalStart == null`.
- `MeasureAvailabilityChanged(type, availability)` — `unknown`, `available`,
  `acquiring`, `unavailable`, `unavailableDeviceOffBody`.

### Errors

All errors extend the sealed `WearHealthMeasureException`, so a `switch` can
be exhaustive:

| Exception | Meaning |
|---|---|
| `HealthServicesUnavailableException` | No Health Services on this device (phone, old watch) or the connection failed. |
| `UnsupportedDataTypeException` | The watch cannot measure this type. Check `getCapabilities()` first. |
| `PermissionDeniedException` | Missing runtime permission; `permission` names it. |
| `MeasureRegistrationFailedException` | Health Services rejected the registration (`onRegistrationFailed`). |

After an error the stream closes. Listen again to retry.

## Supported data types

All numeric (`Double`/`Long`) delta data types of
`androidx.health:health-services-client` 1.1.0: `heartRateBpm`, `steps`,
`walkingSteps`, `runningSteps`, `stepsPerMinute`, `distance`, `speed`, `pace`,
`calories`, `absoluteElevation`, `elevationGain`, `elevationLoss`, `floors`,
`vo2Max`, `declineDistance`, `declineDuration`, `flatGroundDistance`,
`flatGroundDuration`, `inclineDistance`, `inclineDuration`, `golfShotCount`,
`swimmingStrokes`, `swimmingLapCount`, `repCount`, `restingExerciseDuration`,
`groundContactTime`, `verticalOscillation`, `verticalRatio`, `strideLength`,
`stepsDaily`, `floorsDaily`, `elevationGainDaily`, `caloriesDaily`,
`distanceDaily`.

Which of them a device actually supports is reported by `getCapabilities()`;
expect many watches to support only `heartRateBpm`.

**Not included:** `LOCATION` (non-numeric `LocationData`) is left out of this
release.

## Example

`example/` is a Wear OS app that lists the capabilities, lets you start and
stop a measurement per type, shows values and availability, and has a
"Multi-engine check" button that spawns and destroys a second FlutterEngine
while a measurement is running.

## Out of scope

ExerciseClient, PassiveMonitoringClient, permission request UI, iOS/watchOS.
