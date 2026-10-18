package com.antigravity.financas_casal_flutter

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.widget.RemoteViews
import android.widget.Toast
import java.util.Calendar

object NotificationHelper {
    const val NOTIF_CHANNEL_ID = "ctrlpig_white_high_channel_v2"
    const val ACTION_FIRE_ALARM = "com.antigravity.ctrlpig.ACTION_FIRE_ALARM"
    const val ACTION_SNOOZE_5M = "com.antigravity.ctrlpig.ACTION_SNOOZE_5M"
    const val ACTION_DISMISS = "com.antigravity.ctrlpig.ACTION_DISMISS"
    const val ACTION_MARK_TAKEN = "com.antigravity.ctrlpig.ACTION_MARK_TAKEN"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Alertas de Saúde & Finanças (Destaque Branco)"
            val descriptionText = "Notificações com fundo branco, som e botões de Adiar, Desligar e Já Tomei"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(NOTIF_CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    fun showWhiteCardNotification(context: Context, title: String, body: String, notifId: Int): Boolean {
        return try {
            ensureChannel(context)

            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            // Intent para abrir o app ao tocar no corpo da notificação
            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openPending = PendingIntent.getActivity(context, notifId, openIntent, pendingFlags)

            // Intent 1: Adiar 5 min
            val snoozeIntent = Intent(context, MedAlarmReceiver::class.java).apply {
                action = ACTION_SNOOZE_5M
                putExtra("title", title)
                putExtra("body", body)
                putExtra("id", notifId)
            }
            val snoozePending = PendingIntent.getBroadcast(context, notifId + 10000, snoozeIntent, pendingFlags)

            // Intent 2: Desligar
            val dismissIntent = Intent(context, MedAlarmReceiver::class.java).apply {
                action = ACTION_DISMISS
                putExtra("id", notifId)
            }
            val dismissPending = PendingIntent.getBroadcast(context, notifId + 20000, dismissIntent, pendingFlags)

            // Intent 3: Já Tomei
            val takenIntent = Intent(context, MedAlarmReceiver::class.java).apply {
                action = ACTION_MARK_TAKEN
                putExtra("title", title)
                putExtra("id", notifId)
            }
            val takenPending = PendingIntent.getBroadcast(context, notifId + 30000, takenIntent, pendingFlags)

            // Layout customizado de fundo branco (Estilo iFood)
            val remoteViews = RemoteViews(context.packageName, R.layout.custom_white_notification).apply {
                setTextViewText(R.id.notif_title, title)
                setTextViewText(R.id.notif_body, body)
                setOnClickPendingIntent(R.id.btn_notif_snooze, snoozePending)
                setOnClickPendingIntent(R.id.btn_notif_dismiss, dismissPending)
                setOnClickPendingIntent(R.id.btn_notif_taken, takenPending)
            }

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, NOTIF_CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context).setPriority(Notification.PRIORITY_HIGH)
            }

            builder.setSmallIcon(context.applicationInfo.icon)
                .setContentTitle(title)
                .setContentText(body)
                .setAutoCancel(true)
                .setContentIntent(openPending)
                .setColor(0xFFFFFFFF.toInt())

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                builder.setCustomContentView(remoteViews)
                builder.setCustomBigContentView(remoteViews)
                builder.setStyle(Notification.DecoratedCustomViewStyle())
            } else {
                @Suppress("DEPRECATION")
                builder.setContent(remoteViews)
            }

            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(notifId, builder.build())
            true
        } catch (e: Exception) {
            false
        }
    }

    fun scheduleExactOneShot(context: Context, triggerAtMillis: Long, title: String, body: String, notifId: Int) {
        try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, MedAlarmReceiver::class.java).apply {
                action = ACTION_FIRE_ALARM
                putExtra("title", title)
                putExtra("body", body)
                putExtra("id", notifId)
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pi = PendingIntent.getBroadcast(context, notifId, intent, flags)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
                } catch (se: SecurityException) {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
                }
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            }
        } catch (e: Exception) {}
    }
}

class MedAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: ""
        val notifId = intent.getIntExtra("id", 7001)
        val title = intent.getStringExtra("title") ?: "⏰ Hora do Medicamento • ControlPig"
        val body = intent.getStringExtra("body") ?: "Confira e registre sua dose no ControlPig."
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        when (action) {
            NotificationHelper.ACTION_FIRE_ALARM -> {
                NotificationHelper.showWhiteCardNotification(context, title, body, notifId)
            }
            NotificationHelper.ACTION_SNOOZE_5M -> {
                nm.cancel(notifId)
                val nextTrigger = System.currentTimeMillis() + (5 * 60 * 1000L)
                NotificationHelper.scheduleExactOneShot(
                    context,
                    nextTrigger,
                    title,
                    "💤 (Adiado 5 min) $body",
                    notifId
                )
                Toast.makeText(context, "💤 Alarme adiado! Repetirá em 5 minutos.", Toast.LENGTH_SHORT).show()
            }
            NotificationHelper.ACTION_DISMISS -> {
                nm.cancel(notifId)
                Toast.makeText(context, "🔕 Alarme desligado.", Toast.LENGTH_SHORT).show()
            }
            NotificationHelper.ACTION_MARK_TAKEN -> {
                nm.cancel(notifId)
                val prefs = context.getSharedPreferences("ctrlpig_native_med_actions", Context.MODE_PRIVATE)
                prefs.edit().putString("last_taken_med_title", title)
                    .putLong("last_taken_med_ts", System.currentTimeMillis())
                    .apply()
                Toast.makeText(context, "✅ Dose marcada como tomada!", Toast.LENGTH_SHORT).show()
            }
        }
    }
}

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.antigravity.ctrlpig/launcher_icon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NotificationHelper.ensureChannel(this)
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
                "showNotification" -> {
                    val title = call.argument<String>("title") ?: "ControlPig"
                    val body = call.argument<String>("body") ?: ""
                    val notifId = call.argument<Int>("id") ?: (System.currentTimeMillis() % 100000).toInt()
                    val ok = NotificationHelper.showWhiteCardNotification(this, title, body, notifId)
                    result.success(ok)
                }
                "scheduleMedAlarms" -> {
                    val alarms = call.argument<List<Map<String, Any>>>("alarms") ?: emptyList()
                    scheduleDailyAlarmsList(alarms)
                    result.success(true)
                }
                "consumePendingMedTaken" -> {
                    val prefs = getSharedPreferences("ctrlpig_native_med_actions", Context.MODE_PRIVATE)
                    val title = prefs.getString("last_taken_med_title", null)
                    val ts = prefs.getLong("last_taken_med_ts", 0L)
                    if (title != null && ts > 0L) {
                        prefs.edit().remove("last_taken_med_title").remove("last_taken_med_ts").apply()
                        result.success(mapOf("title" to title, "ts" to ts))
                    } else {
                        result.success(null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun scheduleDailyAlarmsList(alarms: List<Map<String, Any>>) {
        val now = Calendar.getInstance()
        for ((index, item) in alarms.withIndex()) {
            val hour = (item["hour"] as? Number)?.toInt() ?: continue
            val minute = (item["minute"] as? Number)?.toInt() ?: continue
            val title = (item["title"] as? String) ?: "⏰ Hora do Medicamento"
            val body = (item["body"] as? String) ?: "Hora de tomar sua medicação."
            val id = (item["id"] as? Number)?.toInt() ?: (8000 + index)

            val target = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                if (before(now)) {
                    add(Calendar.DAY_OF_YEAR, 1)
                }
            }
            NotificationHelper.scheduleExactOneShot(this, target.timeInMillis, title, body, id)
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
