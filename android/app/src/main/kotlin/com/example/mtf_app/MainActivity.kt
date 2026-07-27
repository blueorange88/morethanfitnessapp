package com.example.mtf_app

import android.Manifest
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val cameraPermissionChannel = "com.example.mtf_app/camera_permission"
    private val cameraPermissionRequestCode = 4102
    private var pendingCameraPermissionResult: MethodChannel.Result? = null
    private var pendingWidgetAction: String? = null
    private var widgetActionWasColdStart = false
    private var pendingWidgetActionSource = "none"
    private var widgetNavigationChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            cameraPermissionChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "check" -> result.success(cameraPermissionStatus())
                "request" -> requestCameraPermission(result)
                "openSettings" -> {
                    val intent = Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:$packageName"),
                    )
                    startActivity(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        widgetNavigationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIDGET_NAVIGATION_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "consume") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val action = pendingWidgetAction ?: widgetActionFromIntent(intent)
                val source = pendingWidgetActionSource
                val coldStart = widgetActionWasColdStart
                pendingWidgetAction = null
                pendingWidgetActionSource = "none"
                clearConsumedWidgetAction(intent)
                logWidgetDeepLink(
                    coldStart = coldStart,
                    consumed = action.isNotEmpty(),
                    result = if (action.isNotEmpty()) "delivered" else "empty",
                )
                widgetActionWasColdStart = false
                result.success(
                    mapOf(
                        "action" to action,
                        "coldStart" to coldStart,
                        "source" to source,
                    ),
                )
            }
        }
    }

    private fun cameraPermissionStatus(): String {
        return if (
            ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            "granted"
        } else if (ActivityCompat.shouldShowRequestPermissionRationale(
                this,
                Manifest.permission.CAMERA,
            )
        ) {
            "denied"
        } else {
            val requestedBefore = getPreferences(MODE_PRIVATE)
                .getBoolean("camera_permission_requested", false)
            if (requestedBefore) "permanentlyDenied" else "denied"
        }
    }

    private fun requestCameraPermission(result: MethodChannel.Result) {
        if (cameraPermissionStatus() == "granted") {
            result.success("granted")
            return
        }
        if (pendingCameraPermissionResult != null) {
            result.error("request_in_progress", "Camera permission request is active.", null)
            return
        }
        pendingCameraPermissionResult = result
        getPreferences(MODE_PRIVATE).edit()
            .putBoolean("camera_permission_requested", true)
            .apply()
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.CAMERA),
            cameraPermissionRequestCode,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != cameraPermissionRequestCode) return
        pendingCameraPermissionResult?.success(cameraPermissionStatus())
        pendingCameraPermissionResult = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingWidgetAction = widgetActionFromIntent(intent)
        widgetActionWasColdStart = pendingWidgetAction == WIDGET_ACTION_TODAY
        pendingWidgetActionSource = if (widgetActionWasColdStart) "onCreate" else "none"
        if (widgetActionWasColdStart) {
            logWidgetTap(state = "cold", result = "received")
        }
        super.onCreate(savedInstanceState)
        logWidgetActivity("onCreate", intent, pendingWidgetAction)

        // 월요일 00:01 위젯 주차 자동 롤오버 예약
        MtfWidgetWeekRolloverReceiver.scheduleNext(this)
        MtfWidgetWeekRolloverReceiver.scheduleNextTimeRefresh(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = widgetActionFromIntent(intent)
        logWidgetActivity("onNewIntent", intent, action)
        if (action.isEmpty()) return
        widgetActionWasColdStart = false
        logWidgetTap(state = "warm", result = "received")
        val channel = widgetNavigationChannel
        if (channel == null) {
            pendingWidgetAction = action
            pendingWidgetActionSource = "onNewIntent"
            return
        }

        pendingWidgetAction = null
        pendingWidgetActionSource = "none"
        clearConsumedWidgetAction(intent)
        fun restorePendingAction() {
            if (pendingWidgetAction == null) {
                pendingWidgetAction = action
                pendingWidgetActionSource = "onNewIntent"
            }
        }
        channel.invokeMethod(
            "widgetAction",
            action,
            object : MethodChannel.Result {
                override fun success(result: Any?) = Unit

                override fun error(
                    errorCode: String,
                    errorMessage: String?,
                    errorDetails: Any?,
                ) = restorePendingAction()

                override fun notImplemented() = restorePendingAction()
            },
        )
    }

    override fun onResume() {
        super.onResume()
        if (pendingWidgetAction == WIDGET_ACTION_TODAY) {
            logWidgetDeepLink(
                coldStart = widgetActionWasColdStart,
                consumed = false,
                result = "activity_foreground",
            )
        }
    }

    private fun logWidgetTap(state: String, result: String) {
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) return
        Log.d(
            TAG_DAILY_WIDGET_TAP,
            "state=$state pendingIntentType=activity action=openTodaySchedule " +
                "activityLaunchRequested=true result=$result",
        )
    }

    private fun widgetActionFromIntent(candidate: Intent?): String {
        if (candidate == null) return ""
        val extraAction = candidate.getStringExtra(EXTRA_WIDGET_ACTION).orEmpty()
        val hasTodayIdentity =
            candidate.action == openTodayScheduleAction(packageName) &&
                isTodayWidgetData(candidate.data)
        return if (hasTodayIdentity && extraAction == WIDGET_ACTION_TODAY) {
            WIDGET_ACTION_TODAY
        } else {
            ""
        }
    }

    private fun isTodayWidgetData(data: Uri?): Boolean {
        if (data == null) return false
        return data.scheme == getString(R.string.mtf_widget_intent_scheme) &&
            data.host == "widget" &&
            data.pathSegments.firstOrNull() == "today"
    }

    private fun clearConsumedWidgetAction(candidate: Intent?) {
        if (candidate == null) return
        candidate.removeExtra(EXTRA_WIDGET_ACTION)
        if (candidate.action == openTodayScheduleAction(packageName)) {
            candidate.action = null
        }
        if (isTodayWidgetData(candidate.data)) {
            candidate.data = null
        }
    }

    private fun logWidgetActivity(callback: String, candidate: Intent?, action: String?) {
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) return
        val actionMatched = candidate?.action == openTodayScheduleAction(packageName)
        val dataMatched = isTodayWidgetData(candidate?.data)
        Log.d(
            TAG_DAILY_WIDGET_ACTIVITY,
            "callback=$callback actionMatched=$actionMatched dataMatched=$dataMatched " +
                "isTaskRoot=$isTaskRoot activityForegroundRequested=true " +
                "result=${if (action == WIDGET_ACTION_TODAY) "received" else "ignored"}",
        )
    }

    private fun logWidgetDeepLink(coldStart: Boolean, consumed: Boolean, result: String) {
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) return
        Log.d(
            TAG_DAILY_WIDGET_DEEPLINK,
            "coldStart=$coldStart activityForeground=true " +
                "homeReady=false consumed=$consumed result=$result",
        )
    }

    override fun getInitialRoute(): String {
        val targetRoute = intent?.getStringExtra("mtf_route")
        return targetRoute ?: "/"
    }

    companion object {
        const val EXTRA_WIDGET_ACTION = "mtf_widget_action"
        const val WIDGET_ACTION_TODAY = "today"
        fun openTodayScheduleAction(packageName: String) =
            "$packageName.action.OPEN_TODAY_SCHEDULE"
        private const val TAG_DAILY_WIDGET_TAP = "MTF_DAILY_WIDGET_TAP"
        private const val TAG_DAILY_WIDGET_DEEPLINK = "MTF_DAILY_WIDGET_DEEPLINK"
        private const val TAG_DAILY_WIDGET_ACTIVITY = "MTF_DAILY_WIDGET_ACTIVITY"
        private const val WIDGET_NAVIGATION_CHANNEL =
            "com.example.mtf_app/widget_navigation"
    }
}
