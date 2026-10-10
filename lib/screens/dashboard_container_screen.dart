import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
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
          onWebResourceError: (WebResourceError error) {
            debugPrint('Erro no WebView: ${error.description}');
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
    // Injeta script no WebView para conectar os botões de voz e câmera diretamente aos sensores nativos
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
      } else if (action == 'authenticate_biometric') {
        _authenticateBiometric();
      }
    } catch (e) {
      debugPrint('Erro ao processar mensagem do JS: $e');
    }
  }

  Future<void> _startNativeVoiceRecording() async {
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
          _controller.runJavaScript("if (typeof window.onNativeVoiceResult === 'function') { window.onNativeVoiceResult('$safeText'); }");
        }
      },
    );
  }

  Future<void> _startNativeCameraOcr() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
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
      _controller.runJavaScript("if (typeof window.onNativeOcrResult === 'function') { window.onNativeOcrResult($jsonData); }");
    } catch (e) {
      debugPrint('Erro no OCR Nativo: $e');
    }
  }

  Future<void> _authenticateBiometric() async {
    final bio = BiometricService();
    final auth = await bio.authenticate(reason: 'Autenticação de Segurança Finanças Casal');
    _controller.runJavaScript("if (typeof window.onBiometricAuthResult === 'function') { window.onBiometricAuthResult($auth); }");
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
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
    );
  }
}
