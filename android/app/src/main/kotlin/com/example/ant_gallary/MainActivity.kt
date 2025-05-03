package com.example.ant_gallary

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app_strings_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        
        // Method Channel 설정
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getString") {
                val key = call.argument<String>("key")
                if (key != null) {
                    val resourceId = resources.getIdentifier(key, "string", packageName)
                    if (resourceId != 0) {
                        result.success(resources.getString(resourceId))
                    } else {
                        result.error("RESOURCE_NOT_FOUND", "String resource not found: $key", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "Key is required", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
