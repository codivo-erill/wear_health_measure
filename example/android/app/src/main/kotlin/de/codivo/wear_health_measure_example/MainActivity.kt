package de.codivo.wear_health_measure_example

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var secondEngine: FlutterEngine? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestMissingPermissions()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wear_health_measure_example/multi_engine")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "spawnAndDestroy" -> {
                        spawnAndDestroySecondEngine()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Multi-engine check: creates a second FlutterEngine (which registers every
     * plugin again, like background engines of e.g. flutter_foreground_task do),
     * runs the `secondEngineMain` entrypoint, and destroys the engine 3 seconds
     * later. A measurement running in the first engine must keep delivering.
     */
    private fun spawnAndDestroySecondEngine() {
        secondEngine?.destroy()
        val engine = FlutterEngine(applicationContext)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault().let {
                DartExecutor.DartEntrypoint(it.pathToBundle, "secondEngineMain")
            },
        )
        secondEngine = engine
        Handler(Looper.getMainLooper()).postDelayed({
            if (secondEngine === engine) {
                engine.destroy()
                secondEngine = null
            }
        }, 3_000)
    }

    override fun onDestroy() {
        secondEngine?.destroy()
        secondEngine = null
        super.onDestroy()
    }

    private fun requestMissingPermissions() {
        val heartRate = if (Build.VERSION.SDK_INT >= 36) {
            "android.permission.health.READ_HEART_RATE"
        } else {
            Manifest.permission.BODY_SENSORS
        }
        val wanted = listOf(
            heartRate,
            Manifest.permission.ACTIVITY_RECOGNITION,
            Manifest.permission.ACCESS_FINE_LOCATION,
        )
        val missing = wanted.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, missing.toTypedArray(), 1)
        }
    }
}
