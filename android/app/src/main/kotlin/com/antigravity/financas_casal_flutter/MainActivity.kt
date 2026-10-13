package com.antigravity.financas_casal_flutter

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ComponentName
import android.content.pm.PackageManager

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.antigravity.ctrlpig/launcher_icon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setLauncherIcon") {
                val isPositive = call.argument<Boolean>("isPositive") ?: true
                updateLauncherIcon(isPositive)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun updateLauncherIcon(isPositive: Boolean) {
        // Ícone único padrão garantido para evitar duplicação no launcher do Android
    }
}

