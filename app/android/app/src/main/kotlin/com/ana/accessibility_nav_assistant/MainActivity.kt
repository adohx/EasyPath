package com.ana.accessibility_nav_assistant

import android.app.Activity
import android.content.Intent
import android.speech.RecognizerIntent
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.ana.accessibility_nav_assistant/voice"
    private val FOCUS_CHANNEL = "com.ana.accessibility_nav_assistant/accessibility_focus"
    private val REQUEST_CODE = 42
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "startVoiceInput") {
                    pendingResult = result
                    val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                            RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
                        putExtra(RecognizerIntent.EXTRA_PROMPT, "Speak your destination")
                    }
                    try {
                        startActivityForResult(intent, REQUEST_CODE)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Speech recognition not available", null)
                        pendingResult = null
                    }
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOCUS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "focusNode") {
                    val nodeId = call.argument<Int>("nodeId")
                    Log.d("A11yFocus", "focusNode called, nodeId=$nodeId")
                    if (nodeId != null) {
                        runOnUiThread {
                            val flutterView = findFlutterView(window.decorView)
                            Log.d("A11yFocus", "flutterView=$flutterView")
                            val provider = flutterView?.accessibilityNodeProvider
                            Log.d("A11yFocus", "provider=$provider")
                            val ok = provider?.performAction(
                                nodeId,
                                AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS,
                                null
                            )
                            Log.d("A11yFocus", "performAction result=$ok")
                        }
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun findFlutterView(view: View): View? {
        if (view.javaClass.simpleName == "FlutterView") return view
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                findFlutterView(view.getChildAt(i))?.let { return it }
            }
        }
        return null
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val results = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                pendingResult?.success(results?.firstOrNull() ?: "")
            } else {
                pendingResult?.success("")
            }
            pendingResult = null
        }
    }
}
