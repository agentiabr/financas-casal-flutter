package com.antigravity.financas_casal_flutter

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView

class AlarmAlertActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Configuração para acender a tela e aparecer mesmo com o celular bloqueado
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            keyguardManager?.requestDismissKeyguard(this, null)
        }
        
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        setContentView(R.layout.activity_alarm_alert)
        updateAlarmUI(intent)
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        updateAlarmUI(intent)
    }

    private fun updateAlarmUI(currentIntent: Intent?) {
        val title = currentIntent?.getStringExtra("title") ?: "⏰ Hora do Medicamento"
        val body = currentIntent?.getStringExtra("body") ?: "Confirme a conclusão ou adie por 5 minutos."
        val speech = currentIntent?.getStringExtra("speech") ?: ""
        val slot = currentIntent?.getStringExtra("slot") ?: ""
        val notifId = currentIntent?.getIntExtra("id", 1001) ?: 1001

        val tvBadge = findViewById<TextView>(R.id.tv_alarm_badge)
        val tvIcon = findViewById<TextView>(R.id.tv_alarm_icon)
        val tvTitle = findViewById<TextView>(R.id.tv_alarm_title)
        val tvBody = findViewById<TextView>(R.id.tv_alarm_body)
        val btnTaken = findViewById<Button>(R.id.btn_alarm_taken)
        val btnSnooze = findViewById<Button>(R.id.btn_alarm_snooze)
        val btnDismiss = findViewById<Button>(R.id.btn_alarm_dismiss)

        val isShopping = title.contains("Compras", ignoreCase = true) ||
                         title.contains("Lista", ignoreCase = true) ||
                         title.contains("Mercado", ignoreCase = true) ||
                         title.contains("🛒") ||
                         body.contains("Lista de Compras", ignoreCase = true) ||
                         body.contains("🛒", ignoreCase = true)
        val isPet = title.contains("Pet", ignoreCase = true) || title.contains("🐾") || body.contains("Pet", ignoreCase = true) || title.contains("Vacina", ignoreCase = true)

        if (isShopping) {
            tvBadge.text = "🛒 CONTROLPIG • LISTA DE COMPRAS"
            tvIcon.text = "🛒"
            btnTaken.text = "✓ RECEBI A LISTA"
            btnSnooze.text = "⏰ VER DEPOIS"
        } else if (isPet) {
            tvBadge.text = "🐾 CONTROLPIG • CUIDADO PET AGENDADO"
            tvIcon.text = "🐾"
            btnTaken.text = "✓ CUIDADO REALIZADO"
            btnSnooze.text = "💤 ADIAR 5 MIN"
        } else {
            tvBadge.text = "⏰ CONTROLPIG • ALARME DE SAÚDE"
            tvIcon.text = "💊"
            btnTaken.text = "✓ JÁ TOMEI"
            btnSnooze.text = "💤 ADIAR 5 MIN"
        }

        tvTitle.text = title
        tvBody.text = body

        btnTaken.setOnClickListener {
            if (isShopping) {
                val acceptIntent = Intent(this, MedAlarmReceiver::class.java).apply {
                    action = NotificationHelper.ACTION_ACCEPT_SHOPPING
                    putExtra("title", title)
                    putExtra("id", notifId)
                }
                sendBroadcast(acceptIntent)
            } else {
                val takenIntent = Intent(this, MedAlarmReceiver::class.java).apply {
                    action = NotificationHelper.ACTION_MARK_TAKEN
                    putExtra("title", title)
                    putExtra("slot", slot)
                    putExtra("id", notifId)
                }
                sendBroadcast(takenIntent)
            }
            AlarmAudioPlayer.stop()
            finish()
        }

        btnSnooze.setOnClickListener {
            val snoozeIntent = Intent(this, MedAlarmReceiver::class.java).apply {
                action = NotificationHelper.ACTION_SNOOZE_5M
                putExtra("title", title)
                putExtra("body", body)
                putExtra("speech", speech)
                putExtra("slot", slot)
                putExtra("id", notifId)
            }
            sendBroadcast(snoozeIntent)
            AlarmAudioPlayer.stop()
            finish()
        }

        btnDismiss.setOnClickListener {
            val dismissIntent = Intent(this, MedAlarmReceiver::class.java).apply {
                action = NotificationHelper.ACTION_DISMISS
                putExtra("title", title)
                putExtra("slot", slot)
                putExtra("id", notifId)
            }
            sendBroadcast(dismissIntent)
            AlarmAudioPlayer.stop()
            finish()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        AlarmAudioPlayer.stop()
    }
}
