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
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.speech.tts.TextToSpeech
import android.widget.RemoteViews
import android.widget.Toast
import java.util.Calendar
import java.util.Locale

object AlarmAudioPlayer {
    private var ringtone: Ringtone? = null
    private var tts: TextToSpeech? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val handler = Handler(Looper.getMainLooper())
    private var isStopped = false

    fun playAlarmAndSpeak(context: Context, speechText: String) {
        val appCtx = context.applicationContext
        stop()
        isStopped = false

        // 1. Mantém a CPU acordada por até 68s para repetir o alarme de 10 em 10s durante 1 minuto
        try {
            val pm = appCtx.getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "ctrlpig:MedAlarmWakeLock"
            ).apply {
                acquire(68000L)
            }
        } catch (_: Exception) {}

        // 2. Prepara o som de alarme do celular no canal USAGE_ALARM (audível mesmo com o app fechado)
        try {
            var alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            if (alarmUri == null) {
                alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            }
            if (alarmUri != null) {
                val r = RingtoneManager.getRingtone(appCtx, alarmUri)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    r.audioAttributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                } else {
                    @Suppress("DEPRECATION")
                    r.streamType = AudioManager.STREAM_ALARM
                }
                ringtone = r
                r.play()
                handler.postDelayed({
                    try { ringtone?.stop() } catch (_: Exception) {}
                }, 2200L)
            }
        } catch (_: Exception) {}

        // 3. Fala em voz alta (TTS nativo Android no canal de Alarme) repetindo de 10 em 10 segundos durante 1 minuto (0s, 10s, 20s, 30s, 40s, 50s, 60s)
        try {
            tts = TextToSpeech(appCtx) { status ->
                if (status == TextToSpeech.SUCCESS && !isStopped) {
                    try {
                        val engine = tts ?: return@TextToSpeech
                        val ptBr = Locale("pt", "BR")
                        val res = engine.setLanguage(ptBr)
                        if (res == TextToSpeech.LANG_MISSING_DATA || res == TextToSpeech.LANG_NOT_SUPPORTED) {
                            engine.setLanguage(Locale.getDefault())
                        }
                        engine.setSpeechRate(0.98f)
                        engine.setPitch(1.0f)

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            val attrs = AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_ALARM)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                                .build()
                            engine.setAudioAttributes(attrs)
                        }

                        val params = Bundle().apply {
                            putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, AudioManager.STREAM_ALARM)
                            putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, 1.0f)
                        }

                        // Ciclos de 10 em 10 segundos durante 1 minuto (60s)
                        val offsetsMs = longArrayOf(2200L, 10000L, 20000L, 30000L, 40000L, 50000L, 60000L)
                        for ((idx, delayMs) in offsetsMs.withIndex()) {
                            handler.postDelayed({
                                if (!isStopped) {
                                    try { ringtone?.stop() } catch (_: Exception) {}
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                        engine.speak(speechText, TextToSpeech.QUEUE_FLUSH, params, "med_alarm_cycle_$idx")
                                    } else {
                                        @Suppress("DEPRECATION")
                                        engine.speak(speechText, TextToSpeech.QUEUE_FLUSH, null)
                                    }
                                }
                            }, delayMs)
                        }

                        // Encerra automaticamente após completar 1 minuto
                        handler.postDelayed({
                            if (!isStopped) {
                                stop()
                            }
                        }, 66000L)
                    } catch (_: Exception) {}
                }
            }
        } catch (_: Exception) {}
    }

    fun stop() {
        isStopped = true
        handler.removeCallbacksAndMessages(null)
        try {
            ringtone?.stop()
            ringtone = null
        } catch (_: Exception) {}
        try {
            tts?.stop()
            tts?.shutdown()
            tts = null
        } catch (_: Exception) {}
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
            wakeLock = null
        } catch (_: Exception) {}
    }
}

object NotificationHelper {
    const val NOTIF_CHANNEL_ID = "ctrlpig_white_high_channel_v3"
    const val NOTIF_SHOPPING_CHANNEL_ID = "ctrlpig_shopping_channel_v1"
    const val ACTION_FIRE_ALARM = "com.antigravity.ctrlpig.ACTION_FIRE_ALARM"
    const val ACTION_SNOOZE_5M = "com.antigravity.ctrlpig.ACTION_SNOOZE_5M"
    const val ACTION_DISMISS = "com.antigravity.ctrlpig.ACTION_DISMISS"
    const val ACTION_MARK_TAKEN = "com.antigravity.ctrlpig.ACTION_MARK_TAKEN"
    const val ACTION_ACCEPT_SHOPPING = "com.antigravity.ctrlpig.ACTION_ACCEPT_SHOPPING"
    const val ACTION_OPEN_CHAT = "com.antigravity.ctrlpig.ACTION_OPEN_CHAT"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Alarmes de Remédios & Saúde (Destaque Branco)"
            val descriptionText = "Notificações com fundo branco, voz e botões de Adiar, Desligar e Já Tomei"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val alarmSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val audioAttrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val channel = NotificationChannel(NOTIF_CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 300, 500, 300, 700)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                if (alarmSound != null) {
                    setSound(alarmSound, audioAttrs)
                }
            }

            val shopName = "Lista de Compras da Família"
            val shopDesc = "Notificações de envio e recebimento da Lista de Compras"
            val shopChannel = NotificationChannel(NOTIF_SHOPPING_CHANNEL_ID, shopName, NotificationManager.IMPORTANCE_HIGH).apply {
                description = shopDesc
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 200, 300)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }

            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
            nm.createNotificationChannel(shopChannel)
        }
    }

    fun showShoppingNotification(
        context: Context,
        title: String,
        body: String,
        notifId: Int,
        sender: String = "",
        partner: String = ""
    ): Boolean {
        return try {
            ensureChannel(context)

            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("open_chat", true)
            }
            val openPending = PendingIntent.getActivity(context, notifId, openIntent, pendingFlags)

            // Intent: Aceitar lista de compras ("Recebi a lista")
            val acceptIntent = Intent(context, MedAlarmReceiver::class.java).apply {
                action = ACTION_ACCEPT_SHOPPING
                putExtra("title", title)
                putExtra("sender", sender)
                putExtra("partner", partner)
                putExtra("id", notifId)
            }
            val acceptPending = PendingIntent.getBroadcast(context, notifId + 40000, acceptIntent, pendingFlags)

            val remoteViews = RemoteViews(context.packageName, R.layout.custom_shopping_notification).apply {
                setTextViewText(R.id.notif_shopping_title, title)
                setTextViewText(R.id.notif_shopping_body, body)
                setOnClickPendingIntent(R.id.btn_notif_accept_shopping, acceptPending)
                setOnClickPendingIntent(R.id.btn_notif_open_chat, openPending)
            }

            val channelId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) NOTIF_SHOPPING_CHANNEL_ID else NOTIF_CHANNEL_ID
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, channelId)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context).setPriority(Notification.PRIORITY_MAX)
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

    fun showWhiteCardNotification(
        context: Context,
        title: String,
        body: String,
        notifId: Int,
        speechText: String = "",
        slotTime: String = ""
    ): Boolean {
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
                putExtra("speech", speechText)
                putExtra("slot", slotTime)
                putExtra("id", notifId)
            }
            val snoozePending = PendingIntent.getBroadcast(context, notifId + 10000, snoozeIntent, pendingFlags)

            // Intent 2: Desligar
            val dismissIntent = Intent(context, MedAlarmReceiver::class.java).apply {
                action = ACTION_DISMISS
                putExtra("title", title)
                putExtra("slot", slotTime)
                putExtra("id", notifId)
            }
            val dismissPending = PendingIntent.getBroadcast(context, notifId + 20000, dismissIntent, pendingFlags)

            // Intent 3: Já Tomei
            val takenIntent = Intent(context, MedAlarmReceiver::class.java).apply {
                action = ACTION_MARK_TAKEN
                putExtra("title", title)
                putExtra("slot", slotTime)
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

            // Intent de Tela Cheia / Alarme na Tela (estilo Despertador)
            val fullScreenIntent = Intent(context, AlarmAlertActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("title", title)
                putExtra("body", body)
                putExtra("speech", speechText)
                putExtra("slot", slotTime)
                putExtra("id", notifId)
            }
            val fullScreenPending = PendingIntent.getActivity(context, notifId + 50000, fullScreenIntent, pendingFlags)

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, NOTIF_CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context).setPriority(Notification.PRIORITY_MAX)
            }

            builder.setSmallIcon(context.applicationInfo.icon)
                .setContentTitle(title)
                .setContentText(body)
                .setAutoCancel(true)
                .setContentIntent(openPending)
                .setDeleteIntent(dismissPending)
                .setColor(0xFFFFFFFF.toInt())
                .setFullScreenIntent(fullScreenPending, true)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                builder.setCategory(Notification.CATEGORY_ALARM)
            }

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

    fun cancelScheduledAlarms(context: Context) {
        try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_NO_CREATE
            }
            for (id in 8000..8060) {
                val intent = Intent(context, MedAlarmReceiver::class.java).apply {
                    action = ACTION_FIRE_ALARM
                }
                val pi = PendingIntent.getBroadcast(context, id, intent, flags)
                if (pi != null) {
                    am.cancel(pi)
                    pi.cancel()
                }
            }
        } catch (_: Exception) {}
    }

    fun scheduleExactOneShot(
        context: Context,
        triggerAtMillis: Long,
        title: String,
        body: String,
        notifId: Int,
        speechText: String = "",
        slotTime: String = ""
    ) {
        try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, MedAlarmReceiver::class.java).apply {
                action = ACTION_FIRE_ALARM
                putExtra("title", title)
                putExtra("body", body)
                putExtra("speech", speechText)
                putExtra("slot", slotTime)
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
        val speech = intent.getStringExtra("speech")?.takeIf { it.isNotBlank() } ?: "$title. $body"
        val slot = intent.getStringExtra("slot") ?: ""
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val prefs = context.getSharedPreferences("ctrlpig_native_med_actions", Context.MODE_PRIVATE)

        when (action) {
            NotificationHelper.ACTION_FIRE_ALARM -> {
                // Abre exclusivamente o novo modelo de tela cheia sem repetir na barra de notificações
                try {
                    val alertIntent = Intent(context, AlarmAlertActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("title", title)
                        putExtra("body", body)
                        putExtra("speech", speech)
                        putExtra("slot", slot)
                        putExtra("id", notifId)
                    }
                    context.startActivity(alertIntent)
                } catch (e: Exception) {
                    // Fallback de segurança apenas se o Android bloquear a inicialização da Activity
                    NotificationHelper.showWhiteCardNotification(context, title, body, notifId, speech, slot)
                }

                val audioPrefs = context.getSharedPreferences("ctrlpig_med_audio_settings", Context.MODE_PRIVATE)
                val isAudioEnabled = audioPrefs.getBoolean("med_audio_enabled", true)
                if (isAudioEnabled) {
                    AlarmAudioPlayer.playAlarmAndSpeak(context, speech)
                }
                // Reagenda automaticamente para o dia seguinte (+24h) se for alarme diário recorrente de remédios
                if (notifId in 8000..8099) {
                    val nextDayMillis = System.currentTimeMillis() + (24 * 60 * 60 * 1000L)
                    NotificationHelper.scheduleExactOneShot(context, nextDayMillis, title, body, notifId, speech, slot)
                }
            }
            NotificationHelper.ACTION_SNOOZE_5M -> {
                AlarmAudioPlayer.stop()
                nm.cancel(notifId)
                // Registra que o alarme atual foi tratado na notificação para não disparar de novo ao abrir o app
                prefs.edit()
                    .putString("last_dismissed_med_title", title)
                    .putString("last_dismissed_med_slot", slot)
                    .putLong("last_dismissed_med_ts", System.currentTimeMillis())
                    .apply()
                val nextTrigger = System.currentTimeMillis() + (5 * 60 * 1000L)
                NotificationHelper.scheduleExactOneShot(
                    context,
                    nextTrigger,
                    title,
                    "💤 (Adiado 5 min) $body",
                    notifId + 500,
                    speech,
                    slot
                )
                Toast.makeText(context, "💤 Alarme adiado! Repetirá em 5 minutos.", Toast.LENGTH_SHORT).show()
            }
            NotificationHelper.ACTION_DISMISS -> {
                AlarmAudioPlayer.stop()
                nm.cancel(notifId)
                prefs.edit()
                    .putString("last_dismissed_med_title", title)
                    .putString("last_dismissed_med_slot", slot)
                    .putLong("last_dismissed_med_ts", System.currentTimeMillis())
                    .apply()
                Toast.makeText(context, "🔕 Alarme desligado.", Toast.LENGTH_SHORT).show()
            }
            NotificationHelper.ACTION_MARK_TAKEN -> {
                AlarmAudioPlayer.stop()
                nm.cancel(notifId)
                val nowTs = System.currentTimeMillis()
                prefs.edit()
                    .putString("last_taken_med_title", title)
                    .putString("last_taken_med_slot", slot)
                    .putLong("last_taken_med_ts", nowTs)
                    .putString("last_dismissed_med_title", title)
                    .putString("last_dismissed_med_slot", slot)
                    .putLong("last_dismissed_med_ts", nowTs)
                    .apply()
                Toast.makeText(context, "✅ Dose marcada como tomada!", Toast.LENGTH_SHORT).show()
            }
            NotificationHelper.ACTION_ACCEPT_SHOPPING -> {
                nm.cancel(notifId)
                val sender = intent.getStringExtra("sender") ?: "Amor"
                val partner = intent.getStringExtra("partner") ?: "Parceiro"
                val nowTs = System.currentTimeMillis()
                val shopPrefs = context.getSharedPreferences("ctrlpig_shopping_actions", Context.MODE_PRIVATE)
                shopPrefs.edit()
                    .putString("last_accepted_by", partner)
                    .putString("last_requested_by", sender)
                    .putLong("last_accepted_ts", nowTs)
                    .putBoolean("has_unread_acceptance", true)
                    .apply()
                Toast.makeText(context, "🛒 Lista de compras aceita! Abrindo detalhes...", Toast.LENGTH_SHORT).show()

                // Abre a tela do aplicativo diretamente no Chat
                val openIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("open_chat", true)
                    putExtra("accepted_by", partner)
                }
                context.startActivity(openIntent)
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
                    val speech = call.argument<String>("speech") ?: ""
                    val slot = call.argument<String>("slot") ?: ""
                    val notifId = call.argument<Int>("id") ?: (System.currentTimeMillis() % 100000).toInt()
                    val ok = NotificationHelper.showWhiteCardNotification(this, title, body, notifId, speech, slot)
                    result.success(ok)
                }
                "showShoppingNotification" -> {
                    val title = call.argument<String>("title") ?: "🛒 Lista de Compras"
                    val body = call.argument<String>("body") ?: ""
                    val sender = call.argument<String>("sender") ?: ""
                    val partner = call.argument<String>("partner") ?: ""
                    val notifId = call.argument<Int>("id") ?: (System.currentTimeMillis() % 100000).toInt()
                    val ok = NotificationHelper.showShoppingNotification(this, title, body, notifId, sender, partner)
                    result.success(ok)
                }
                "stopNativeAlarm" -> {
                    AlarmAudioPlayer.stop()
                    result.success(true)
                }
                "scheduleMedAlarms" -> {
                    val alarms = call.argument<List<Map<String, Any>>>("alarms") ?: emptyList()
                    scheduleDailyAlarmsList(alarms)
                    result.success(true)
                }
                "schedulePetAlarms" -> {
                    val alarms = call.argument<List<Map<String, Any>>>("alarms") ?: emptyList()
                    schedulePetAlarmsList(alarms)
                    result.success(true)
                }
                "consumePendingMedTaken" -> {
                    val prefs = getSharedPreferences("ctrlpig_native_med_actions", Context.MODE_PRIVATE)
                    val takenTitle = prefs.getString("last_taken_med_title", null)
                    val takenSlot = prefs.getString("last_taken_med_slot", null)
                    val takenTs = prefs.getLong("last_taken_med_ts", 0L)
                    val dismissedTitle = prefs.getString("last_dismissed_med_title", null)
                    val dismissedSlot = prefs.getString("last_dismissed_med_slot", null)
                    val dismissedTs = prefs.getLong("last_dismissed_med_ts", 0L)

                    if ((takenTitle != null && takenTs > 0L) || (dismissedTitle != null && dismissedTs > 0L)) {
                        prefs.edit()
                            .remove("last_taken_med_title")
                            .remove("last_taken_med_slot")
                            .remove("last_taken_med_ts")
                            .remove("last_dismissed_med_title")
                            .remove("last_dismissed_med_slot")
                            .remove("last_dismissed_med_ts")
                            .apply()
                        result.success(
                            mapOf(
                                "title" to (takenTitle ?: ""),
                                "slot" to (takenSlot ?: ""),
                                "ts" to takenTs,
                                "dismissedTitle" to (dismissedTitle ?: ""),
                                "dismissedSlot" to (dismissedSlot ?: ""),
                                "dismissedTs" to dismissedTs
                            )
                        )
                    } else {
                        result.success(null)
                    }
                }
                "consumePendingShoppingAcceptance" -> {
                    val shopPrefs = getSharedPreferences("ctrlpig_shopping_actions", Context.MODE_PRIVATE)
                    val acceptedBy = shopPrefs.getString("last_accepted_by", null)
                    val requestedBy = shopPrefs.getString("last_requested_by", null)
                    val ts = shopPrefs.getLong("last_accepted_ts", 0L)
                    val hasUnread = shopPrefs.getBoolean("has_unread_acceptance", false)

                    if (acceptedBy != null && hasUnread) {
                        shopPrefs.edit().putBoolean("has_unread_acceptance", false).apply()
                        result.success(
                            mapOf(
                                "acceptedBy" to acceptedBy,
                                "requestedBy" to (requestedBy ?: ""),
                                "ts" to ts
                            )
                        )
                    } else {
                        result.success(null)
                    }
                }
                "setMedAudioEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    val audioPrefs = getSharedPreferences("ctrlpig_med_audio_settings", Context.MODE_PRIVATE)
                    audioPrefs.edit().putBoolean("med_audio_enabled", enabled).apply()
                    result.success(true)
                }
                "getMedAudioEnabled" -> {
                    val audioPrefs = getSharedPreferences("ctrlpig_med_audio_settings", Context.MODE_PRIVATE)
                    val enabled = audioPrefs.getBoolean("med_audio_enabled", true)
                    result.success(enabled)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun scheduleDailyAlarmsList(alarms: List<Map<String, Any>>) {
        NotificationHelper.cancelScheduledAlarms(this)
        val now = Calendar.getInstance()
        for ((index, item) in alarms.withIndex()) {
            val hour = (item["hour"] as? Number)?.toInt() ?: continue
            val minute = (item["minute"] as? Number)?.toInt() ?: continue
            val title = (item["title"] as? String) ?: "⏰ Hora do Medicamento"
            val body = (item["body"] as? String) ?: "Hora de tomar sua medicação."
            val speech = (item["speech"] as? String) ?: "$title. $body"
            val slot = (item["slot"] as? String) ?: String.format("%02d:%02d", hour, minute)
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
            NotificationHelper.scheduleExactOneShot(this, target.timeInMillis, title, body, id, speech, slot)
        }
    }

    private fun schedulePetAlarmsList(alarms: List<Map<String, Any>>) {
        val now = System.currentTimeMillis()
        for ((index, item) in alarms.withIndex()) {
            val triggerMillis = (item["triggerMillis"] as? Number)?.toLong() ?: continue
            if (triggerMillis <= now) continue
            val title = (item["title"] as? String) ?: "🐾 Hora do Cuidado Pet"
            val body = (item["body"] as? String) ?: "Confira os cuidados agendados do pet."
            val speech = (item["speech"] as? String) ?: "$title. $body"
            val slot = (item["slot"] as? String) ?: ""
            val id = (item["id"] as? Number)?.toInt() ?: (9000 + index)

            NotificationHelper.scheduleExactOneShot(this, triggerMillis, title, body, id, speech, slot)
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

