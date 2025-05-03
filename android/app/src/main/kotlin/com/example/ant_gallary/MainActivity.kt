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
                        // 포맷 문자열 처리 (예: %1$d items)
                        try {
                            // 문자열에 숫자 포맷 지정자가 있는지 확인
                            val formatString = resources.getString(resourceId)
                            
                            // 숫자 포맷팅이 필요한 문자열 처리 (%1$d 포맷)
                            if ((key == "items" || 
                                 key == "selected_items" ||
                                 key == "delete_confirm") && 
                                call.hasArgument("arg1")) {
                                val count = call.argument<Int>("arg1") ?: 0
                                result.success(String.format(formatString, count))
                                return@setMethodCallHandler
                            }
                            
                            // 에러 메시지 처리 (%1$s 포맷)
                            if ((key == "folder_selection_error" || 
                                 key == "directory_selection_error" || 
                                 key == "error_message" || 
                                 key == "cannot_load_image") && 
                                call.hasArgument("arg1")) {
                                val errorMsg = call.argument<String>("arg1") ?: ""
                                result.success(String.format(formatString, errorMsg))
                                return@setMethodCallHandler
                            }
                            
                            // 기본 문자열 반환
                            result.success(formatString)
                        } catch (e: Exception) {
                            // 예외 발생 시 원본 문자열 반환
                            result.success(resources.getString(resourceId))
                        }
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
