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
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(R.layout.activity_alarm_alert)

        val title = intent.getStringExtra("title") ?: "⏰ Hora do Medicamento"
        val body = intent.getStringExtra("body") ?: "Confirme a conclusão ou adie por 5 minutos."
        val speech = intent.getStringExtra("speech") ?: ""
        val slot = intent.getStringExtra("slot") ?: ""
        val notifId = intent.getIntExtra("id", 1001)

        val tvBadge = findViewById<TextView>(R.id.tv_alarm_badge)
        val tvIcon = findViewById<TextView>(R.id.tv_alarm_icon)
        val tvTitle = findViewById<TextView>(R.id.tv_alarm_title)
        val tvBody = findViewById<TextView>(R.id.tv_alarm_body)
        val btnTaken = findViewById<Button>(R.id.btn_alarm_taken)
        val btnSnooze = findViewById<Button>(R.id.btn_alarm_snooze)
        val btnDismiss = findViewById<Button>(R.id.btn_alarm_dismiss)

        val isPet = title.contains("Pet", ignoreCase = true) || title.contains("🐾") || body.contains("Pet", ignoreCase = true)
        if (isPet) {
            tvBadge.text = "🐾 CONTROLPIG • CUIDADO PET AGENDADO"
            tvIcon.text = "🐾"
            btnTaken.text = "✓ CUIDADO REALIZADO"
        } else {
            tvBadge.text = "⏰ CONTROLPIG • ALARME DE SAÚDE"
            tvIcon.text = "💊"
            btnTaken.text = "✓ JÁ TOMEI"
        }

        tvTitle.text = title
        tvBody.text = body

        btnTaken.setOnClickListener {
            // Dispara ação de Concluído
            val takenIntent = Intent(this, MedAlarmReceiver::class.java).apply {
                action = NotificationHelper.ACTION_MARK_TAKEN
                putExtra("title", title)
                putExtra("slot", slot)
                putExtra("id", notifId)
            }
            sendBroadcast(takenIntent)
            AlarmAudioPlayer.stop()
            finish()
        }

        btnSnooze.setOnClickListener {
            // Dispara ação de Adiar 5 minutos
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
            // Dispara ação de Desligar
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
