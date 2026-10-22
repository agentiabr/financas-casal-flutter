import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../services/speech_service.dart';
import '../services/ocr_service.dart';
import '../services/biometric_service.dart';
import '../services/auth_service.dart';
import '../services/nfce/nfce.dart';
import '../models/transaction_model.dart';
import '../providers/finance_provider.dart';

class DashboardContainerScreen extends StatefulWidget {
  const DashboardContainerScreen({super.key});

  @override
  State<DashboardContainerScreen> createState() => _DashboardContainerScreenState();
}

class _DashboardContainerScreenState extends State<DashboardContainerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();
  FlutterTts? _flutterTts;
  DateTime? _lastBackPressTime;
  DateTime? _lastPausedTime;
  bool _isPickingExternalMedia = false;
  Timer? _chatVoiceDebounceTimer;
  String _lastChatRecognizedText = '';
  Timer? _voiceDebounceTimer;
  String _lastRecognizedVoiceText = '';
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void dispose() {
    _pulseController.dispose();
    _voiceDebounceTimer?.cancel();
    _chatVoiceDebounceTimer?.cancel();
    _flutterTts?.stop();
    WidgetsBinding.instance.removeObserver(this);
    _ocrService.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initWebViewController();
  }

  Future<void> _checkPendingNativeMedTaken() async {
    try {
      final res = await const MethodChannel('com.antigravity.ctrlpig/launcher_icon')
          .invokeMethod('consumePendingMedTaken');
      if (res != null && res is Map) {
        final title = res['title']?.toString() ?? '';
        final slot = res['slot']?.toString() ?? '';
        final dismissedTitle = res['dismissedTitle']?.toString() ?? '';
        final dismissedSlot = res['dismissedSlot']?.toString() ?? '';

        if (dismissedTitle.isNotEmpty || dismissedSlot.isNotEmpty) {
          final safeDismissedTitle = jsonEncode(dismissedTitle);
          final safeDismissedSlot = jsonEncode(dismissedSlot);
          await _controller.runJavaScript("""
            if (typeof window.onNativeNotificationMedDismissed === 'function') {
              window.onNativeNotificationMedDismissed($safeDismissedTitle, $safeDismissedSlot);
            }
          """);
        }

        if (title.isNotEmpty) {
          final safeTitle = jsonEncode(title);
          final safeSlot = jsonEncode(slot);
          await _controller.runJavaScript("""
            if (typeof window.onNativeNotificationMedTaken === 'function') {
              window.onNativeNotificationMedTaken($safeTitle, $safeSlot);
            }
          """);
        }
      }
    } catch (e) {
      debugPrint('Aviso ao checar consumePendingMedTaken: $e');
    }
  }

  Future<void> _checkPendingShoppingAcceptance() async {
    try {
      final res = await const MethodChannel('com.antigravity.ctrlpig/launcher_icon')
          .invokeMethod('consumePendingShoppingAcceptance');
      if (res != null && res is Map) {
        final acceptedBy = res['acceptedBy']?.toString() ?? '';
        final requestedBy = res['requestedBy']?.toString() ?? '';
        final ts = res['ts'] ?? 0;
        final safeAcceptedBy = jsonEncode(acceptedBy);
        final safeRequestedBy = jsonEncode(requestedBy);
        await _controller.runJavaScript("""
          if (typeof window.onNativeShoppingListAccepted === 'function') {
            window.onNativeShoppingListAccepted($safeAcceptedBy, $safeRequestedBy, $ts);
          }
        """);
      }
    } catch (e) {
      debugPrint('Aviso ao checar consumePendingShoppingAcceptance: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lastPausedTime = DateTime.now();
      if (!_isPickingExternalMedia) {
        _controller.runJavaScript("""
          localStorage.setItem('ctrlpig_last_paused_timestamp', '${DateTime.now().millisecondsSinceEpoch}');
          if (typeof window.onAppPausedToBackground === 'function') {
            window.onAppPausedToBackground();
          }
        """);
      }
    } else if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      final difference = _lastPausedTime != null ? now.difference(_lastPausedTime!) : Duration.zero;
      _lastPausedTime = null;

      // Tolerância de 5 minutos: só bloqueia por inatividade se o usuário ficou fora por 5 min ou mais
      if (difference.inMinutes >= 5 && !_isPickingExternalMedia) {
        _controller.runJavaScript("""
          localStorage.setItem('financas_session_locked', 'true');
          sessionStorage.removeItem('pigctrl_session_authenticated');
          if (typeof window.lockAppSessionNow === 'function') {
            window.lockAppSessionNow();
          }
        """);
      }

      // Consome primeiro qualquer ação da notificação (Desligar, Adiar ou Já Tomei) ANTES de verificar os timers de alarme
      _checkPendingNativeMedTaken().then((_) {
        _checkPendingShoppingAcceptance();
        _controller.runJavaScript("""
          if (typeof window.onAppResumedFromBackground === 'function') {
            window.onAppResumedFromBackground(${difference.inSeconds});
          }
        """);
      });
      Permission.notification.status.then((status) {
        final granted = status.isGranted;
        _controller.runJavaScript("""
          if (typeof window.onNativeNotificationPermissionResult === 'function') {
            window.onNativeNotificationPermissionResult($granted, false);
          }
        """);
      });
    }
  }

  static const String _kCurrentAppVersion = '2.1.31+108';

  void _initWebViewController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFEEF3FB))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _injectNativeBridge();
            _checkPendingNativeMedTaken();
            _checkPendingShoppingAcceptance();
            // Abertura imediata e suave do painel financeiro
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            if (url.startsWith('file:') || url.contains('flutter_assets') || url == 'about:blank') {
              return NavigationDecision.navigate;
            }
            debugPrint('Navegação externa aberta fora do WebView: $url');
            _openExternalUrl(url);
            return NavigationDecision.prevent;
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Erro no WebView: ${error.description}');
            if (error.isForMainFrame ?? false) {
              _controller.loadFlutterAsset('assets/index.html');
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: _handleJavaScriptMessage,
      );

    // Habilita permissão de geolocalização nativa e câmera no WebView Android
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async {
          final status = await Permission.location.request();
          return GeolocationPermissionsResponse(
            allow: status.isGranted,
            retain: true,
          );
        },
      );
      platform.setOnPlatformPermissionRequest(
        (request) async {
          final cameraStatus = await Permission.camera.request();
          final micStatus = await Permission.microphone.request();
          if (cameraStatus.isGranted || micStatus.isGranted) {
            request.grant();
          } else {
            request.deny();
          }
        },
      );
    }

    _prepareAndLoadWebView();
  }

  Future<void> _prepareAndLoadWebView() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastVersion = prefs.getString('ctrlpig_installed_version');
      if (lastVersion != _kCurrentAppVersion) {
        debugPrint('CtrlPig: Nova versão detectada ($lastVersion -> $_kCurrentAppVersion). Limpando cache de renderização do WebView...');
        await _controller.clearCache();
        await prefs.setString('ctrlpig_installed_version', _kCurrentAppVersion);
      }
    } catch (e) {
      debugPrint('Aviso ao verificar versão do app no cache: $e');
    }
    await _controller.loadFlutterAsset('assets/index.html');
  }

  Future<void> _openExternalUrl(String url) async {
    _isPickingExternalMedia = true;
    Future.delayed(const Duration(seconds: 4), () {
      _isPickingExternalMedia = false;
    });
    try {
      final uri = Uri.parse(url);
      bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!ok) {
        debugPrint('Não foi possível abrir externamente: $url');
      }
    } catch (e) {
      debugPrint('Erro ao abrir link externo: $e');
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
      } catch (_) {}
    }
  }

  Future<void> _shareWhatsAppText(String text, {String? phone}) async {
    _isPickingExternalMedia = true;
    Future.delayed(const Duration(seconds: 4), () {
      _isPickingExternalMedia = false;
    });
    try {
      final encoded = Uri.encodeComponent(text);
      String cleanPhone = (phone ?? '').replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.isNotEmpty && !cleanPhone.startsWith('55') && cleanPhone.length >= 10 && cleanPhone.length <= 11) {
        cleanPhone = '55$cleanPhone';
      }

      final Uri waUri;
      if (cleanPhone.isNotEmpty) {
        waUri = Uri.parse("whatsapp://send?phone=$cleanPhone&text=$encoded");
      } else {
        waUri = Uri.parse("whatsapp://send?text=$encoded");
      }

      bool ok = await launchUrl(waUri, mode: LaunchMode.externalApplication);
      if (!ok) {
        final Uri webUri;
        if (cleanPhone.isNotEmpty) {
          webUri = Uri.parse("https://api.whatsapp.com/send?phone=$cleanPhone&text=$encoded");
        } else {
          webUri = Uri.parse("https://api.whatsapp.com/send?text=$encoded");
        }
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Erro ao compartilhar no WhatsApp: $e");
      try {
        final encoded = Uri.encodeComponent(text);
        String cleanPhone = (phone ?? '').replaceAll(RegExp(r'\D'), '');
        if (cleanPhone.isNotEmpty && !cleanPhone.startsWith('55') && cleanPhone.length >= 10 && cleanPhone.length <= 11) {
          cleanPhone = '55$cleanPhone';
        }
        final url = cleanPhone.isNotEmpty
            ? "https://wa.me/$cleanPhone?text=$encoded"
            : "https://wa.me/?text=$encoded";
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Future<void> _pickContactFromPhone() async {
    _isPickingExternalMedia = true;
    try {
      final contact = await const MethodChannel('com.antigravity.ctrlpig/launcher_icon')
          .invokeMapMethod<String, dynamic>('pickContact');
      if (contact != null) {
        final name = (contact['name'] as String? ?? '').trim();
        final phone = (contact['phone'] as String? ?? '').trim();
        final safeName = jsonEncode(name);
        final safePhone = jsonEncode(phone);
        _controller.runJavaScript("""
          if (typeof window.onNativeContactPicked === 'function') {
            window.onNativeContactPicked($safeName, $safePhone);
          }
        """);
      }
    } catch (e) {
      debugPrint('Erro ao selecionar contato via MethodChannel: $e');
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        _isPickingExternalMedia = false;
      });
    }
  }

  void _injectNativeBridge() {
    const jsBridge = '''
      window.isNativeApp = true;
      // O WebView não abre novas janelas: redireciona window.open para o navegador do celular
      window.open = function(url) {
        if (url && window.FlutterBridge) {
          FlutterBridge.postMessage(JSON.stringify({ action: 'open_external_url', url: String(url) }));
        }
        return null;
      };
      console.log("Flutter Native Bridge conectada com sucesso!");
    ''';
    _controller.runJavaScript(jsBridge);

    // Envia dados do Supabase carregados no Flutter para a interface Web
    try {
      final provider = Provider.of<FinanceProvider>(context, listen: false);
      if (provider.transactions.isNotEmpty) {
        final txListJson = jsonEncode(provider.transactions.map((t) => t.toJson()).toList());
        _controller.runJavaScript("""
          if (typeof window.onNativeSupabaseDataLoaded === 'function') {
            window.onNativeSupabaseDataLoaded($txListJson);
          }
        """);
      }
    } catch (e) {
      debugPrint('Aviso ao sincronizar inicial com WebView: $e');
    }
  }

  Future<void> _handleJavaScriptMessage(JavaScriptMessage message) async {
    try {
      final data = jsonDecode(message.message);
      final action = data['action'] as String?;

      if (action == 'open_external_url') {
        final url = data['url'] as String? ?? '';
        if (url.isNotEmpty) _openExternalUrl(url);
      } else if (action == 'share_whatsapp') {
        final text = data['text'] as String? ?? '';
        final phone = data['phone'] as String?;
        if (text.isNotEmpty) _shareWhatsAppText(text, phone: phone);
      } else if (action == 'pick_contact') {
        _pickContactFromPhone();
      } else if (action == 'start_voice') {
        _startNativeVoiceRecording();
      } else if (action == 'stop_voice' || action == 'send_voice') {
        _stopNativeVoiceRecording();
      } else if (action == 'cancel_voice') {
        _cancelNativeVoiceRecording();
      } else if (action == 'start_chat_voice') {
        _startNativeChatVoiceRecording();
      } else if (action == 'stop_chat_voice' || action == 'send_chat_voice') {
        _stopNativeChatVoiceRecording();
      } else if (action == 'cancel_chat_voice') {
        _cancelNativeChatVoiceRecording();
      } else if (action == 'speak_text') {
        final text = data['text'] as String? ?? '';
        final forceWithoutHeadphones = data['forceSpeaker'] as bool? ?? false;
        if (text.isNotEmpty) {
          if (forceWithoutHeadphones) {
            _speakNativeTTS(text);
          } else {
            bool hasHeadphones = false;
            try {
              hasHeadphones = await const MethodChannel('com.antigravity.ctrlpig/launcher_icon')
                      .invokeMethod<bool>('isHeadphonesConnected') ??
                  false;
            } catch (_) {}
            if (hasHeadphones) {
              _speakNativeTTS(text);
            } else {
              _controller.runJavaScript("""
                if (typeof window.onHeadphonesRequiredWarning === 'function') {
                  window.onHeadphonesRequiredWarning();
                }
              """);
            }
          }
        }
      } else if (action == 'speak_alarm') {
        final text = data['text'] as String? ?? '';
        final alarmStyle = data['alarmStyle'] as String? ?? 'female';
        bool audioEnabled = true;
        try {
          audioEnabled = await const MethodChannel('com.antigravity.ctrlpig/launcher_icon')
                  .invokeMethod<bool>('getMedAudioEnabled') ??
              true;
        } catch (_) {}
        try {
          await const MethodChannel('com.antigravity.ctrlpig/launcher_icon')
              .invokeMethod('setAlarmStyle', {'style': alarmStyle});
        } catch (_) {}
        if (alarmStyle == 'vibrate') {
          try {
            HapticFeedback.vibrate();
            Future.delayed(const Duration(milliseconds: 350), () => HapticFeedback.vibrate());
            Future.delayed(const Duration(milliseconds: 700), () => HapticFeedback.vibrate());
          } catch (_) {}
        } else if (text.isNotEmpty && audioEnabled) {
          _speakNativeTTS(text, alarmStyle: alarmStyle);
        }
      } else if (action == 'set_med_audio_enabled') {
        final enabled = data['enabled'] as bool? ?? true;
        try {
          await const MethodChannel('com.antigravity.ctrlpig/launcher_icon')
              .invokeMethod('setMedAudioEnabled', {'enabled': enabled});
        } catch (e) {
          debugPrint('Aviso ao sincronizar audio de remedios no nativo: $e');
        }
      } else if (action == 'check_headphones') {
        bool hasHeadphones = false;
        try {
          hasHeadphones = await const MethodChannel('com.antigravity.ctrlpig/launcher_icon')
                  .invokeMethod<bool>('isHeadphonesConnected') ??
              false;
        } catch (_) {}
        _controller.runJavaScript("""
          if (typeof window.onNativeHeadphonesStatus === 'function') {
            window.onNativeHeadphonesStatus($hasHeadphones);
          }
        """);
      } else if (action == 'request_notification_permission') {
        var status = await Permission.notification.status;
        if (!status.isGranted) {
          status = await Permission.notification.request();
        }
        final granted = status.isGranted;
        if (!granted) {
          await openAppSettings();
        }
        _controller.runJavaScript("""
          if (typeof window.onNativeNotificationPermissionResult === 'function') {
            window.onNativeNotificationPermissionResult($granted, true);
          }
        """);
      } else if (action == 'request_location_permission') {
        var status = await Permission.location.status;
        if (!status.isGranted) {
          status = await Permission.location.request();
        }
        final granted = status.isGranted;
        if (!granted) {
          await openAppSettings();
        }
        _controller.runJavaScript("""
          if (typeof window.onNativeLocationPermissionResult === 'function') {
            window.onNativeLocationPermissionResult($granted);
          }
        """);
      } else if (action == 'set_med_speak_name_disabled') {
        final disabled = data['disabled'] as bool? ?? false;
        try {
          await const MethodChannel('com.antigravity.ctrlpig/launcher_icon')
              .invokeMethod('setMedSpeakNameDisabled', {'disabled': disabled});
        } catch (_) {}
      } else if (action == 'set_alarm_style') {
        final style = data['style'] as String? ?? 'female';
        try {
          await const MethodChannel('com.antigravity.ctrlpig/launcher_icon')
              .invokeMethod('setAlarmStyle', {'style': style});
        } catch (_) {}
      } else if (action == 'show_notification') {
        final title = data['title'] as String? ?? 'ControlPig';
        final body = data['body'] as String? ?? '';
        final speech = data['speech'] as String? ?? '';
        final slot = data['slot'] as String? ?? '';
        final id = data['id'] is int
            ? data['id'] as int
            : (DateTime.now().millisecondsSinceEpoch % 100000);
        try {
          await const MethodChannel('com.antigravity.ctrlpig/launcher_icon')
              .invokeMethod('showNotification', {
            'title': title,
            'body': body,
            'speech': speech,
            'slot': slot,
            'id': id,
          });
        } catch (e) {
          debugPrint('Aviso ao disparar notificação nativa: $e');
        }
      } else if (action == 'show_shopping_notification') {
        final title = data['title'] as String? ?? '🛒 Lista de Compras';
        final body = data['body'] as String? ?? '';
        final sender = data['sender'] as String? ?? '';
        final partner = data['partner'] as String? ?? '';
        final id = data['id'] is int
            ? data['id'] as int
            : (DateTime.now().millisecondsSinceEpoch % 100000);
        try {
          await const MethodChannel('com.antigravity.ctrlpig/launcher_icon')
              .invokeMethod('showShoppingNotification', {
            'title': title,
            'body': body,
            'sender': sender,
            'partner': partner,
            'id': id,
          });
        } catch (e) {
          debugPrint('Aviso ao disparar notificação de compras nativa: $e');
        }
      } else if (action == 'schedule_med_alarms') {
        final rawAlarms = data['alarms'];
        if (rawAlarms is List) {
          final List<Map<String, dynamic>> alarms = rawAlarms
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
          try {
            await const MethodChannel('com.antigravity.ctrlpig/launcher_icon')
                .invokeMethod('scheduleMedAlarms', {'alarms': alarms});
          } catch (e) {
            debugPrint('Aviso ao agendar alarmes nativos: $e');
          }
        }
      } else if (action == 'schedule_pet_alarms') {
        final rawAlarms = data['alarms'];
        if (rawAlarms is List) {
          final List<Map<String, dynamic>> alarms = rawAlarms
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
          try {
            await const MethodChannel('com.antigravity.ctrlpig/launcher_icon')
                .invokeMethod('schedulePetAlarms', {'alarms': alarms});
          } catch (e) {
            debugPrint('Aviso ao agendar alarmes de pet nativos: $e');
          }
        }
      } else if (action == 'open_app_settings') {
        _isPickingExternalMedia = true;
        await openAppSettings();
        Future.delayed(const Duration(seconds: 2), () {
          _isPickingExternalMedia = false;
        });
      } else if (action == 'check_notification_permission') {
        final status = await Permission.notification.status;
        final granted = status.isGranted;
        _controller.runJavaScript("""
          if (typeof window.onNativeNotificationPermissionResult === 'function') {
            window.onNativeNotificationPermissionResult($granted, false);
          }
        """);
      } else if (action == 'stop_speak') {
        _flutterTts?.stop();
        try {
          await const MethodChannel('com.antigravity.ctrlpig/launcher_icon')
              .invokeMethod('stopNativeAlarm');
        } catch (_) {}
      } else if (action == 'update_launcher_icon') {
        final isPositive = data['isPositive'] as bool? ?? true;
        try {
          const MethodChannel('com.antigravity.ctrlpig/launcher_icon')
              .invokeMethod('setLauncherIcon', {'isPositive': isPositive});
        } catch (e) {
          debugPrint('Aviso ao atualizar ícone dinâmico do launcher: $e');
        }
      } else if (action == 'request_camera_permission') {
        var status = await Permission.camera.status;
        if (!status.isGranted) {
          status = await Permission.camera.request();
        }
        _controller.runJavaScript("""
          if (typeof window.onNativeCameraPermissionResult === 'function') {
            window.onNativeCameraPermissionResult(${status.isGranted});
          }
        """);
      } else if (action == 'fetch_nfce_url') {
        final url = data['url'] as String?;
        if (url != null && url.isNotEmpty) {
          await _fetchNfceFromUrl(url);
        }
      } else if (action == 'scan_invoice_qrcode') {
        _isPickingExternalMedia = true;
        await _scanInvoiceQrCode();
        Future.delayed(const Duration(seconds: 2), () {
          _isPickingExternalMedia = false;
        });
      } else if (action == 'pick_invoice_camera') {
        _isPickingExternalMedia = true;
        await _pickInvoicePhoto(source: ImageSource.camera);
        Future.delayed(const Duration(seconds: 2), () {
          _isPickingExternalMedia = false;
        });
      } else if (action == 'pick_invoice_gallery') {
        _isPickingExternalMedia = true;
        await _pickInvoicePhotosFromGallery();
        Future.delayed(const Duration(seconds: 2), () {
          _isPickingExternalMedia = false;
        });
      } else if (action == 'start_camera_ocr') {
        _isPickingExternalMedia = true;
        await _pickInvoicePhoto(source: ImageSource.camera);
        Future.delayed(const Duration(seconds: 2), () {
          _isPickingExternalMedia = false;
        });
      } else if (action == 'pick_chat_photo') {
        _isPickingExternalMedia = true;
        await _pickChatPhoto();
        Future.delayed(const Duration(seconds: 2), () {
          _isPickingExternalMedia = false;
        });
      } else if (action == 'pick_logo_image') {
        _isPickingExternalMedia = true;
        await _pickLogoImage();
        Future.delayed(const Duration(seconds: 2), () {
          _isPickingExternalMedia = false;
        });
      } else if (action == 'pick_avatar_photo') {
        _isPickingExternalMedia = true;
        final member = data['member'] as String? ?? 'rodrigo';
        final source = data['source'] as String? ?? 'gallery';
        await _pickAvatarPhoto(member, source: source);
        Future.delayed(const Duration(seconds: 2), () {
          _isPickingExternalMedia = false;
        });
      } else if (action == 'pick_pet_photo') {
        _isPickingExternalMedia = true;
        final source = data['source'] as String? ?? 'gallery';
        await _pickPetPhoto(source: source);
        Future.delayed(const Duration(seconds: 2), () {
          _isPickingExternalMedia = false;
        });
      } else if (action == 'save_image') {
        final base64Data = data['base64Data'] as String? ?? '';
        final filename = data['filename'] as String? ?? 'qrcode_coleira_pet.png';
        try {
          final ok = await const MethodChannel('com.antigravity.ctrlpig/launcher_icon')
                  .invokeMethod<bool>('saveImage', {
                'base64Data': base64Data,
                'filename': filename,
              }) ??
              false;
          _controller.runJavaScript("""
            if (typeof window.onNativeImageSaved === 'function') {
              window.onNativeImageSaved($ok);
            }
          """);
        } catch (e) {
          debugPrint('Aviso ao salvar imagem via MethodChannel: $e');
        }
      } else if (action == 'authenticate_biometric' || action == 'authenticate_biometrics') {
        _isPickingExternalMedia = true;
        await _authenticateBiometric();
        Future.delayed(const Duration(seconds: 2), () {
          _isPickingExternalMedia = false;
        });
      } else if (action == 'sync_transaction') {
        // Conexão Web -> Flutter -> Supabase
        final txMap = data['transaction'];
        if (txMap != null && txMap is Map<String, dynamic>) {
          final tx = TransactionModel.fromJson(txMap);
          final provider = Provider.of<FinanceProvider>(context, listen: false);
          final exists = provider.transactions.any((t) => t.id == tx.id);
          if (exists) {
            provider.editTransaction(tx);
          } else {
            provider.addTransaction(tx);
          }
        }
      } else if (action == 'delete_transaction') {
        // Conexão Web -> Flutter -> Supabase Delete
        final idVal = data['id'];
        if (idVal != null) {
          final id = idVal is int ? idVal : int.tryParse(idVal.toString()) ?? 0;
          if (id > 0) {
            final provider = Provider.of<FinanceProvider>(context, listen: false);
            provider.deleteTransaction(id);
          }
        }
      } else if (action == 'auth_login') {
        final email = data['email'] as String? ?? '';
        final password = data['password'] as String? ?? '';
        final authService = Provider.of<AuthService>(context, listen: false);
        final err = await authService.signIn(email: email, password: password);
        final success = err == null;
        final user = authService.currentUser;
        final userJson = jsonEncode({
          'email': user?.email ?? email,
          'id': user?.id ?? '',
          'nome': user?.userMetadata?['nome'] ?? email.split('@')[0],
        });
        _controller.runJavaScript("""
          if (typeof window.onNativeAuthLoginResult === 'function') {
            window.onNativeAuthLoginResult($success, ${jsonEncode(err ?? '')}, $userJson);
          }
        """);
      } else if (action == 'auth_signup') {
        final email = data['email'] as String? ?? '';
        final password = data['password'] as String? ?? '';
        final nome = data['nome'] as String? ?? '';
        final authService = Provider.of<AuthService>(context, listen: false);
        final err = await authService.signUp(email: email, password: password, nome: nome);
        final success = err == null;
        _controller.runJavaScript("""
          if (typeof window.onNativeAuthRegisterResult === 'function') {
            window.onNativeAuthRegisterResult($success, ${jsonEncode(err ?? '')});
          }
        """);
      } else if (action == 'auth_reset_password') {
        final email = data['email'] as String? ?? '';
        final authService = Provider.of<AuthService>(context, listen: false);
        final err = await authService.resetPassword(email);
        final success = err == null;
        _controller.runJavaScript("""
          if (typeof window.onNativeAuthForgotResult === 'function') {
            window.onNativeAuthForgotResult($success, ${jsonEncode(err ?? '')});
          }
        """);
      } else if (action == 'auth_signout') {
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.signOut();
      } else if (action == 'exit_app') {
        SystemNavigator.pop();
      }
    } catch (e) {
      debugPrint('Erro ao processar mensagem do JS: $e');
    }
  }

  Future<void> _startNativeVoiceRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissão de microfone necessária para comando de voz.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final speech = Provider.of<SpeechService>(context, listen: false);
    final available = await speech.initialize();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reconhecimento de voz não disponível no aparelho.')),
        );
      }
      return;
    }

    _voiceDebounceTimer?.cancel();
    _lastRecognizedVoiceText = '';

    _controller.runJavaScript(
      "if (typeof window.onNativeMicrophoneRecordingState === 'function') { window.onNativeMicrophoneRecordingState(true, ''); }"
    );

    await speech.startListening(
      finalOnly: false,
      onResult: (text) {
        final trimmed = text.trim();
        if (trimmed.isNotEmpty) {
          _lastRecognizedVoiceText = trimmed;
          // Envia texto parcial em tempo real para exibir na barra estilo WhatsApp enquanto a pessoa fala
          final safePartial = jsonEncode(_lastRecognizedVoiceText);
          _controller.runJavaScript("""
            if (typeof window.onNativeVoiceInterimResult === 'function') { window.onNativeVoiceInterimResult($safePartial); }
            if (typeof window.onNativeMicrophoneRecordingState === 'function') { window.onNativeMicrophoneRecordingState(true, $safePartial); }
          """);
        }
      },
    );
  }

  void _stopNativeVoiceRecording() {
    _voiceDebounceTimer?.cancel();
    final speech = Provider.of<SpeechService>(context, listen: false);
    final finalWords = _lastRecognizedVoiceText.trim().isNotEmpty
        ? _lastRecognizedVoiceText.trim()
        : speech.lastWords.trim();
    speech.stopListening();
    _controller.runJavaScript(
      "if (typeof window.onNativeMicrophoneRecordingState === 'function') { window.onNativeMicrophoneRecordingState(false, ''); }"
    );
    if (finalWords.isNotEmpty) {
      final safeFinal = jsonEncode(finalWords);
      _controller.runJavaScript(
        "if (typeof window.onNativeVoiceResult === 'function') { window.onNativeVoiceResult($safeFinal); }"
      );
    }
    _lastRecognizedVoiceText = '';
  }

  void _cancelNativeVoiceRecording() {
    _voiceDebounceTimer?.cancel();
    _lastRecognizedVoiceText = '';
    final speech = Provider.of<SpeechService>(context, listen: false);
    speech.cancelListening();
    _controller.runJavaScript(
      "if (typeof window.onNativeMicrophoneRecordingState === 'function') { window.onNativeMicrophoneRecordingState(false, ''); }"
    );
  }

  Future<void> _startNativeChatVoiceRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    final speech = Provider.of<SpeechService>(context, listen: false);
    final available = await speech.initialize();
    if (!available) return;

    _chatVoiceDebounceTimer?.cancel();
    _lastChatRecognizedText = '';

    _controller.runJavaScript(
      "if (typeof window.onNativeMicrophoneRecordingState === 'function') { window.onNativeMicrophoneRecordingState(true, ''); }"
    );

    await speech.startListening(
      finalOnly: false,
      onResult: (text) {
        final trimmed = text.trim();
        if (trimmed.isNotEmpty) {
          _lastChatRecognizedText = trimmed;
          final safePartial = jsonEncode(_lastChatRecognizedText);
          _controller.runJavaScript(
            "if (typeof window.onNativeMicrophoneRecordingState === 'function') { window.onNativeMicrophoneRecordingState(true, $safePartial); }"
          );
        }
      },
    );
  }

  void _stopNativeChatVoiceRecording() {
    _chatVoiceDebounceTimer?.cancel();
    final speech = Provider.of<SpeechService>(context, listen: false);
    final finalWords = _lastChatRecognizedText.trim().isNotEmpty
        ? _lastChatRecognizedText.trim()
        : speech.lastWords.trim();
    speech.stopListening();
    _controller.runJavaScript(
      "if (typeof window.onNativeMicrophoneRecordingState === 'function') { window.onNativeMicrophoneRecordingState(false, ''); }"
    );
    if (finalWords.isNotEmpty) {
      final safeTextJson = jsonEncode(finalWords);
      _controller.runJavaScript(
        "if (typeof window.onNativeChatVoiceResult === 'function') { window.onNativeChatVoiceResult($safeTextJson); }"
      );
    }
    _lastChatRecognizedText = '';
  }

  void _cancelNativeChatVoiceRecording() {
    _chatVoiceDebounceTimer?.cancel();
    _lastChatRecognizedText = '';
    final speech = Provider.of<SpeechService>(context, listen: false);
    speech.cancelListening();
    _controller.runJavaScript(
      "if (typeof window.onNativeMicrophoneRecordingState === 'function') { window.onNativeMicrophoneRecordingState(false, ''); }"
    );
  }

  Future<void> _speakNativeTTS(String text, {String alarmStyle = 'female'}) async {
    try {
      _flutterTts ??= FlutterTts();
      await _flutterTts!.setLanguage("pt-BR");
      await _flutterTts!.setVolume(1.0);
      try {
        final voices = await _flutterTts!.getVoices;
        if (voices is List) {
          final ptBrVoices = voices.where((v) {
            final locale = (v['locale'] ?? '').toString().toLowerCase();
            return locale.contains('pt-br') || locale.contains('pt_br');
          }).toList();

          if (alarmStyle == 'female') {
            final femaleVoice = ptBrVoices.firstWhere(
              (v) =>
                  (v['name'] ?? '').toString().toLowerCase().contains('female') ||
                  (v['name'] ?? '').toString().toLowerCase().contains('afs') ||
                  (v['name'] ?? '').toString().toLowerCase().contains('yfn') ||
                  (v['name'] ?? '').toString().toLowerCase().contains('luciana') ||
                  (v['name'] ?? '').toString().toLowerCase().contains('mulher'),
              orElse: () => null,
            );
            if (femaleVoice != null) {
              await _flutterTts!.setVoice({
                'name': femaleVoice['name'].toString(),
                'locale': femaleVoice['locale'].toString()
              });
            }
          } else if (alarmStyle == 'male') {
            final maleVoice = ptBrVoices.firstWhere(
              (v) =>
                  (v['name'] ?? '').toString().toLowerCase().contains('male') ||
                  (v['name'] ?? '').toString().toLowerCase().contains('ptd') ||
                  (v['name'] ?? '').toString().toLowerCase().contains('homem'),
              orElse: () => null,
            );
            if (maleVoice != null) {
              await _flutterTts!.setVoice({
                'name': maleVoice['name'].toString(),
                'locale': maleVoice['locale'].toString()
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Aviso ao consultar vozes pt-BR no FlutterTts: $e');
      }

      if (alarmStyle == 'male') {
        await _flutterTts!.setPitch(0.70); // Tom encorpado / grave masculino
        await _flutterTts!.setSpeechRate(0.46);
      } else {
        await _flutterTts!.setPitch(1.35); // Tom nítido / agudo feminino
        await _flutterTts!.setSpeechRate(0.50);
      }
      _flutterTts!.setCompletionHandler(() {
        _controller.runJavaScript("""
          if (typeof window.onNativeTtsCompleted === 'function') {
            window.onNativeTtsCompleted();
          }
        """);
      });
      await _flutterTts!.speak(text);
    } catch (e) {
      debugPrint('Erro ao reproduzir TTS nativo: $e');
    }
  }

  Future<void> _pickInvoicePhoto({required ImageSource source}) async {
    try {
      if (source == ImageSource.camera) {
        var status = await Permission.camera.status;
        if (!status.isGranted) {
          status = await Permission.camera.request();
          if (!status.isGranted) {
            _controller.runJavaScript("""
              if (typeof showToastUndo === 'function') {
                showToastUndo('Permissão de câmera não concedida pelo usuário!', false);
              }
            """);
            return;
          }
        }
      }
      final XFile? photo = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 88,
      );
      if (photo == null) return;

      _controller.runJavaScript(
        "if (typeof window.onNativeOcrProcessingStart === 'function') { window.onNativeOcrProcessingStart(); }"
      );

      final bytes = await photo.readAsBytes();
      final base64Str = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64Str';

      // Executa OCR Google ML Kit no hardware nativo do dispositivo
      final ocrResult = await _ocrService.processReceiptImage(photo.path);
      final jsonResult = jsonEncode(ocrResult.toJson());
      final safeJson = jsonResult.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
      final safeDataUrl = dataUrl.replaceAll("'", r"\'");

      _controller.runJavaScript("""
        if (typeof window.onNativeInvoiceOcrResult === 'function') {
          window.onNativeInvoiceOcrResult('$safeJson', '$safeDataUrl');
        } else if (typeof window.onNativeInvoicePhotoCaptured === 'function') {
          window.onNativeInvoicePhotoCaptured('$safeDataUrl');
        }
      """);
    } catch (e) {
      debugPrint('Erro ao capturar foto da nota com OCR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao capturar foto da nota: $e')),
        );
      }
    }
  }

  Future<void> _scanInvoiceQrCode() async {
    try {
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
        if (!status.isGranted) {
          _controller.runJavaScript("""
            if (typeof showToastUndo === 'function') {
              showToastUndo('PermissÃ£o de cÃ¢mera necessÃ¡ria para ler o QR Code!', false);
            }
          """);
          return;
        }
      }

      if (!mounted) return;

      // Abre a tela de scanner contÃ­nuo nativo (mobile_scanner)
      final NfceInvoice? invoice = await Navigator.of(context).push<NfceInvoice>(
        MaterialPageRoute(
          builder: (context) => const NfceScannerScreen(),
        ),
      );

      if (invoice == null) {
        // UsuÃ¡rio cancelou ou fechou a cÃ¢mera sem escanear
        return;
      }

      final jsonResult = jsonEncode(invoice.toJson());
      final safeJson = jsonResult.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
      final safeUrl = (invoice.rawUrl ?? '').replaceAll("'", r"\'");

      // Injeta os dados oficiais diretamente na WebView (alimenta modal, tabela de mercado e comparador)
      _controller.runJavaScript("""
        if (typeof window.onNativeInvoiceQrResult === 'function') {
          window.onNativeInvoiceQrResult('$safeJson');
        } else if (typeof window.applyOcrResultToInvoiceModal === 'function') {
          window.applyOcrResultToInvoiceModal($jsonResult);
        } else if (typeof window.handleDetectedQrCode === 'function') {
          window.handleDetectedQrCode('$safeUrl');
        }
      """);
    } catch (e) {
      debugPrint('Erro ao escanear QR Code da nota: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao escanear nota fiscal: $e')),
        );
      }
    }
  }

  Future<void> _fetchNfceFromUrl(String url) async {
    try {
      final NfceInvoice? invoice = await Navigator.of(context).push<NfceInvoice>(
        MaterialPageRoute(
          builder: (context) => NfceScannerScreen(initialUrl: url),
        ),
      );

      if (invoice == null) return;

      final jsonResult = jsonEncode(invoice.toJson());
      final safeJson = jsonResult.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

      _controller.runJavaScript("""
        if (typeof window.onNativeInvoiceQrResult === 'function') {
          window.onNativeInvoiceQrResult('$safeJson');
        } else if (typeof window.applyOcrResultToInvoiceModal === 'function') {
          window.applyOcrResultToInvoiceModal($jsonResult);
        }
      """);
    } catch (e) {
      debugPrint('Erro ao consultar NFC-e via URL: $e');
    }
  }

  Future<void> _pickInvoicePhotosFromGallery() async {
    try {
      final List<XFile> photos = await _picker.pickMultiImage(
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 88,
      );
      if (photos.isEmpty) return;

      _controller.runJavaScript(
        "if (typeof window.onNativeOcrProcessingStart === 'function') { window.onNativeOcrProcessingStart(); }"
      );

      final List<String> dataUrls = [];
      final List<ReceiptItem> allItems = [];
      final List<String> allLines = [];
      final List<String> allRawTexts = [];
      String? detectedStore;
      DateTime? detectedDate;
      double? detectedTotal;

      for (final p in photos) {
        final bytes = await p.readAsBytes();
        final base64Str = base64Encode(bytes);
        dataUrls.add('data:image/jpeg;base64,$base64Str');

        try {
          final ocr = await _ocrService.processReceiptImage(p.path);
          if (ocr.storeName != null && detectedStore == null) detectedStore = ocr.storeName;
          if (ocr.date != null && detectedDate == null) detectedDate = ocr.date;
          if (ocr.totalAmount != null && ocr.totalAmount! > 0) detectedTotal = ocr.totalAmount;
          allItems.addAll(ocr.items);
          allLines.addAll(ocr.lines);
          if (ocr.rawText.trim().isNotEmpty) {
            allRawTexts.add(ocr.rawText.trim());
          }
        } catch (itemErr) {
          debugPrint('Erro ao processar parte da nota: $itemErr');
        }
      }

      if ((detectedTotal == null || detectedTotal <= 0) && allItems.isNotEmpty) {
        detectedTotal = allItems.fold<double>(0.0, (double acc, item) => acc + item.total);
      }

      final combinedResult = ReceiptOcrResult(
        storeName: detectedStore,
        totalAmount: detectedTotal,
        date: detectedDate ?? DateTime.now(),
        items: allItems,
        lines: allLines,
        rawText: allRawTexts.join('\n--- PAGINA ---\n'),
      );

      final jsonResult = jsonEncode(combinedResult.toJson());
      final safeJson = jsonResult.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
      final jsonArray = jsonEncode(dataUrls);

      _controller.runJavaScript("""
        if (typeof window.onNativeInvoiceMultiOcrResult === 'function') {
          window.onNativeInvoiceMultiOcrResult('$safeJson', $jsonArray);
        } else if (typeof window.onNativeInvoicePhotosCaptured === 'function') {
          window.onNativeInvoicePhotosCaptured($jsonArray);
        }
      """);
    } catch (e) {
      debugPrint('Erro ao selecionar fotos da galeria com OCR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar fotos: $e')),
        );
      }
    }
  }

  Future<void> _pickChatPhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 75,
      );
      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      final base64Str = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64Str';

      _controller.runJavaScript(
        "if (typeof window.onNativeChatPhotoResult === 'function') { window.onNativeChatPhotoResult('$dataUrl'); }"
      );
    } catch (e) {
      debugPrint('Erro ao capturar foto no chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao capturar foto: $e')),
        );
      }
    }
  }

  Future<void> _pickLogoImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final base64Str = base64Encode(bytes);
      final dataUrl = 'data:image/png;base64,$base64Str';

      _controller.runJavaScript(
        "if (typeof window.onNativeLogoResult === 'function') { window.onNativeLogoResult('$dataUrl'); }"
      );
    } catch (e) {
      debugPrint('Erro ao selecionar logo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e')),
        );
      }
    }
  }

  Future<void> _pickAvatarPhoto(String member, {String source = 'gallery'}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final base64Str = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64Str';

      _controller.runJavaScript(
        "if (typeof window.onNativeAvatarResult === 'function') { window.onNativeAvatarResult('$member', '$dataUrl'); }"
      );
    } catch (e) {
      debugPrint('Erro ao selecionar foto do avatar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar foto do avatar: $e')),
        );
      }
    }
  }

  Future<void> _pickPetPhoto({String source = 'gallery'}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final base64Str = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64Str';

      _controller.runJavaScript(
        "if (typeof window.onNativePetPhotoResult === 'function') { window.onNativePetPhotoResult('$dataUrl'); }"
      );
    } catch (e) {
      debugPrint('Erro ao selecionar foto do pet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar foto do pet: $e')),
        );
      }
    }
  }

  Future<void> _authenticateBiometric() async {
    try {
      final bio = BiometricService();
      final auth = await bio.authenticate(
        reason: 'Confirme com sua digital, rosto ou senha do celular para acessar',
      );
      final errorMsg = (bio.lastErrorMessage ?? '').replaceAll("'", "\\'");
      _controller.runJavaScript(
        "if (typeof window.onBiometricAuthResult === 'function') { window.onBiometricAuthResult($auth, '$errorMsg'); }"
      );
    } catch (e) {
      debugPrint('Erro em _authenticateBiometric: $e');
      final errorMsg = e.toString().replaceAll("'", "\\'");
      _controller.runJavaScript(
        "if (typeof window.onBiometricAuthResult === 'function') { window.onBiometricAuthResult(false, '$errorMsg'); }"
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        // Se por qualquer motivo o WebView não estiver no index.html, recupera imediatamente
        try {
          final currentUrl = await _controller.currentUrl();
          if (currentUrl != null && !currentUrl.contains('index.html')) {
            _controller.loadFlutterAsset('assets/index.html');
            return;
          }
        } catch (_) {}

        // 1. Fechar qualquer modal ativo dentro do Dashboard web
        try {
          final closedResult = await _controller.runJavaScriptReturningResult(
            "typeof window.closeAnyActiveModal === 'function' ? window.closeAnyActiveModal() : false;"
          );
          if (closedResult.toString() == 'true') {
            return;
          }
        } catch (_) {}

        // 2. Se não houver modal aberto, confirmação de 2 toques para sair do app (nunca volta para login)
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pressione voltar novamente para sair do app'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        SystemNavigator.pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF0A3981),
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFF020617),
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFF0A3981),
          body: SafeArea(
            top: true,
            bottom: false,
            child: Stack(
              children: [
              WebViewWidget(controller: _controller),
                AnimatedOpacity(
                  opacity: _isLoading ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOut,
                  child: IgnorePointer(
                    ignoring: !_isLoading,
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF020617),
                            Color(0xFF06183B),
                            Color(0xFF0F172A),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Ícone Animado Pulsando
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                                      blurRadius: 26,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Image.asset(
                                    'assets/ICONE CELULAR - AZUL POSITIVO.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Image.asset('assets/app_icon.png'),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Logo CtrlPig
                            const Text(
                              'CtrlPig',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Subtítulo Oficial
                            const Text(
                              'Controle Financeiro Inteligente',
                              style: TextStyle(
                                color: Color(0xFF93C5FD),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 32),
                            const SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                              ),
                            ),
                            const SizedBox(height: 18),
                            // Indicador de Carregamento Discreto
                            const Text(
                              'Carregando seu painel...',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
