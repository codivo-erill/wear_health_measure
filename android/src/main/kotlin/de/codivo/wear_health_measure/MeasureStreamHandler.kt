package de.codivo.wear_health_measure

import android.content.Context
import android.content.pm.PackageManager
import android.os.SystemClock
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.health.services.client.HealthServices
import androidx.health.services.client.MeasureCallback
import androidx.health.services.client.MeasureClient
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataPointContainer
import androidx.health.services.client.data.DataTypeAvailability
import androidx.health.services.client.data.DeltaDataType
import androidx.health.services.client.data.IntervalDataPoint
import androidx.health.services.client.data.SampleDataPoint
import com.google.common.util.concurrent.FutureCallback
import com.google.common.util.concurrent.Futures
import io.flutter.plugin.common.EventChannel
import java.time.Instant

/**
 * One event channel stream for one data type.
 *
 * `onListen` registers a [MeasureCallback] with Health Services on the main
 * executor, so all callbacks arrive on the platform thread and may use the
 * [EventChannel.EventSink] directly. `onCancel` (last Dart listener gone) and
 * [dispose] (engine detached) unregister exactly that callback.
 */
internal class MeasureStreamHandler(
    private val context: Context,
    private val type: MeasureType,
) : EventChannel.StreamHandler {
    private var sink: EventChannel.EventSink? = null
    private var callback: MeasureCallback? = null
    private var client: MeasureClient? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        if (!HealthServicesSupport.isAvailable(context)) {
            fail(events, WearHealthMeasurePlugin.ERROR_NOT_AVAILABLE, HealthServicesSupport.NOT_AVAILABLE_MESSAGE)
            return
        }
        val permission = type.requiredPermission(context)
        if (permission != null &&
            ContextCompat.checkSelfPermission(context, permission) != PackageManager.PERMISSION_GRANTED
        ) {
            fail(
                events,
                WearHealthMeasurePlugin.ERROR_PERMISSION_DENIED,
                "Measuring ${type.name} requires the $permission permission.",
                mapOf("permission" to permission),
            )
            return
        }

        val measureClient = try {
            HealthServices.getClient(context).measureClient
        } catch (e: Exception) {
            fail(events, WearHealthMeasurePlugin.ERROR_NOT_AVAILABLE, e.message ?: e.toString())
            return
        }
        val measureCallback = object : MeasureCallback {
            override fun onRegistrationFailed(throwable: Throwable) {
                if (callback !== this) return
                val message = throwable.message ?: throwable.toString()
                val code = if (message.contains("not supported", ignoreCase = true)) {
                    WearHealthMeasurePlugin.ERROR_UNSUPPORTED_TYPE
                } else {
                    WearHealthMeasurePlugin.ERROR_REGISTRATION_FAILED
                }
                val sink = sink ?: return
                unregister()
                clear()
                fail(sink, code, message)
            }

            override fun onAvailabilityChanged(dataType: DeltaDataType<*, *>, availability: Availability) {
                if (callback !== this || dataType != type.dataType) return
                val name = (availability as? DataTypeAvailability)?.name ?: "UNKNOWN"
                sink?.success(
                    mapOf(
                        "event" to "availability",
                        "type" to type.name,
                        "availability" to name,
                    ),
                )
            }

            override fun onDataReceived(data: DataPointContainer) {
                if (callback !== this) return
                val sink = sink ?: return
                val bootInstant = Instant.ofEpochMilli(System.currentTimeMillis() - SystemClock.elapsedRealtime())
                for (point in data.getData(type.dataType)) {
                    val event = when (point) {
                        is SampleDataPoint<*> -> mapOf(
                            "event" to "sample",
                            "type" to type.name,
                            "value" to point.value,
                            "timestamp" to point.getTimeInstant(bootInstant).toEpochMilli(),
                        )
                        is IntervalDataPoint<*> -> mapOf(
                            "event" to "sample",
                            "type" to type.name,
                            "value" to point.value,
                            "timestamp" to point.getEndInstant(bootInstant).toEpochMilli(),
                            "intervalStart" to point.getStartInstant(bootInstant).toEpochMilli(),
                        )
                        else -> continue
                    }
                    sink.success(event)
                }
            }
        }

        sink = events
        callback = measureCallback
        client = measureClient
        try {
            measureClient.registerMeasureCallback(
                type.dataType,
                ContextCompat.getMainExecutor(context),
                measureCallback,
            )
        } catch (e: Exception) {
            clear()
            fail(events, WearHealthMeasurePlugin.ERROR_REGISTRATION_FAILED, e.message ?: e.toString())
        }
    }

    override fun onCancel(arguments: Any?) {
        unregister()
        clear()
    }

    /** Called when the engine detaches; the sink must not be used afterwards. */
    fun dispose() {
        unregister()
        clear()
    }

    private fun unregister() {
        val measureClient = client ?: return
        val measureCallback = callback ?: return
        val future = try {
            measureClient.unregisterMeasureCallbackAsync(type.dataType, measureCallback)
        } catch (e: Exception) {
            Log.w(TAG, "unregisterMeasureCallbackAsync(${type.name}) threw", e)
            return
        }
        Futures.addCallback(
            future,
            object : FutureCallback<Void?> {
                override fun onSuccess(result: Void?) {}

                override fun onFailure(t: Throwable) {
                    Log.w(TAG, "unregisterMeasureCallbackAsync(${type.name}) failed", t)
                }
            },
            ContextCompat.getMainExecutor(context),
        )
    }

    private fun clear() {
        sink = null
        callback = null
        client = null
    }

    private fun fail(
        events: EventChannel.EventSink,
        code: String,
        message: String,
        extraDetails: Map<String, Any?> = emptyMap(),
    ) {
        events.error(code, message, mapOf("type" to type.name) + extraDetails)
        events.endOfStream()
    }

    private companion object {
        const val TAG = "WearHealthMeasure"
    }
}
