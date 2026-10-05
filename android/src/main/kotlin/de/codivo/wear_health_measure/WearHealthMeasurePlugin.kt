package de.codivo.wear_health_measure

import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import androidx.health.services.client.HealthServices
import androidx.health.services.client.MeasureClient
import androidx.health.services.client.data.MeasureCapabilities
import com.google.common.util.concurrent.FutureCallback
import com.google.common.util.concurrent.Futures
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter plugin exposing Health Services' [MeasureClient].
 *
 * Every [FlutterEngine] gets its own instance of this class. All state lives
 * in the instance, so detaching one engine only tears down the callbacks that
 * this instance registered.
 */
class WearHealthMeasurePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var methodChannel: MethodChannel? = null
    private val eventChannels = mutableListOf<EventChannel>()
    private val streamHandlers = mutableListOf<MeasureStreamHandler>()
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        val messenger = binding.binaryMessenger

        methodChannel = MethodChannel(messenger, METHOD_CHANNEL).also {
            it.setMethodCallHandler(this)
        }

        for (type in MeasureDataTypes.all) {
            val handler = MeasureStreamHandler(context, type)
            val channel = EventChannel(messenger, "$EVENT_CHANNEL_PREFIX${type.name}")
            channel.setStreamHandler(handler)
            eventChannels += channel
            streamHandlers += handler
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        // Only the callbacks registered by this instance are unregistered.
        streamHandlers.forEach { it.dispose() }
        streamHandlers.clear()
        eventChannels.forEach { it.setStreamHandler(null) }
        eventChannels.clear()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCapabilities" -> getCapabilities(result)
            else -> result.notImplemented()
        }
    }

    private fun getCapabilities(result: MethodChannel.Result) {
        if (!HealthServicesSupport.isAvailable(context)) {
            result.error(
                ERROR_NOT_AVAILABLE,
                HealthServicesSupport.NOT_AVAILABLE_MESSAGE,
                null,
            )
            return
        }
        val future = try {
            HealthServices.getClient(context).measureClient.getCapabilitiesAsync()
        } catch (e: Exception) {
            result.error(ERROR_NOT_AVAILABLE, e.message ?: e.toString(), null)
            return
        }
        Futures.addCallback(
            future,
            object : FutureCallback<MeasureCapabilities> {
                override fun onSuccess(capabilities: MeasureCapabilities?) {
                    val supported = capabilities?.supportedDataTypesMeasure ?: emptySet()
                    result.success(
                        MeasureDataTypes.all
                            .filter { it.dataType in supported }
                            .map { it.name },
                    )
                }

                override fun onFailure(t: Throwable) {
                    result.error(ERROR_NOT_AVAILABLE, t.message ?: t.toString(), null)
                }
            },
            ContextCompat.getMainExecutor(context),
        )
    }

    companion object {
        const val METHOD_CHANNEL = "wear_health_measure/methods"
        const val EVENT_CHANNEL_PREFIX = "wear_health_measure/events/"

        const val ERROR_NOT_AVAILABLE = "notAvailable"
        const val ERROR_UNSUPPORTED_TYPE = "unsupportedType"
        const val ERROR_PERMISSION_DENIED = "permissionDenied"
        const val ERROR_REGISTRATION_FAILED = "registrationFailed"
    }
}

/** Detection of the Health Services app, which every Wear OS 3+ device ships. */
internal object HealthServicesSupport {
    private const val SERVICE_PACKAGE = "com.google.android.wearable.healthservices"
    const val NOT_AVAILABLE_MESSAGE =
        "Health Services is not available on this device (package $SERVICE_PACKAGE not installed)."

    fun isAvailable(context: Context): Boolean = try {
        context.packageManager.getPackageInfo(SERVICE_PACKAGE, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }
}
