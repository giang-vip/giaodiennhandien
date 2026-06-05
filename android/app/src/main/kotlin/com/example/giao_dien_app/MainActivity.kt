package com.example.giao_dien_app

import android.location.Location
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "mock_location_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isMockLocation") {
                val locationManager = getSystemService(LOCATION_SERVICE) as android.location.LocationManager
                val providers = locationManager.getProviders(true)

                var isMock = false
                for (provider in providers) {
                    val loc = locationManager.getLastKnownLocation(provider)
                    if (loc != null && loc.isFromMockProvider) {
                        isMock = true
                        break
                    }
                }

                result.success(isMock)

            }
        }
    }
}

