import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'models/nfce_invoice.dart';
import 'nfce_fetcher.dart';
import 'nfce_number_parser.dart';
import 'nfce_parser.dart';
import '../ocr_service.dart';

/// Tela Flutter de Scanner de QR Code de Nota Fiscal (NFC-e) em tela cheia com Motor Híbrido.
/// 1. Leitura contínua ultrarrápida via mobile_scanner nativo.
/// 2. Tentativa direta de parsing via NfceFetcher.
/// 3. Resolução automática e contínua via Chromium WebView (idêntico ao navegador nativo do celular)
///    para bypass transparente de WAF/F5 BIG-IP, cookies de sessão e formulários ASP.NET da SEFAZ SP / Nacional.
/// 4. Modo interativo transparente caso a SEFAZ exija CAPTCHA ou confirmação manual.
class NfceScannerScreen extends StatefulWidget {
  final String title;
  final String? initialUrl;

  const NfceScannerScreen({
    super.key,
    this.title = 'Escanear QR Code da Nota Fiscal',
    this.initialUrl,
  });

  @override
  State<NfceScannerScreen> createState() => _NfceScannerScreenState();
}

class _NfceScannerScreenState extends State<NfceScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _scannerController;
  late final AnimationController _animController;
  late final Animation<double> _scanLineAnimation;
  final NfceFetcher _fetcher = NfceFetcher();

  bool _isProcessing = false;
  String _statusMessage = 'Aponte a câmera para o QR Code do cupom fiscal';
  bool _isTorchOn = false;
  bool _showFriendlyHint = false;
  Timer? _friendlyHintTimer;
  String? _lastScannedValue;

  // Variáveis para a Solução A: Navegador Integrado Inteligente com Auto-Captura
  String? _browserUrl;
  WebViewController? _browserController;
  double _browserProgress = 0.0;
  String _browserStatus = 'Conectando ao portal oficial da SEFAZ SP...';
  Timer? _browserExtractionTimer;
  bool _isExtractingFromBrowser = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
      returnImage: false,
      formats: const [BarcodeFormat.qrCode],
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _initCamera();

    // Se uma URL inicial foi informada diretamente
    if (widget.initialUrl != null && widget.initialUrl!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleBarcodeValue(widget.initialUrl!.trim());
      });
    } else {
      // Dica amigável após 8 segundos caso o usuário tenha dificuldade com iluminação
      _friendlyHintTimer = Timer(const Duration(seconds: 8), () {
        if (mounted && !_isProcessing) {
          setState(() {
            _showFriendlyHint = true;
          });
        }
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Permissão de câmera necessária. Use o botão abaixo para fotografar.';
          });
        }
        return;
      }
      if (!_scannerController.value.isRunning) {
        await _scannerController.start();
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Aviso ao iniciar câmera do MobileScanner: $e');
    }
  }

  Future<void> _pickQrFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 92,
      );
      if (photo != null) {
        await _analyzeImageFile(photo.path);
      }
    } catch (e) {
      debugPrint('Erro ao fotografar QR: $e');
    }
  }

  Future<void> _pickQrFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 92,
      );
      if (photo != null) {
        await _analyzeImageFile(photo.path);
      }
    } catch (e) {
      debugPrint('Erro ao selecionar foto do QR: $e');
    }
  }

  Future<void> _analyzeImageFile(String filePath) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = '⚡ Decodificando nota fiscal da imagem...';
    });

    // 1. Tenta identificar QR Code da imagem via MobileScanner
    try {
      final BarcodeCapture? capture = await _scannerController.analyzeImage(filePath);
      if (capture != null && capture.barcodes.isNotEmpty) {
        for (final b in capture.barcodes) {
          final val = b.rawValue?.trim();
          if (val != null && val.isNotEmpty) {
            await _handleBarcodeDetected(capture);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Aviso ao analisar QR Code da foto: $e');
    }

    // 2. Fallback Inteligente Local: Se não encontrou QR Code na foto, extrai dados diretamente via Google ML Kit Text Recognition
    try {
      final ocrRes = await OcrService().processReceiptImage(filePath);
      if ((ocrRes.totalAmount != null && ocrRes.totalAmount! > 0) || ocrRes.items.isNotEmpty) {
        final items = ocrRes.items.map((it) => NfceItem(
          name: it.produto,
          quantity: it.qtd,
          unit: it.unidade,
          unitPrice: it.preco,
          totalPrice: it.total,
        )).toList();

        final dateStr = ocrRes.date != null
            ? '${ocrRes.date!.year}-${ocrRes.date!.month.toString().padLeft(2, '0')}-${ocrRes.date!.day.toString().padLeft(2, '0')}'
            : DateTime.now().toIso8601String().split('T')[0];

        final invoice = NfceInvoice(
          storeName: ocrRes.storeName ?? 'Nota Fiscal',
          date: dateStr,
          total: ocrRes.totalAmount ?? 0.0,
          paymentMethod: ocrRes.paymentMethod ?? 'Cartão de Débito',
          accessKey: ocrRes.nfceKey,
          rawUrl: ocrRes.nfceUrl,
          items: items,
          isFallback: false,
          errorMessage: null,
        );

        if (mounted) {
          HapticFeedback.heavyImpact();
          Navigator.of(context).pop(invoice);
          return;
        }
      }
    } catch (e) {
      debugPrint('Aviso ao processar imagem com Google ML Kit: $e');
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Não conseguimos ler a nota nesta foto. Tente aproximar mais com boa iluminação.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não identificamos o cupom na foto. Aponte mais de perto com foco nítido.'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _browserExtractionTimer?.cancel();
    _friendlyHintTimer?.cancel();
    _animController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        final val = rawValue.trim();
        _isProcessing = true;
        HapticFeedback.heavyImpact();
        _handleBarcodeValue(val);
        return;
      }
    }
  }

  Future<void> _handleBarcodeValue(String val) async {
    _lastScannedValue = val;
    setState(() {
      _isProcessing = true;
      _statusMessage = '⚡ QR Code lido com sucesso!';
    });

    HapticFeedback.heavyImpact();

    // Normaliza a URL de consulta direta
    String targetUrl = val.trim();
    if (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://')) {
      final keyMatch = RegExp(r'\d{44}').firstMatch(val);
      if (keyMatch != null) {
        final key = keyMatch.group(0)!;
        targetUrl = 'https://www.nfce.fazenda.sp.gov.br/NFCeConsultaPublica/Paginas/ConsultaQRCode.aspx?p=$key';
      }
    } else {
      targetUrl = NfceFetcher.normalizeUrl(targetUrl);
    }

    // Extrai dados diretamente do parâmetro p da NFC-e
    double qrTotal = 0.0;
    String qrDate = DateTime.now().toIso8601String().split('T')[0];
    final accessKey = NfceNumberParser.extractAccessKey(targetUrl);

    try {
      final uri = Uri.tryParse(targetUrl);
      final pParam = uri?.queryParameters['p'] ?? (targetUrl.contains('p=') ? targetUrl.split('p=')[1].split('&')[0] : null);
      if (pParam != null) {
        final parts = pParam.split('|');
        for (int i = 0; i < parts.length; i++) {
          final clean = parts[i].replaceAll(',', '.').trim();
          final parsed = double.tryParse(clean);
          if (parsed != null && parsed > 0 && clean.contains('.')) {
            qrTotal = parsed;
            break;
          }
        }
      }
      if (accessKey != null && accessKey.length == 44) {
        final yy = accessKey.substring(2, 4);
        final mm = accessKey.substring(4, 6);
        final year = '20$yy';
        qrDate = '$year-$mm-01';
      }
    } catch (_) {}

    // 1. TENTA CAPTURA DIRETA INSTANTÂNEA VIA SOCKET RAW (SEM WAF / SEM X-Requested-With)
    try {
      final invoice = await _fetcher.fetchAndParse(targetUrl);
      if (invoice.items.isNotEmpty || invoice.total > 0.0) {
        try {
          HapticFeedback.heavyImpact();
        } catch (_) {}

        if (mounted) {
          setState(() {
            _statusMessage = '✓ ${invoice.items.length} produtos capturados!';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('🎉 ${invoice.items.length} produtos capturados (${invoice.storeName})!'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0F172A),
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop(invoice);
          return;
        }
      }
    } catch (e) {
      debugPrint('Aviso captura direta instantânea: $e');
    }

    // 2. Se a consulta direta não retornou itens (ex: CAPTCHA ou confirmação manual), abre a visualização integrada
    _openBrowserView(targetUrl);
  }

  /// Inicializa e abre a visualização integrada do navegador oficial da SEFAZ
  void _openBrowserView(String targetUrl) async {
    try {
      await _scannerController.stop();
    } catch (_) {}

    setState(() {
      _browserUrl = targetUrl;
      _browserProgress = 0.15;
      _browserStatus = 'Carregando página oficial da SEFAZ SP...';
      _isProcessing = false;
    });

    final safeUri = NfceFetcher.parseSafeUri(targetUrl);

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _browserProgress = progress / 100.0;
                if (progress < 100) {
                  _browserStatus = 'Carregando SEFAZ ($progress%)...';
                } else {
                  _browserStatus = 'Página carregada. Buscando itens...';
                }
              });
            }
            if (progress >= 60) {
              _attemptExtractionFromBrowser();
            }
          },
          onPageFinished: (String finishedUrl) {
            if (mounted) {
              setState(() {
                _browserProgress = 1.0;
                _browserStatus = 'Analisando tabela oficial de produtos...';
              });
            }
            _attemptExtractionFromBrowser();
          },
          onWebResourceError: (error) {
            debugPrint('Aviso WebResource: ${error.description}');
          },
        ),
      );

    // Tenta primeiro carregar o HTML já obtido via socket raw para evitar bloqueio WAF da SEFAZ
    final rawHtml = await _fetcher.fetchRawHttp(targetUrl);
    if (rawHtml != null && rawHtml.isNotEmpty && !rawHtml.contains('The requested URL was rejected')) {
      await controller.loadHtmlString(rawHtml, baseUrl: 'https://www.nfce.fazenda.sp.gov.br');
    } else {
      await controller.loadRequest(safeUri);
    }

    setState(() {
      _browserController = controller;
    });

    // Inicia polling ativo a cada 800ms para capturar os itens assim que a tabela for renderizada
    _browserExtractionTimer?.cancel();
    _browserExtractionTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      _attemptExtractionFromBrowser();
    });
  }

  /// Tenta extrair os dados da página da SEFAZ aberta no WebView
  Future<void> _attemptExtractionFromBrowser({bool force = false}) async {
    if (_browserController == null || _isExtractingFromBrowser || !mounted) return;
    _isExtractingFromBrowser = true;

    try {
      // 1. Script inteligente que expande acordeões/tabelas se necessário e extrai o HTML atual
      const script = '''
        (function() {
          try {
            // Se houver botão/aba de itens que precisa ser clicado, clica automaticamente
            var btnItens = document.querySelector('a[href*="tabResult"], #btnItens, .btnItens, a:contains("Itens")');
            if (btnItens && !document.querySelector('#tabResult tr')) {
              btnItens.click();
            }
            return document.documentElement.outerHTML;
          } catch(e) {
            return '';
          }
        })()
      ''';

      final htmlObj = await _browserController!.runJavaScriptReturningResult(script);
      String html = htmlObj.toString();
      if (html.startsWith('"') && html.endsWith('"')) {
        html = jsonDecode(html) as String;
      }

      if (html.isNotEmpty && html.length > 500) {
        final invoice = NfceParser().parse(html, rawUrl: _browserUrl);

        if (invoice.items.isNotEmpty) {
          // ✓ SUCESSO ABSOLUTO! Produtos capturados com precisão!
          _browserExtractionTimer?.cancel();
          HapticFeedback.heavyImpact();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('🎉 ${invoice.items.length} produtos capturados da SEFAZ!'),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF0F172A),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );

            Navigator.of(context).pop(invoice);
            return;
          }
        } else if (force) {
          // Se o usuário clicou explicitamente em 'Capturar'
          _browserExtractionTimer?.cancel();
          HapticFeedback.heavyImpact();

          if (mounted) {
            Navigator.of(context).pop(invoice);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Aviso na extração do browser: $e');
    } finally {
      _isExtractingFromBrowser = false;
    }
  }

  void _closeBrowserView() async {
    _browserExtractionTimer?.cancel();
    setState(() {
      _browserUrl = null;
      _browserController = null;
      _isProcessing = false;
      _statusMessage = 'Aponte a câmera para o QR Code do cupom fiscal';
    });
    try {
      await _scannerController.start();
    } catch (_) {}
  }

  void _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (_) {}
  }

  void _switchCamera() async {
    try {
      await _scannerController.switchCamera();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanBoxSize = (size.width * 0.72).clamp(240.0, 320.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Câmera contínua de alta taxa de quadros (mobile_scanner) com tratamento de tela preta
          MobileScanner(
              controller: _scannerController,
              fit: BoxFit.cover,
              onDetect: _handleBarcodeDetected,
              placeholderBuilder: (context, child) => Container(
                color: Colors.black,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Iniciando câmera nativa...',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              errorBuilder: (context, error, child) => Container(
                color: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined, color: Color(0xFFFBBF24), size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Visor ao vivo indisponível neste aparelho',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Toque no botão abaixo para tirar uma foto nítida do QR Code da nota fiscal com a câmera do seu celular.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _pickQrFromCamera,
                        icon: const Icon(Icons.camera),
                        label: const Text('Fotografar QR Code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _pickQrFromGallery,
                        icon: const Icon(Icons.image, size: 18),
                        label: const Text('Escolher da Galeria'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white30),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            await _scannerController.stop();
                            await _scannerController.start();
                            setState(() {});
                          } catch (_) {}
                        },
                        icon: const Icon(Icons.refresh, color: Colors.white60, size: 16),
                        label: const Text('Tentar Câmera ao Vivo Novamente', style: TextStyle(color: Colors.white60, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 2. Máscara escura com recorte transparente para a moldura
          CustomPaint(
            size: size,
            painter: _ScannerOverlayPainter(
              boxSize: scanBoxSize,
              overlayColor: Colors.black.withOpacity(0.65),
              borderColor: const Color(0xFF10B981), // Emerald
            ),
          ),

          // 3. Linha de laser animada dentro da moldura
          if (!_isProcessing)
            Center(
              child: SizedBox(
                width: scanBoxSize,
                height: scanBoxSize,
                child: AnimatedBuilder(
                  animation: _scanLineAnimation,
                  builder: (context, child) {
                    final topOffset = _scanLineAnimation.value * (scanBoxSize - 4);
                    return Stack(
                      children: [
                        Positioned(
                          top: topOffset,
                          left: 12,
                          right: 12,
                          child: Container(
                            height: 2.5,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Color(0xFF38BDF8), // Sky Blue
                                  Color(0xFF10B981), // Emerald
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF38BDF8).withOpacity(0.8),
                                  blurRadius: 8,
                                  spreadRadius: 1.5,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

          // 4. Barra Superior do Scanner
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                      tooltip: 'Fechar Scanner',
                      onPressed: () => Navigator.of(context).pop(null),
                    ),
                    const Expanded(
                      child: Text(
                        'Leitor de Cupom NFC-e',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isTorchOn ? Icons.flash_on : Icons.flash_off,
                        color: _isTorchOn ? const Color(0xFFFBBF24) : Colors.white70,
                      ),
                      tooltip: _isTorchOn ? 'Desligar Lanterna' : 'Ligar Lanterna',
                      onPressed: _toggleTorch,
                    ),
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios, color: Colors.white70),
                      tooltip: 'Alternar Câmera',
                      onPressed: _switchCamera,
                    ),
                    IconButton(
                      icon: const Icon(Icons.camera_alt, color: Color(0xFF10B981)),
                      tooltip: 'Fotografar QR Code',
                      onPressed: _pickQrFromCamera,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Barra Inferior do Scanner (Instruções e Dica Amigável)
          SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickQrFromCamera,
                            icon: const Icon(Icons.camera_alt, size: 16),
                            label: const Text('Fotografar QR Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _pickQrFromGallery,
                            icon: const Icon(Icons.image, size: 16),
                            label: const Text('Galeria', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white24,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                      if (_showFriendlyHint && !_isProcessing) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lightbulb_outline, color: Color(0xFF38BDF8), size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Dica: Aproxime a câmera ou ligue a lanterna para melhor foco do QR Code.',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(null),
                                child: const Text('Cancelar', style: TextStyle(color: Color(0xFFF87171), fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // 6. Overlay de Carregamento durante Consulta à SEFAZ (Translúcido sobre a câmera)
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.70),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.7)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.25),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                        strokeWidth: 3.5,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'QR Code Lido!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Consultando SEFAZ em tempo real...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          final accessKey = NfceNumberParser.extractAccessKey(_lastScannedValue);
                          Navigator.of(context).pop(
                            NfceInvoice.fallback(
                              accessKey: accessKey,
                              rawUrl: _lastScannedValue,
                              errorMessage: 'Consulta cancelada pelo usuário.',
                            ),
                          );
                        },
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 7. SOLUÇÃO A: NAVEGADOR INTEGRADO INTELIGENTE (OFICIAL SEFAZ SP)
          if (_browserUrl != null && _browserController != null)
            Positioned.fill(
              child: Scaffold(
                backgroundColor: const Color(0xFF0F172A),
                appBar: AppBar(
                  backgroundColor: const Color(0xFF0A3981),
                  elevation: 3,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: 'Voltar ao Scanner',
                    onPressed: _closeBrowserView,
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Consulta SEFAZ SP Oficial',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _browserStatus,
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.open_in_browser, color: Colors.white, size: 20),
                      tooltip: 'Abrir no Google Chrome',
                      onPressed: () async {
                        if (_browserUrl != null) {
                          final uri = Uri.parse(_browserUrl!.replaceAll('|', '%7C'));
                          try {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } catch (e) {
                            debugPrint('Aviso launchUrl: $e');
                          }
                        }
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ElevatedButton.icon(
                        onPressed: () => _attemptExtractionFromBrowser(force: true),
                        icon: const Icon(Icons.download_done, color: Colors.white, size: 16),
                        label: const Text(
                          'Capturar',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 1,
                        ),
                      ),
                    ),
                  ],
                  bottom: _browserProgress < 1.0
                      ? PreferredSize(
                          preferredSize: const Size.fromHeight(3),
                          child: LinearProgressIndicator(
                            value: _browserProgress,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                          ),
                        )
                      : null,
                ),
                body: Stack(
                  children: [
                    WebViewWidget(controller: _browserController!),
                    if (_browserProgress < 0.5)
                      Container(
                        color: const Color(0xFF0F172A),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Conectando ao portal oficial da Fazenda SP...',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Os produtos serão capturados automaticamente.',
                                style: TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Painter customizado que desenha a máscara escura e os cantos estilizados da moldura (reticle)
class _ScannerOverlayPainter extends CustomPainter {
  final double boxSize;
  final Color overlayColor;
  final Color borderColor;

  _ScannerOverlayPainter({
    required this.boxSize,
    required this.overlayColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double left = (size.width - boxSize) / 2;
    final double top = (size.height - boxSize) / 2;
    final double right = left + boxSize;
    final double bottom = top + boxSize;

    final backgroundPaint = Paint()..color = overlayColor;

    // Fundo escurecido ao redor da moldura
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(left, top, right, bottom),
              const Radius.circular(20),
            ),
          ),
      ),
      backgroundPaint,
    );

    // Cantos decorativos da moldura (estilo visor de precisão)
    final cornerPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 28.0;
    const radius = 20.0;

    // Canto Superior Esquerdo
    final topLeft = Path()
      ..moveTo(left, top + cornerLength)
      ..lineTo(left, top + radius)
      ..arcToPoint(Offset(left + radius, top), radius: const Radius.circular(radius))
      ..lineTo(left + cornerLength, top);
    canvas.drawPath(topLeft, cornerPaint);

    // Canto Superior Direito
    final topRight = Path()
      ..moveTo(right - cornerLength, top)
      ..lineTo(right - radius, top)
      ..arcToPoint(Offset(right, top + radius), radius: const Radius.circular(radius))
      ..lineTo(right, top + cornerLength);
    canvas.drawPath(topRight, cornerPaint);

    // Canto Inferior Esquerdo
    final bottomLeft = Path()
      ..moveTo(left, bottom - cornerLength)
      ..lineTo(left, bottom - radius)
      ..arcToPoint(Offset(left + radius, bottom), radius: const Radius.circular(radius))
      ..lineTo(left + cornerLength, bottom);
    canvas.drawPath(bottomLeft, cornerPaint);

    // Canto Inferior Direito
    final bottomRight = Path()
      ..moveTo(right - cornerLength, bottom)
      ..lineTo(right - radius, bottom)
      ..arcToPoint(Offset(right, bottom - radius), radius: const Radius.circular(radius))
      ..lineTo(right, bottom - cornerLength);
    canvas.drawPath(bottomRight, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
