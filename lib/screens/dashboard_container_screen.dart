import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/speech_service.dart';
import '../services/ocr_service.dart';
import '../services/biometric_service.dart';
import '../providers/finance_provider.dart';

class DashboardContainerScreen extends StatefulWidget {
  const DashboardContainerScreen({super.key});

  @override
  State<DashboardContainerScreen> createState() => _DashboardContainerScreenState();
}

class _DashboardContainerScreenState extends State<DashboardContainerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _initWebViewController();
  }

  void _initWebViewController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFEEF3FB))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _injectNativeBridge();
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            if (url.startsWith('file:') || url.contains('flutter_assets') || url == 'about:blank') {
              return NavigationDecision.navigate;
            }
            debugPrint('Navegação externa bloqueada no WebView: $url');
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

  void _injectNativeBridge() {
    const jsBridge = '''
      window.isNativeApp = true;
      console.log("Flutter Native Bridge conectada com sucesso!");
    ''';
    _controller.runJavaScript(jsBridge);
  }

  Future<void> _handleJavaScriptMessage(JavaScriptMessage message) async {
    try {
      final data = jsonDecode(message.message);
      final action = data['action'] as String?;

      if (action == 'start_voice') {
        _startNativeVoiceRecording();
      } else if (action == 'start_camera_ocr') {
        _startNativeCameraOcr();
      } else if (action == 'pick_chat_photo') {
        _pickChatPhoto();
      } else if (action == 'pick_logo_image') {
        _pickLogoImage();
      } else if (action == 'pick_avatar_photo') {
        final member = data['member'] as String? ?? 'rodrigo';
        final source = data['source'] as String? ?? 'gallery';
        _pickAvatarPhoto(member, source: source);
      } else if (action == 'authenticate_biometric') {
        _authenticateBiometric();
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
          final safeText = text.replaceAll("'", "\\'");
          _controller.runJavaScript(
            "if (typeof window.onNativeVoiceResult === 'function') { window.onNativeVoiceResult('$safeText'); }"
          );
        }
      },
    );
  }

  Future<void> _startNativeCameraOcr() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo == null) return;

      final ocrService = OcrService();
      final result = await ocrService.processReceiptImage(photo.path);
      ocrService.dispose();

      final dataMap = {
        'store': result.storeName ?? '',
        'total': result.totalAmount ?? 0.0,
        'date': result.date?.toIso8601String().split('T')[0] ?? '',
      };
      final jsonData = jsonEncode(dataMap);
      _controller.runJavaScript(
        "if (typeof window.onNativeOcrResult === 'function') { window.onNativeOcrResult($jsonData); }"
      );
    } catch (e) {
      debugPrint('Erro no OCR Nativo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao acessar a câmera: $e')),
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
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1D4ED8),
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
