/// A delta data type that Health Services' `MeasureClient` can deliver.
///
/// Every value corresponds to a `DataType.<nativeName>` constant of
/// `androidx.health:health-services-client`. Which of them a watch can
/// actually measure is device specific; many watches only support
/// [heartRateBpm]. Query [WearHealthMeasure.getCapabilities] first.
///
/// `LOCATION` is intentionally not part of this release.
enum MeasureDataType {
  /// Current heart rate in beats per minute. `double`, sample.
  heartRateBpm('HEART_RATE_BPM', isIntegral: false, isInterval: false),

  /// Steps taken since the last update. `int`, interval.
  steps('STEPS', isIntegral: true, isInterval: true),

  /// Steps taken while walking since the last update. `int`, interval.
  walkingSteps('WALKING_STEPS', isIntegral: true, isInterval: true),

  /// Steps taken while running since the last update. `int`, interval.
  runningSteps('RUNNING_STEPS', isIntegral: true, isInterval: true),

  /// Step rate in steps per minute. `int`, sample.
  stepsPerMinute('STEPS_PER_MINUTE', isIntegral: true, isInterval: false),

  /// Distance delta in meters. `double`, interval.
  distance('DISTANCE', isIntegral: false, isInterval: true),

  /// Speed in meters per second. `double`, sample.
  speed('SPEED', isIntegral: false, isInterval: false),

  /// Pace in milliseconds per kilometer, `0` while not moving. `double`,
  /// sample.
  pace('PACE', isIntegral: false, isInterval: false),

  /// Calories burned (basal rate plus activity) since the last update.
  /// `double`, interval.
  calories('CALORIES', isIntegral: false, isInterval: true),

  /// Absolute elevation in meters. `double`, sample.
  absoluteElevation('ABSOLUTE_ELEVATION', isIntegral: false, isInterval: false),

  /// Elevation gained since the last update in meters. `double`, interval.
  elevationGain('ELEVATION_GAIN', isIntegral: false, isInterval: true),

  /// Elevation lost since the last update in meters. `double`, interval.
  elevationLoss('ELEVATION_LOSS', isIntegral: false, isInterval: true),

  /// Floors climbed since the last update, partial floors allowed. `double`,
  /// interval.
  floors('FLOORS', isIntegral: false, isInterval: true),

  /// Maximum rate of oxygen consumption, range 0 to 100. `double`, sample.
  vo2Max('VO2_MAX', isIntegral: false, isInterval: false),

  /// Distance over declining ground since the last update in meters.
  /// `double`, interval.
  declineDistance('DECLINE_DISTANCE', isIntegral: false, isInterval: true),

  /// Seconds spent on declining ground since the last update. `int`,
  /// interval.
  declineDuration('DECLINE_DURATION', isIntegral: true, isInterval: true),

  /// Distance over flat ground since the last update in meters. `double`,
  /// interval.
  flatGroundDistance(
    'FLAT_GROUND_DISTANCE',
    isIntegral: false,
    isInterval: true,
  ),

  /// Seconds spent on flat ground since the last update. `int`, interval.
  flatGroundDuration(
    'FLAT_GROUND_DURATION',
    isIntegral: true,
    isInterval: true,
  ),

  /// Distance over inclining ground since the last update in meters.
  /// `double`, interval.
  inclineDistance('INCLINE_DISTANCE', isIntegral: false, isInterval: true),

  /// Seconds spent on inclining ground since the last update. `int`,
  /// interval.
  inclineDuration('INCLINE_DURATION', isIntegral: true, isInterval: true),

  /// Golf shots since the last update. `int`, interval.
  golfShotCount('GOLF_SHOT_COUNT', isIntegral: true, isInterval: true),

  /// Swimming strokes since the last update. `int`, interval.
  swimmingStrokes('SWIMMING_STROKES', isIntegral: true, isInterval: true),

  /// Swimming laps since the last update. `int`, interval.
  swimmingLapCount('SWIMMING_LAP_COUNT', isIntegral: true, isInterval: true),

  /// Exercise repetitions since the last update. `int`, interval.
  repCount('REP_COUNT', isIntegral: true, isInterval: true),

  /// Seconds the user rested during an exercise since the last update. `int`,
  /// interval.
  restingExerciseDuration(
    'RESTING_EXERCISE_DURATION',
    isIntegral: true,
    isInterval: true,
  ),

  /// Ground contact time of a single step in milliseconds. `int`, sample.
  groundContactTime('GROUND_CONTACT_TIME', isIntegral: true, isInterval: false),

  /// Vertical oscillation per step in centimeters. `double`, sample.
  verticalOscillation(
    'VERTICAL_OSCILLATION',
    isIntegral: false,
    isInterval: false,
  ),

  /// Vertical oscillation divided by stride length. `double`, sample.
  verticalRatio('VERTICAL_RATIO', isIntegral: false, isInterval: false),

  /// Stride length in meters. `double`, sample.
  strideLength('STRIDE_LENGTH', isIntegral: false, isInterval: false),

  /// Total steps since local midnight. `int`, interval.
  stepsDaily('STEPS_DAILY', isIntegral: true, isInterval: true),

  /// Total floors climbed since local midnight. `double`, interval.
  floorsDaily('FLOORS_DAILY', isIntegral: false, isInterval: true),

  /// Total elevation gain since local midnight in meters. `double`, interval.
  elevationGainDaily(
    'ELEVATION_GAIN_DAILY',
    isIntegral: false,
    isInterval: true,
  ),

  /// Total calories since local midnight. `double`, interval.
  caloriesDaily('CALORIES_DAILY', isIntegral: false, isInterval: true),

  /// Total distance since local midnight in meters. `double`, interval.
  distanceDaily('DISTANCE_DAILY', isIntegral: false, isInterval: true);

  const MeasureDataType(
    this.nativeName, {
    required this.isIntegral,
    required this.isInterval,
  });

  /// Name of the `DataType` constant in health-services-client, used on the
  /// wire.
  final String nativeName;

  /// Whether values are integral (`Long` natively, `int` in Dart).
  final bool isIntegral;

  /// Whether values cover an interval (`IntervalDataPoint`) rather than a
  /// point in time (`SampleDataPoint`).
  final bool isInterval;

  /// Looks up a type by its [nativeName], or returns `null` if unknown.
  static MeasureDataType? fromNativeName(String? name) {
    for (final type in values) {
      if (type.nativeName == name) return type;
    }
    return null;
  }
}
