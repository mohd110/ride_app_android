package com.example.riderapp

import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // flutter_overlay_window renders the floating bubble in its OWN, separate
    // Flutter engine (cached by that plugin under this tag) — not the engine
    // this Activity owns. Its own overlay<->main relay (shareData/
    // overlayListener) routes through a shared static field that gets
    // overwritten by whichever engine's plugin instance attaches last, which
    // in practice ends up being the bubble's own engine — so a tap's
    // "open_app" message loops back to itself instead of reaching this
    // engine. Registering our own channel directly on the bubble's engine
    // sidesteps that entirely: the bubble calls bringToFront on itself.
    private val bubbleEngineCacheTag = "myCachedEngine"

    private val overlayControlHandler = MethodChannel.MethodCallHandler { call, result ->
        when (call.method) {
            "bringToFront" -> {
                bringAppToFront()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rider.overlay/control")
            .setMethodCallHandler(overlayControlHandler)
        attachControlChannelToBubbleEngine()
    }

    /// The bubble's engine is created by flutter_overlay_window shortly after
    /// this Activity attaches (or lazily on first showOverlay call) — it may
    /// not exist yet the instant configureFlutterEngine runs, so retry
    /// briefly instead of silently giving up.
    private fun attachControlChannelToBubbleEngine(retriesLeft: Int = 15) {
        val bubbleEngine = FlutterEngineCache.getInstance().get(bubbleEngineCacheTag)
        if (bubbleEngine != null) {
            MethodChannel(bubbleEngine.dartExecutor.binaryMessenger, "rider.overlay/control")
                .setMethodCallHandler(overlayControlHandler)
            return
        }
        if (retriesLeft > 0) {
            Handler(Looper.getMainLooper()).postDelayed({
                attachControlChannelToBubbleEngine(retriesLeft - 1)
            }, 300)
        }
    }

    private fun bringAppToFront() {
        // Allowed because the app holds SYSTEM_ALERT_WINDOW, which exempts it
        // from Android 10+ background-activity-start restrictions.
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?.apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_NEW_TASK
                )
            }
        if (intent != null) startActivity(intent)
    }
}
