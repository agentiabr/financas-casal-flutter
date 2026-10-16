package com.antigravity.financas_casal_flutter

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.antigravity.ctrlpig/launcher_icon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setLauncherIcon" -> {
                    val isPositive = call.argument<Boolean>("isPositive") ?: true
                    updateLauncherIcon(isPositive)
                    result.success(true)
                }
                "isHeadphonesConnected" -> {
                    result.success(isHeadphonesConnected())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isHeadphonesConnected(): Boolean {
        return try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                devices.any { device ->
                    device.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                    device.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
                    device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                    device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                    device.type == AudioDeviceInfo.TYPE_USB_HEADSET ||
                    device.type == AudioDeviceInfo.TYPE_HEARING_AID ||
                    (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && (
                        device.type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                        device.type == AudioDeviceInfo.TYPE_BLE_SPEAKER
                    ))
                }
            } else {
                @Suppress("DEPRECATION")
                audioManager.isWiredHeadsetOn || audioManager.isBluetoothA2dpOn || audioManager.isBluetoothScoOn
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun updateLauncherIcon(isPositive: Boolean) {
        // Ícone único padrão garantido para evitar duplicação no launcher do Android
    }
}
