import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'models/nfce_invoice.dart';
import 'nfce_fetcher.dart';
import 'nfce_number_parser.dart';

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

  WebViewController? _webViewController;
  bool _isProcessing = false;
  bool _showInteractiveWebView = false;
  String _statusMessage = 'Aponte a câmera para o QR Code do cupom fiscal';
  bool _isTorchOn = false;
  bool _showFriendlyHint = false;
  Timer? _friendlyHintTimer;
  Timer? _pollTimer;
  Timer? _interactiveTimeoutTimer;
  String? _lastScannedValue;
  int _pollAttempts = 0;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
      returnImage: false,
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
      await _scannerController.start();
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
      _statusMessage = '⚡ Decodificando QR Code da imagem...';
    });
    try {
      final BarcodeCapture? capture = await _scannerController.analyzeImage(filePath);
      if (capture != null && capture.barcodes.isNotEmpty) {
        for (final b in capture.barcodes) {
          final val = b.rawValue?.trim();
          if (val != null && (val.startsWith('http') || RegExp(r'\d{44}').hasMatch(val))) {
            await _handleBarcodeDetected(capture);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Erro no analyzeImage: $e');
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Não conseguimos ler o QR Code nesta foto. Tente aproximar mais da nota.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não identificamos o QR Code na foto. Aponte mais de perto com foco nítido.'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _interactiveTimeoutTimer?.cancel();
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
        final isHttpUrl = val.startsWith('http://') || val.startsWith('https://');
        final hasAccessKey = RegExp(r'\d{44}').hasMatch(val);

        if (isHttpUrl || hasAccessKey) {
          _handleBarcodeValue(val);
          return;
        }
      }
    }
  }

  Future<void> _handleBarcodeValue(String val) async {
    if (_isProcessing) return;

    _lastScannedValue = val;
    setState(() {
      _isProcessing = true;
      _statusMessage = '⚡ QR Code lido! Consultando SEFAZ em tempo real...';
    });

    HapticFeedback.mediumImpact();

    try {
      await _scannerController.stop();
    } catch (_) {}

    // Formata a URL se for apenas chave de acesso
    String targetUrl = val;
    if (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://')) {
      final keyMatch = RegExp(r'\d{44}').firstMatch(val);
      if (keyMatch != null) {
        final key = keyMatch.group(0)!;
        if (key.startsWith('35')) {
          targetUrl = 'https://www.nfce.fazenda.sp.gov.br/qrcode?p=$key|2|1|1|';
        } else {
          targetUrl = 'https://www.nfce.fazenda.sp.gov.br/NFCeConsultaPublica/Paginas/ConsultaPublica.aspx?p=$key';
        }
      }
    }

    // 1. Tenta consulta direta leve via NfceFetcher
    try {
      final directInvoice = await NfceFetcher().fetchAndParse(targetUrl);
      if (!directInvoice.isFallback && (directInvoice.items.isNotEmpty || directInvoice.total > 0)) {
        if (mounted) {
          HapticFeedback.heavyImpact();
          Navigator.of(context).pop(directInvoice);
          return;
        }
      }
    } catch (e) {
      debugPrint('Aviso: Consulta direta não extraiu itens, iniciando motor WebView Chromium: $e');
    }

    // 2. Se a SEFAZ exige JS, cookies ou WAF bypass, inicia o motor WebView Chromium
    _initWebViewResolver(targetUrl);
  }

  void _initWebViewResolver(String targetUrl) {
    if (!mounted) return;

    setState(() {
      _statusMessage = '⚡ Conectando ao portal oficial da SEFAZ...';
    });

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36',
      )
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            _checkAndExtractFromDom();
          },
          onWebResourceError: (err) {
            debugPrint('Aviso de carregamento SEFAZ: ${err.description}');
          },
        ),
      );

    // Se após 3.5 segundos a SEFAZ ainda não devolveu os itens (ex: captcha ou botão de confirmação),
    // exibe o WebView de forma interativa para que o usuário não fique preso
    _interactiveTimeoutTimer?.cancel();
    _interactiveTimeoutTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _isProcessing && !_showInteractiveWebView) {
        setState(() {
          _showInteractiveWebView = true;
        });
      }
    });

    // Inicia verificação periódica a cada 1 segundo (até 25 tentativas)
    _pollAttempts = 0;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _pollAttempts++;
      if (!mounted || !_isProcessing) {
        timer.cancel();
        return;
      }

      final extracted = await _checkAndExtractFromDom();
      if (extracted || _pollAttempts >= 30) {
        timer.cancel();
      }
    });

    try {
      _webViewController!.loadRequest(Uri.parse(targetUrl));
    } catch (e) {
      debugPrint('Erro ao iniciar requisição no WebView: $e');
    }
  }

  Future<bool> _checkAndExtractFromDom() async {
    if (_webViewController == null) return false;

    try {
      // Script JavaScript injetado diretamente no DOM do portal da SEFAZ
      const jsExtractor = r'''
        (function() {
          try {
            // Se for SEFAZ SP ConsultaQRCode esperando postback automático para prosseguir
            var form = document.forms['ctl00'];
            var prosseguir = document.getElementById('hdfProsseguimentoAtual');
            if (prosseguir && prosseguir.value === 'RedirectParaConsultaPublica' && typeof __doPostBack === 'function') {
              __doPostBack('', '');
              return JSON.stringify({ pending: true });
            }

            var items = [];
            var total = 0.0;
            var discount = 0.0;
            var store = '';
            var date = '';
            var accessKey = '';

            // 1. Padrão SEFAZ SP: #tabResult
            var tableSp = document.querySelector('#tabResult');
            if (tableSp) {
              var rows = tableSp.querySelectorAll('tr');
              for (var i = 0; i < rows.length; i++) {
                var r = rows[i];
                var tit = r.querySelector('.txtTit');
                if (!tit) continue;
                var rCod = tit.querySelector('.RCod');
                var name = tit.textContent;
                if (rCod) name = name.replace(rCod.textContent, '');
                name = name.replace(/\(C[oó]digo:?[^\)]*\)/gi, '').replace(/\s+/g, ' ').trim();
                if (!name) continue;

                var qtdEl = r.querySelector('.Rqtd');
                var qtdText = qtdEl ? qtdEl.textContent.replace(/[^\d,\.]/g, '').replace(',', '.') : '1';
                var unEl = r.querySelector('.RUN');
                var unText = unEl ? unEl.textContent.replace(/.*:\s*/, '').trim() : 'UN';
                var vlEl = r.querySelector('.RvlUnit');
                var vlText = vlEl ? vlEl.textContent.replace(/[^\d,\.]/g, '').replace(',', '.') : '0';
                var totEl = r.querySelector('.valor');
                var totText = totEl ? totEl.textContent.replace(/[^\d,\.]/g, '').replace(',', '.') : '0';
                var descEl = r.querySelector('.Rdesconto');
                var descText = descEl ? descEl.textContent.replace(/[^\d,\.]/g, '').replace(',', '.') : '0';

                var q = parseFloat(qtdText) || 1.0;
                var u = (unText || 'UN').toUpperCase();
                var p = parseFloat(vlText) || 0.0;
                var t = parseFloat(totText) || 0.0;
                var d = parseFloat(descText) || 0.0;
                if (t === 0.0 && p > 0.0) t = (q * p) - d;

                items.push({
                  produto: name,
                  nome: name,
                  qtd: q,
                  unidade: u,
                  preco: p,
                  precoUnitario: p,
                  total: t,
                  subtotal: t,
                  desconto: d,
                  validated: true
                });
              }
            }

            // 2. Padrão Nacional / SVRS / Outras SEFAZ (tabela normal ou genérica)
            if (items.length === 0) {
              var allRows = document.querySelectorAll('table tr');
              for (var i = 0; i < allRows.length; i++) {
                var cells = allRows[i].querySelectorAll('td');
                if (cells.length >= 4) {
                  var firstText = cells[0].textContent.toLowerCase();
                  if (firstText.includes('descri') || firstText.includes('produto') || firstText.includes('item')) continue;
                  var name = cells[0].textContent.replace(/\s+/g, ' ').trim();
                  if (name.length < 2) continue;
                  var qtdText = cells[1].textContent.replace(/[^\d,\.]/g, '').replace(',', '.');
                  var unText = cells[2].textContent.replace(/.*:\s*/, '').trim();
                  var vlText = cells[3].textContent.replace(/[^\d,\.]/g, '').replace(',', '.');
                  var totText = cells.length >= 5 ? cells[4].textContent.replace(/[^\d,\.]/g, '').replace(',', '.') : '0';

                  var q = parseFloat(qtdText) || 1.0;
                  var p = parseFloat(vlText) || 0.0;
                  var t = parseFloat(totText) || 0.0;
                  if (t === 0.0 && p > 0.0) t = q * p;

                  items.push({
                    produto: name,
                    nome: name,
                    qtd: q,
                    unidade: (unText || 'UN').toUpperCase(),
                    preco: p,
                    precoUnitario: p,
                    total: t,
                    subtotal: t,
                    desconto: 0.0,
                    validated: true
                  });
                }
              }
            }

            // 3. Totais da Nota
            var totalEls = document.querySelectorAll('.totalNumb, .txtMax, #totalNota, .linhaTotal, .valorTotal');
            for (var i = 0; i < totalEls.length; i++) {
              var m = totalEls[i].textContent.match(/(\d+[\.\d]*,\d{2})/);
              if (m) {
                var v = parseFloat(m[1].replace(/\./g, '').replace(',', '.'));
                if (v > total) total = v;
              }
            }
            if (total === 0.0 && items.length > 0) {
              for (var i = 0; i < items.length; i++) total += items[i].total;
            }

            // 4. Estabelecimento (Prioriza Nome Fantasia)
            var store = '';
            var fantasiaEl = document.querySelector('.fantasia, #lblNomeFantasia, .nomeFantasia, #nomeFantasia, .txtFantasia, #fantasia');
            if (fantasiaEl && fantasiaEl.textContent.trim()) {
              store = fantasiaEl.textContent;
            } else {
              var storeEl = document.querySelector('.txtTopo') || document.querySelector('#u20') || document.querySelector('.empresa') || document.querySelector('#empresa');
              if (storeEl) store = storeEl.textContent;
            }
            if (!store) {
              var h3 = document.querySelector('h3, h4');
              if (h3 && !h3.textContent.toLowerCase().includes('danfe')) {
                store = h3.textContent;
              }
            }
            function sanitizeStore(s) {
              if (!s) return '';
              s = s.replace(/CNPJ:?.*/gi, '').replace(/[\r\n\t]+/g, ' ').replace(/\s+/g, ' ').trim();
              var u = s.toUpperCase();
              if (u.includes('DIA BRASIL')) return 'Supermercado Dia';
              if (u.includes('SENDAS DISTRIBUIDORA')) return 'Assaí Atacadista';
              if (u.includes('COMPANHIA BRASILEIRA DE DISTRIBUI')) return 'Pão de Açúcar';
              if (u.includes('CARREFOUR COMERCIO')) return 'Carrefour';
              if (u.includes('ATACADAO S')) return 'Atacadão';
              if (u.includes('RAIA DROGASIL')) return 'Droga Raia';
              if (u.includes('DROGARIA SAO PAULO') || u.includes('DPSP')) return 'Drogaria São Paulo';
              if (u.includes('DROGARIAS PACHECO')) return 'Drogarias Pacheco';
              if (u.includes('SONDA SUPERMERCADOS')) return 'Sonda Supermercados';
              if (u.includes('ZAFFARI')) return 'Zaffari';
              if (u.includes('SUPERMERCADOS BH')) return 'Supermercados BH';
              s = s.replace(/\s*(?:SOCIEDADE\s+LIMITADA|LTDA\.?|S\/?A\.?|S\.A\.|EIRELI|M\.?E\.?|EPP)\b.*/gi, '');
              s = s.replace(/\s*[-•]?\s*(?:LOJA|FILIAL|SUCURSAL)\s*[\d\w\s-]*$/gi, '');
              return s.trim();
            }
            store = sanitizeStore(store) || 'Estabelecimento Comercial';

            // 5. Data da Compra
            var bodyText = document.body ? document.body.textContent : '';
            var dateMatch = bodyText.match(/(\d{2})\/(\d{2})\/(\d{4})/);
            if (dateMatch) {
              date = dateMatch[3] + '-' + dateMatch[2] + '-' + dateMatch[1];
            } else {
              date = new Date().toISOString().split('T')[0];
            }

            // 6. Chave de Acesso (44 dígitos)
            var keyMatch = (bodyText + ' ' + window.location.href).match(/(\d{44})/);
            if (keyMatch) accessKey = keyMatch[1];

            return JSON.stringify({
              success: (items.length > 0 || total > 0),
              items: items,
              total: total,
              discount: discount,
              store: store || 'Estabelecimento Comercial',
              date: date,
              accessKey: accessKey,
              rawUrl: window.location.href
            });
          } catch(e) {
            return JSON.stringify({ error: e.toString() });
          }
        })();
      ''';

      final Object rawResult = await _webViewController!.runJavaScriptReturningResult(jsExtractor);
      String resultString = rawResult.toString();

      // Desembrulha caso venha como string serializada
      if (resultString.startsWith('"') && resultString.endsWith('"')) {
        try {
          resultString = jsonDecode(resultString) as String;
        } catch (_) {}
      }

      final Map<String, dynamic> data = jsonDecode(resultString) as Map<String, dynamic>;
      final bool success = data['success'] as bool? ?? false;
      final List rawItems = (data['items'] as List?) ?? [];
      final double total = (data['total'] as num?)?.toDouble() ?? 0.0;

      if (success && (rawItems.isNotEmpty || total > 0)) {
        final List<NfceItem> parsedItems = rawItems
            .map((itemMap) => NfceItem.fromJson(Map<String, dynamic>.from(itemMap as Map)))
            .toList();

        final invoice = NfceInvoice(
          storeName: (data['store'] as String?) ?? 'Estabelecimento Comercial',
          date: (data['date'] as String?) ?? DateTime.now().toIso8601String().split('T')[0],
          total: total > 0 ? total : parsedItems.fold<double>(0.0, (acc, it) => acc + it.totalPrice),
          discount: (data['discount'] as num?)?.toDouble() ?? 0.0,
          paymentMethod: 'Cartão / Dinheiro',
          accessKey: data['accessKey'] as String?,
          rawUrl: data['rawUrl'] as String?,
          items: parsedItems,
          isFallback: false,
        );

        if (mounted) {
          _pollTimer?.cancel();
          _interactiveTimeoutTimer?.cancel();
          HapticFeedback.heavyImpact();
          Navigator.of(context).pop(invoice);
        }
        return true;
      }
    } catch (e) {
      debugPrint('Aviso tentativa de extração DOM: $e');
    }
    return false;
  }

  void _manualForceExtract() async {
    final success = await _checkAndExtractFromDom();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aguardando a página da SEFAZ carregar os itens... Tente novamente em alguns segundos.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
          if (!_showInteractiveWebView)
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
          if (!_showInteractiveWebView)
            CustomPaint(
              size: size,
              painter: _ScannerOverlayPainter(
                boxSize: scanBoxSize,
                overlayColor: Colors.black.withOpacity(0.65),
                borderColor: const Color(0xFF10B981), // Emerald
              ),
            ),

          // 3. Linha de laser animada dentro da moldura
          if (!_isProcessing && !_showInteractiveWebView)
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
          if (!_showInteractiveWebView)
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
          if (!_showInteractiveWebView)
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

          // 6. Overlay de Carregamento durante Consulta à SEFAZ (Modo Automático Rápido)
          if (_isProcessing && !_showInteractiveWebView)
            Container(
              color: Colors.black.withOpacity(0.82),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.6)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                        strokeWidth: 3.5,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Consultando SEFAZ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Extraindo produtos, quantidades, valores e totais oficiais da nota fiscal...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 7. MODO INTERATIVO TRANSPARENTE: Se a SEFAZ exigir interação ou CAPTCHA
          if (_showInteractiveWebView && _webViewController != null)
            SafeArea(
              child: Container(
                color: const Color(0xFF0F172A),
                child: Column(
                  children: [
                    // Top Bar de Navegação da SEFAZ
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: const Color(0xFF1E293B),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                            tooltip: 'Fechar',
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
                          ),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Portal Oficial da SEFAZ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Resolva o desafio ou aguarde a nota carregar',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Color(0xFF38BDF8), size: 22),
                            tooltip: 'Recarregar',
                            onPressed: () => _webViewController?.reload(),
                          ),
                        ],
                      ),
                    ),

                    // WebView com a página oficial da SEFAZ
                    Expanded(
                      child: WebViewWidget(controller: _webViewController!),
                    ),

                    // Botão Flutuante de Extração Manual Imediata
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E293B),
                        border: Border(top: BorderSide(color: Colors.white12)),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _manualForceExtract,
                          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                          label: const Text(
                            'Capturar Dados Desta Nota',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981), // Emerald
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                          ),
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
