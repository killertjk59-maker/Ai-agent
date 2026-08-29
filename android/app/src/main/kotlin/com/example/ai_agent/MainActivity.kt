package com.example.ai_agent

import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "ai_agent/accessibility"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> result.success(isAccessibilityServiceEnabled())
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "captureScreen" -> {
                    val service = AgentAccessibilityService.instance
                    if (service == null) {
                        result.success(null)
                    } else {
                        result.success(service.captureScreen())
                    }
                }
                "performAction" -> {
                    val service = AgentAccessibilityService.instance
                    if (service == null) {
                        result.error("NO_SERVICE", "Accessibility service not running", null)
                        return@setMethodCallHandler
                    }
                    val args = call.arguments as Map<*, *>
                    when (args["type"] as String) {
                        "tap" -> service.performTap((args["x"] as Int), (args["y"] as Int))
                        "input_text" -> service.performInputText(args["text"] as String)
                        "scroll" -> service.performScroll(args["direction"] as? String ?: "down")
                        "back" -> service.performBack()
                        "wait" -> { /* no-op, handled by delay in Dart */ }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expected = "$packageName/${AgentAccessibilityService::class.java.name}"
        val enabledServices = Settings.Secure.getString(
            contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabledServices)
        while (splitter.hasNext()) {
            if (splitter.next().equals(expected, ignoreCase = true)) return true
        }
        return false
    }
}
