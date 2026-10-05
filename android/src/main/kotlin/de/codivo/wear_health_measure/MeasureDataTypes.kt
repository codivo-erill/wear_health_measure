package de.codivo.wear_health_measure

import android.Manifest
import android.content.Context
import android.os.Build
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.DeltaDataType

/**
 * A numeric delta data type exposed to Dart.
 *
 * @param name the `DataType` constant name, used as the wire identifier.
 * @param dataType the Health Services data type.
 * @param permissionGroup the permission the host app needs, or null when
 *   Google's documentation does not state one for this type.
 */
internal class MeasureType(
    val name: String,
    val dataType: DeltaDataType<*, *>,
    private val permissionGroup: PermissionGroup?,
) {
    /** The runtime permission required on this device, or null if none is documented. */
    fun requiredPermission(context: Context): String? = permissionGroup?.permission(context)
}

/**
 * Permission groups as documented at
 * https://developer.android.com/health-and-fitness/health-services/permissions
 */
internal enum class PermissionGroup {
    /** Heart rate: BODY_SENSORS up to API 35, READ_HEART_RATE for API 36+ targets. */
    HEART_RATE {
        override fun permission(context: Context): String {
            val targetSdk = context.applicationInfo.targetSdkVersion
            return if (Build.VERSION.SDK_INT >= 36 && targetSdk >= 36) {
                READ_HEART_RATE
            } else {
                Manifest.permission.BODY_SENSORS
            }
        }
    },
    ACTIVITY_RECOGNITION {
        override fun permission(context: Context) = Manifest.permission.ACTIVITY_RECOGNITION
    },
    FINE_LOCATION {
        override fun permission(context: Context) = Manifest.permission.ACCESS_FINE_LOCATION
    };

    abstract fun permission(context: Context): String

    companion object {
        /** `android.health.connect.HealthPermissions.READ_HEART_RATE`, a runtime permission since API 36. */
        const val READ_HEART_RATE = "android.permission.health.READ_HEART_RATE"
    }
}

/** All delta data types with Double or Long values; LOCATION is not included. */
internal object MeasureDataTypes {
    private val ACTIVITY = PermissionGroup.ACTIVITY_RECOGNITION

    val all: List<MeasureType> = listOf(
        MeasureType("HEART_RATE_BPM", DataType.HEART_RATE_BPM, PermissionGroup.HEART_RATE),
        MeasureType("STEPS", DataType.STEPS, ACTIVITY),
        MeasureType("WALKING_STEPS", DataType.WALKING_STEPS, ACTIVITY),
        MeasureType("RUNNING_STEPS", DataType.RUNNING_STEPS, ACTIVITY),
        MeasureType("STEPS_PER_MINUTE", DataType.STEPS_PER_MINUTE, ACTIVITY),
        MeasureType("DISTANCE", DataType.DISTANCE, ACTIVITY),
        MeasureType("SPEED", DataType.SPEED, ACTIVITY),
        MeasureType("PACE", DataType.PACE, ACTIVITY),
        MeasureType("CALORIES", DataType.CALORIES, ACTIVITY),
        MeasureType("ABSOLUTE_ELEVATION", DataType.ABSOLUTE_ELEVATION, PermissionGroup.FINE_LOCATION),
        MeasureType("ELEVATION_GAIN", DataType.ELEVATION_GAIN, ACTIVITY),
        MeasureType("ELEVATION_LOSS", DataType.ELEVATION_LOSS, ACTIVITY),
        MeasureType("FLOORS", DataType.FLOORS, ACTIVITY),
        MeasureType("VO2_MAX", DataType.VO2_MAX, null),
        MeasureType("DECLINE_DISTANCE", DataType.DECLINE_DISTANCE, ACTIVITY),
        MeasureType("DECLINE_DURATION", DataType.DECLINE_DURATION, null),
        MeasureType("FLAT_GROUND_DISTANCE", DataType.FLAT_GROUND_DISTANCE, ACTIVITY),
        MeasureType("FLAT_GROUND_DURATION", DataType.FLAT_GROUND_DURATION, null),
        MeasureType("INCLINE_DISTANCE", DataType.INCLINE_DISTANCE, ACTIVITY),
        MeasureType("INCLINE_DURATION", DataType.INCLINE_DURATION, null),
        MeasureType("GOLF_SHOT_COUNT", DataType.GOLF_SHOT_COUNT, ACTIVITY),
        MeasureType("SWIMMING_STROKES", DataType.SWIMMING_STROKES, ACTIVITY),
        MeasureType("SWIMMING_LAP_COUNT", DataType.SWIMMING_LAP_COUNT, ACTIVITY),
        MeasureType("REP_COUNT", DataType.REP_COUNT, ACTIVITY),
        MeasureType("RESTING_EXERCISE_DURATION", DataType.RESTING_EXERCISE_DURATION, null),
        MeasureType("GROUND_CONTACT_TIME", DataType.GROUND_CONTACT_TIME, null),
        MeasureType("VERTICAL_OSCILLATION", DataType.VERTICAL_OSCILLATION, null),
        MeasureType("VERTICAL_RATIO", DataType.VERTICAL_RATIO, null),
        MeasureType("STRIDE_LENGTH", DataType.STRIDE_LENGTH, null),
        MeasureType("STEPS_DAILY", DataType.STEPS_DAILY, ACTIVITY),
        MeasureType("FLOORS_DAILY", DataType.FLOORS_DAILY, ACTIVITY),
        MeasureType("ELEVATION_GAIN_DAILY", DataType.ELEVATION_GAIN_DAILY, null),
        MeasureType("CALORIES_DAILY", DataType.CALORIES_DAILY, ACTIVITY),
        MeasureType("DISTANCE_DAILY", DataType.DISTANCE_DAILY, ACTIVITY),
    )
}
