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
import '../services/speech_service.dart';
import '../services/ocr_service.dart';
import '../services/biometric_service.dart';
import '../services/auth_service.dart';
import '../models/transaction_model.dart';
import '../providers/finance_provider.dart';

class DashboardContainerScreen extends StatefulWidget {
  const DashboardContainerScreen({super.key});

  @override
  State<DashboardContainerScreen> createState() => _DashboardContainerScreenState();
}

class _DashboardContainerScreenState extends State<DashboardContainerScreen> with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();
  FlutterTts? _flutterTts;
  DateTime? _lastBackPressTime;
  Timer? _chatVoiceDebounceTimer;
  String _lastChatRecognizedText = '';

  @override
  void dispose() {
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
    _initWebViewController();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Revalida autenticação biométrica/sessão ao retornar do segundo plano
      _controller.runJavaScript("""
        if (typeof window.onAppResumedFromBackground === 'function') {
          window.onAppResumedFromBackground();
        }
      """);
    }
  }

  void _initWebViewController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFEEF3FB))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _injectNativeBridge();
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
      )
      ..loadFlutterAsset('assets/index.html');
  }

  Future<void> _openExternalUrl(String url) async {
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
      } else if (action == 'start_voice') {
        _startNativeVoiceRecording();
      } else if (action == 'start_chat_voice') {
        _startNativeChatVoiceRecording();
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
        if (text.isNotEmpty) {
          _speakNativeTTS(text);
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
        final status = await Permission.notification.request();
        final granted = status.isGranted;
        _controller.runJavaScript("""
          if (typeof window.onNativeNotificationPermissionResult === 'function') {
            window.onNativeNotificationPermissionResult($granted);
          }
        """);
      } else if (action == 'stop_speak') {
        _flutterTts?.stop();
      } else if (action == 'update_launcher_icon') {
        final isPositive = data['isPositive'] as bool? ?? true;
        try {
          const MethodChannel('com.antigravity.ctrlpig/launcher_icon')
              .invokeMethod('setLauncherIcon', {'isPositive': isPositive});
        } catch (e) {
          debugPrint('Aviso ao atualizar ícone dinâmico do launcher: $e');
        }
      } else if (action == 'pick_invoice_camera') {
        _pickInvoicePhoto(source: ImageSource.camera);
      } else if (action == 'pick_invoice_gallery') {
        _pickInvoicePhotosFromGallery();
      } else if (action == 'start_camera_ocr') {
        _pickInvoicePhoto(source: ImageSource.camera);
      } else if (action == 'pick_chat_photo') {
        _pickChatPhoto();
      } else if (action == 'pick_logo_image') {
        _pickLogoImage();
      } else if (action == 'pick_avatar_photo') {
        final member = data['member'] as String? ?? 'rodrigo';
        final source = data['source'] as String? ?? 'gallery';
        _pickAvatarPhoto(member, source: source);
      } else if (action == 'pick_pet_photo') {
        final source = data['source'] as String? ?? 'gallery';
        _pickPetPhoto(source: source);
      } else if (action == 'authenticate_biometric' || action == 'authenticate_biometrics') {
        _authenticateBiometric();
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

    await speech.startListening(
      onResult: (text) {
        if (text.isNotEmpty) {
          final safeTextJson = jsonEncode(text);
          _controller.runJavaScript(
            "if (typeof window.onNativeVoiceResult === 'function') { window.onNativeVoiceResult($safeTextJson); }"
          );
        }
      },
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

    await speech.startListening(
      finalOnly: false,
      onResult: (text) {
        final trimmed = text.trim();
        if (trimmed.isNotEmpty) {
          _lastChatRecognizedText = trimmed;
          _chatVoiceDebounceTimer?.cancel();
          // Aguarda 1.6s após a pessoa parar de falar para enviar o resultado final unificado
          _chatVoiceDebounceTimer = Timer(const Duration(milliseconds: 1600), () {
            speech.stopListening();
            if (_lastChatRecognizedText.isNotEmpty) {
              final safeTextJson = jsonEncode(_lastChatRecognizedText);
              _controller.runJavaScript(
                "if (typeof window.onNativeChatVoiceResult === 'function') { window.onNativeChatVoiceResult($safeTextJson); }"
              );
              _lastChatRecognizedText = '';
            }
          });
        }
      },
    );
  }

  Future<void> _speakNativeTTS(String text) async {
    try {
      _flutterTts ??= FlutterTts();
      await _flutterTts!.setLanguage("pt-BR");
      await _flutterTts!.setSpeechRate(0.48);
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(1.0);
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
        lines: [],
        rawText: '',
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
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFEEF3FB),
          body: SafeArea(
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
                            // Logo CtrlPig Limpo sem repetir o ícone quadrado do celular
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
