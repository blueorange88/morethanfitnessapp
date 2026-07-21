package com.example.mtf_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
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
                val action = pendingWidgetAction ?: intent
                    ?.getStringExtra(EXTRA_WIDGET_ACTION)
                    .orEmpty()
                pendingWidgetAction = null
                intent?.removeExtra(EXTRA_WIDGET_ACTION)
                result.success(action)
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
        pendingWidgetAction = intent?.getStringExtra(EXTRA_WIDGET_ACTION)
        super.onCreate(savedInstanceState)

        // 월요일 00:01 위젯 주차 자동 롤오버 예약
        MtfWidgetWeekRolloverReceiver.scheduleNext(this)
        MtfWidgetWeekRolloverReceiver.scheduleNextTimeRefresh(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = intent.getStringExtra(EXTRA_WIDGET_ACTION).orEmpty()
        if (action.isEmpty()) return
        pendingWidgetAction = action
        widgetNavigationChannel?.invokeMethod("widgetAction", action)
        pendingWidgetAction = null
        intent.removeExtra(EXTRA_WIDGET_ACTION)
    }

    override fun getInitialRoute(): String {
        val targetRoute = intent?.getStringExtra("mtf_route")
        return targetRoute ?: "/"
    }

    companion object {
        const val EXTRA_WIDGET_ACTION = "mtf_widget_action"
        const val WIDGET_ACTION_TODAY = "today"
        private const val WIDGET_NAVIGATION_CHANNEL =
            "com.example.mtf_app/widget_navigation"
    }
}
