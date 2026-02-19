package com.example.secured_calling

import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.secured_calling/pip"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "enterPipMode") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val intent = Intent(this, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                    }
                    val pendingIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)
                    val action = RemoteAction(
                        Icon.createWithResource(this, R.mipmap.ic_launcher),
                        "Back to app",
                        "Back to app",
                        pendingIntent
                    )
                    val params = PictureInPictureParams.Builder()
                        .setAspectRatio(Rational(9, 16))
                        .setActions(listOf(action))
                        .build()
                    enterPictureInPictureMode(params)
                    result.success(null)
                } else {
                    result.error("UNAVAILABLE", "Picture-in-Picture not supported on this device.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
