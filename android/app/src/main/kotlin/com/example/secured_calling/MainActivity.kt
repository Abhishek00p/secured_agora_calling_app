package com.example.secured_calling

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val EXTRA_RETURN_TO_MEETING = "return_to_meeting"
    }

    private val APP_CHANNEL = "com.example.secured_calling/pip"
    private val CALL_NOTIFICATION_CHANNEL = "com.example.secured_calling/call_notification"

    @Volatile
    private var returnToMeetingFlag = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        checkReturnToMeetingIntent(intent)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        checkReturnToMeetingIntent(intent)
    }

    private fun checkReturnToMeetingIntent(intent: android.content.Intent?) {
        if (intent?.getBooleanExtra(EXTRA_RETURN_TO_MEETING, false) == true) {
            returnToMeetingFlag = true
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "moveTaskToBack" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_NOTIFICATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startOngoingCallNotification" -> {
                    val meetingName = call.argument<String>("meetingName") ?: "Meeting"
                    val intent = Intent(this, CallForegroundService::class.java).apply {
                        action = CallForegroundService.ACTION_START
                        putExtra(CallForegroundService.EXTRA_MEETING_NAME, meetingName)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stopOngoingCallNotification" -> {
                    val intent = Intent(this, CallForegroundService::class.java).apply {
                        action = CallForegroundService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(null)
                }
                "getAndClearReturnToMeetingFlag" -> {
                    val value = returnToMeetingFlag
                    returnToMeetingFlag = false
                    result.success(value)
                }
                else -> result.notImplemented()
            }
        }
    }
}
