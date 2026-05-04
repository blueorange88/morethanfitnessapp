package com.example.mtf_app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun getInitialRoute(): String {
        val targetRoute = intent?.getStringExtra("mtf_route")
        return targetRoute ?: "/"
    }
}