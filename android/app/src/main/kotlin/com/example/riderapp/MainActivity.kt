package com.example.riderapp

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rider.overlay/control")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "bringToFront" -> {
                        // Bring MainActivity back to the foreground when the floating
                        // bubble is tapped. Allowed because the app holds
                        // SYSTEM_ALERT_WINDOW, which exempts it from Android 10+
                        // background-activity-start restrictions.
                        val intent = packageManager.getLaunchIntentForPackage(packageName)
                            ?.apply {
                                addFlags(
                                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                                    Intent.FLAG_ACTIVITY_NEW_TASK
                                )
                            }
                        if (intent != null) startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
