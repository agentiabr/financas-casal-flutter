import UIKit
import Flutter
import UserNotifications
import AVFoundation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  private let speechSynthesizer = AVSpeechSynthesizer()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Configura delegado de notificações para exibir alertas mesmo com o app em primeiro plano no iPhone
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self

      // Categorias de Ações Rápidas (Adiar 5m, Desligar, Já Tomei)
      let snoozeAction = UNNotificationAction(identifier: "ACTION_SNOOZE", title: "💤 Adiar 5 min", options: [])
      let dismissAction = UNNotificationAction(identifier: "ACTION_DISMISS", title: "🔕 Desligar", options: [.destructive])
      let markTakenAction = UNNotificationAction(identifier: "ACTION_MARK_TAKEN", title: "✅ Já Tomei", options: [])

      let medCategory = UNNotificationCategory(
        identifier: "MED_ALARM_CATEGORY",
        actions: [snoozeAction, dismissAction, markTakenAction],
        intentIdentifiers: [],
        options: [.customDismissAction]
      )
      UNUserNotificationCenter.current().setNotificationCategories([medCategory])
    }

    // Configura o MethodChannel do ControlPig idêntico ao Android para iOS
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.antigravity.ctrlpig/launcher_icon",
        binaryMessenger: controller.binaryMessenger
      )

      channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        guard let self = self else { return }

        switch call.method {
        case "showNotification":
          guard let args = call.arguments as? [String: Any] else {
            result(false)
            return
          }
          let title = args["title"] as? String ?? "ControlPig"
          let body = args["body"] as? String ?? ""
          let speech = args["speech"] as? String ?? ""
          let id = args["id"] as? Int ?? (Int(Date().timeIntervalSince1970) % 100000)

          self.showLocalNotification(title: title, body: body, id: id, speech: speech)
          result(true)

        case "scheduleMedAlarms":
          guard let args = call.arguments as? [String: Any],
                let alarms = args["alarms"] as? [[String: Any]] else {
            result(true)
            return
          }
          self.scheduleMedicationAlarms(alarms: alarms)
          result(true)

        case "stopNativeAlarm":
          self.speechSynthesizer.stopSpeaking(at: .immediate)
          result(true)

        case "setLauncherIcon":
          result(true)

        case "isHeadphonesConnected":
          result(false)

        case "consumePendingMedTaken":
          let defaults = UserDefaults.standard
          let takenTitle = defaults.string(forKey: "ctrlpig_last_taken_med_title")
          let takenSlot = defaults.string(forKey: "ctrlpig_last_taken_med_slot")
          let takenTs = defaults.integer(forKey: "ctrlpig_last_taken_med_ts")
          let dismissedTitle = defaults.string(forKey: "ctrlpig_last_dismissed_med_title")
          let dismissedSlot = defaults.string(forKey: "ctrlpig_last_dismissed_med_slot")
          let dismissedTs = defaults.integer(forKey: "ctrlpig_last_dismissed_med_ts")

          let payload: [String: Any?] = [
            "takenTitle": takenTitle,
            "takenSlot": takenSlot,
            "takenTs": takenTs,
            "dismissedTitle": dismissedTitle,
            "dismissedSlot": dismissedSlot,
            "dismissedTs": dismissedTs
          ]
          result(payload)

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Apresenta a notificação na tela mesmo se o app estiver aberto no iPhone
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  // Trata ações dos botões da notificação no iOS (Adiar 5m, Desligar, Já Tomei)
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let defaults = UserDefaults.standard
    let userInfo = response.notification.request.content.userInfo
    let title = userInfo["title"] as? String ?? ""
    let slot = userInfo["slot"] as? String ?? ""
    let nowTs = Int(Date().timeIntervalSince1970 * 1000)

    switch response.actionIdentifier {
    case "ACTION_SNOOZE":
      self.showLocalNotification(
        title: title,
        body: "💤 (Adiado 5 min) Lembrete de remédio",
        id: Int.random(in: 1000...9999),
        speech: "",
        delaySeconds: 300
      )
    case "ACTION_DISMISS":
      defaults.set(title, forKey: "ctrlpig_last_dismissed_med_title")
      defaults.set(slot, forKey: "ctrlpig_last_dismissed_med_slot")
      defaults.set(nowTs, forKey: "ctrlpig_last_dismissed_med_ts")
    case "ACTION_MARK_TAKEN":
      defaults.set(title, forKey: "ctrlpig_last_taken_med_title")
      defaults.set(slot, forKey: "ctrlpig_last_taken_med_slot")
      defaults.set(nowTs, forKey: "ctrlpig_last_taken_med_ts")
      defaults.set(title, forKey: "ctrlpig_last_dismissed_med_title")
      defaults.set(slot, forKey: "ctrlpig_last_dismissed_med_slot")
      defaults.set(nowTs, forKey: "ctrlpig_last_dismissed_med_ts")
    default:
      break
    }
    completionHandler()
  }

  private func showLocalNotification(
    title: String,
    body: String,
    id: Int,
    speech: String,
    delaySeconds: TimeInterval = 1
  ) {
    if #available(iOS 10.0, *) {
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = UNNotificationSound.default
      content.categoryIdentifier = "MED_ALARM_CATEGORY"
      content.userInfo = ["title": title]

      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delaySeconds), repeats: false)
      let request = UNNotificationRequest(identifier: "ctrlpig_notif_\(id)", content: content, trigger: trigger)

      UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
          print("Erro ao agendar notificação no iOS: \(error.localizedDescription)")
        }
      }

      if !speech.isEmpty {
        let utterance = AVSpeechUtterance(string: speech)
        utterance.voice = AVSpeechSynthesisVoice(language: "pt-BR")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        self.speechSynthesizer.speak(utterance)
      }
    }
  }

  private func scheduleMedicationAlarms(alarms: [[String: Any]]) {
    if #available(iOS 10.0, *) {
      let center = UNUserNotificationCenter.current()
      for alarm in alarms {
        guard let slot = alarm["slot"] as? String,
              let id = alarm["id"] as? Int,
              let title = alarm["title"] as? String,
              let speech = alarm["speech"] as? String else { continue }

        let parts = slot.split(separator: ":")
        if parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) {
          var dateComponents = DateComponents()
          dateComponents.hour = hour
          dateComponents.minute = minute

          let content = UNMutableNotificationContent()
          content.title = title
          content.body = "Horário de tomar seu medicamento (\(slot))"
          content.sound = UNNotificationSound.default
          content.categoryIdentifier = "MED_ALARM_CATEGORY"
          content.userInfo = ["title": title, "slot": slot, "speech": speech]

          let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
          let request = UNNotificationRequest(identifier: "ctrlpig_med_\(id)", content: content, trigger: trigger)

          center.add(request, withCompletionHandler: nil)
        }
      }
    }
  }
}
