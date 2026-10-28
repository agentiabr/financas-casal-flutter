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
  String _statusMessage = 'Aponte a câmera para o QR Code ou Código de Barras da NFC-e';
  bool _isTorchOn = false;
  double _currentZoom = 1.0;
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
      autoStart: true,
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      returnImage: false,
      formats: const [
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.itf,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.dataMatrix,
        BarcodeFormat.pdf417,
      ],
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Garante inicializacao robusta apos montagem completa do frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCamera();
    });

    // Se uma URL inicial foi informada diretamente
    if (widget.initialUrl != null && widget.initialUrl!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleBarcodeValue(widget.initialUrl!.trim());
      });
    } else {
      // Dica amigavel apos 8 segundos caso o usuario tenha dificuldade com iluminacao
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
            _statusMessage = 'Permissao de camera necessaria para ler a nota fiscal.';
          });
        }
        return;
      }

      // Pequena pausa para garantir liberacao de sessoes anteriores de camera no hardware
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      int retries = 3;
      while (retries > 0 && mounted) {
        try {
          if (!_scannerController.value.isRunning) {
            await _scannerController.start();
          }
          break;
        } catch (e) {
          retries--;
          debugPrint('Tentando inicializar camera do MobileScanner... ()');
          if (retries > 0) {
            await Future.delayed(const Duration(milliseconds: 350));
          }
        }
      }
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('Aviso ao inicializar camera do MobileScanner: ');
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
    try {
      _scannerController.dispose();
    } catch (_) {}
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
      _statusMessage = '⚡ Código lido com sucesso!';
    });

    HapticFeedback.heavyImpact();

    // Normaliza a URL de consulta direta
    String targetUrl = val.trim();
    if (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://')) {
      final digits = val.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 44) {
        // Chave de acesso oficial da NFC-e de 44 dígitos
        targetUrl = NfceNumberParser.buildUrlFromAccessKey(digits);
      } else {
        final keyMatch = RegExp(r'\d{44}').firstMatch(digits);
        if (keyMatch != null) {
          targetUrl = NfceNumberParser.buildUrlFromAccessKey(keyMatch.group(0)!);
        } else if (digits.length >= 8 && digits.length <= 14) {
          // É código de produto avulso (ex: EAN-13 na embalagem)
          if (mounted) {
            _showProductBarcodeInfoDialog(digits);
          }
          return;
        } else {
          // Código não reconhecido
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _statusMessage = 'Código não reconhecido. Aponte para a NFC-e (QR Code ou Código de Barras).';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Código não reconhecido ($val). Aponte para a nota fiscal.'),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
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
      _statusMessage = 'Aponte a câmera para o QR Code ou Código de Barras da NFC-e';
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

  Future<void> _setZoom(double zoom) async {
    try {
      await _scannerController.setZoomScale(zoom);
      if (mounted) {
        setState(() {
          _currentZoom = zoom;
        });
      }
    } catch (e) {
      debugPrint('Aviso ao alterar zoom: $e');
    }
  }

  Widget _buildZoomButton(double zoom, String label) {
    final isSelected = (_currentZoom - zoom).abs() < 0.1;
    return GestureDetector(
      onTap: () => _setZoom(zoom),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981) : Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : Colors.white38,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showProductBarcodeInfoDialog(String ean) {
    setState(() {
      _isProcessing = false;
      _statusMessage = 'Código de barras de produto detectado (EAN: $ean)';
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code_scanner, color: Color(0xFF38BDF8), size: 30),
            ),
            const SizedBox(height: 16),
            const Text(
              'Código de Produto Detectado',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Você leu o código de um produto individual (EAN: $ean).\n\nPara importar a nota com todos os itens, aponte a câmera para o QR Code quadrado ou o código de barras da Nota Fiscal (DANFE NFC-e de 44 dígitos).',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _openManualKeyDialog();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Digitar Chave', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Entendi, Ler Nota', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openManualKeyDialog() {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_note, color: Color(0xFF10B981), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Digitar ou Colar Chave',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Chave de 44 dígitos ou link da NFC-e',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: textController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Ex: 3526 1000 ... ou cole a URL',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste, color: Color(0xFF38BDF8)),
                  tooltip: 'Colar da Área de Transferência',
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null && data!.text!.trim().isNotEmpty) {
                      textController.text = data.text!.trim();
                    }
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                final txt = textController.text.trim();
                if (txt.isNotEmpty) {
                  Navigator.of(ctx).pop();
                  _handleBarcodeValue(txt);
                }
              },
              icon: const Icon(Icons.search),
              label: const Text('Consultar Nota Fiscal', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() => textController.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boxWidth = (size.width * 0.86).clamp(260.0, 350.0);
    final boxHeight = (size.width * 0.72).clamp(220.0, 300.0);

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
                      const Icon(Icons.qr_code_scanner, color: Color(0xFF10B981), size: 52),
                      const SizedBox(height: 16),
                      const Text(
                        'Leitor de Cupom NFC-e Pronto',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Aponte para o QR Code da nota fiscal. Se a imagem nao abrir de imediato, toque no botao abaixo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _initCamera,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Iniciar Camera Novamente', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _openManualKeyDialog,
                        icon: const Icon(Icons.edit_note, color: Colors.white70, size: 18),
                        label: const Text('Digitar Chave Manualmente', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 2. Máscara escura com recorte retangular transparente para a moldura (suporta QR Code e Código de Barras horizontal)
          CustomPaint(
            size: size,
            painter: _ScannerOverlayPainter(
              boxWidth: boxWidth,
              boxHeight: boxHeight,
              overlayColor: Colors.black.withOpacity(0.65),
              borderColor: const Color(0xFF10B981), // Emerald
            ),
          ),

          // Indicador de suporte duplo (QR Code e Código de Barras)
          Positioned(
            top: ((size.height - boxHeight) / 2 - 38).clamp(70.0, 400.0),
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.6)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner, color: Color(0xFF10B981), size: 15),
                    SizedBox(width: 6),
                    Text(
                      'QR Code ou Código de Barras',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Linha de laser animada dentro da moldura
          if (!_isProcessing)
            Center(
              child: SizedBox(
                width: boxWidth,
                height: boxHeight,
                child: AnimatedBuilder(
                  animation: _scanLineAnimation,
                  builder: (context, child) {
                    final topOffset = _scanLineAnimation.value * (boxHeight - 4);
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
                      tooltip: 'Fotografar Cupom',
                      onPressed: _pickQrFromCamera,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Barra Inferior do Scanner (Zoom, Ações Rápidas, Instruções e Dicas)
          SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Seletor de Zoom Rápido para Cupom Térmico
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildZoomButton(1.0, '1x'),
                          const SizedBox(width: 8),
                          _buildZoomButton(2.0, '2x'),
                          const SizedBox(width: 8),
                          _buildZoomButton(3.0, '3x'),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Mensagem de Status
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

                      // Botões de Ação: Fotografar, Galeria e Digitar Chave
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickQrFromCamera,
                            icon: const Icon(Icons.camera_alt, size: 15),
                            label: const Text('Fotografar', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _pickQrFromGallery,
                            icon: const Icon(Icons.image, size: 15),
                            label: const Text('Galeria', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white24,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _openManualKeyDialog,
                            icon: const Icon(Icons.keyboard, size: 15),
                            label: const Text('Digitar Chave', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: const Color(0xFF38BDF8),
                              side: const BorderSide(color: Color(0xFF38BDF8), width: 0.8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                  'Dica: Use os botões de zoom 2x/3x ou a lanterna para melhor foco do código.',
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
  final double boxWidth;
  final double boxHeight;
  final Color overlayColor;
  final Color borderColor;

  _ScannerOverlayPainter({
    required this.boxWidth,
    required this.boxHeight,
    required this.overlayColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double left = (size.width - boxWidth) / 2;
    final double top = (size.height - boxHeight) / 2;
    final double right = left + boxWidth;
    final double bottom = top + boxHeight;

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
