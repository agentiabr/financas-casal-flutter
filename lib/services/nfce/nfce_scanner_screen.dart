import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'models/nfce_invoice.dart';
import 'nfce_fetcher.dart';

/// Tela Flutter de Scanner de QR Code de Nota Fiscal (NFC-e) em tela cheia
/// Realiza leitura contínua pela câmera nativa com moldura, lanterna, vibração e consulta imediata à SEFAZ.
class NfceScannerScreen extends StatefulWidget {
  final String title;

  const NfceScannerScreen({
    super.key,
    this.title = 'Escanear QR Code da Nota Fiscal',
  });

  @override
  State<NfceScannerScreen> createState() => _NfceScannerScreenState();
}

class _NfceScannerScreenState extends State<NfceScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _scannerController;
  late final AnimationController _animController;
  late final Animation<double> _scanLineAnimation;

  bool _isProcessing = false;
  String _statusMessage = 'Aponte a câmera para o QR Code do cupom fiscal';
  bool _isTorchOn = false;
  bool _showFriendlyHint = false;
  Timer? _friendlyHintTimer;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Dica amigável após 10 segundos caso o usuário tenha dificuldade com iluminação
    _friendlyHintTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && !_isProcessing) {
        setState(() {
          _showFriendlyHint = true;
        });
      }
    });
  }

  @override
  void dispose() {
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

        // Verifica se é uma URL (ex: https://www.nfce.fazenda.sp.gov.br/qrcode?p=...) ou Chave de 44 dígitos
        final isHttpUrl = val.startsWith('http://') || val.startsWith('https://');
        final hasAccessKey = RegExp(r'\d{44}').hasMatch(val);

        if (isHttpUrl || hasAccessKey) {
          setState(() {
            _isProcessing = true;
            _statusMessage = '⚡ QR Code lido! Consultando SEFAZ em tempo real...';
          });

          // Feedback tátil de sucesso imediato
          HapticFeedback.mediumImpact();

          try {
            final fetcher = NfceFetcher();
            final invoice = await fetcher.fetchAndParse(val);

            if (mounted) {
              Navigator.of(context).pop(invoice);
            }
          } catch (e) {
            if (mounted) {
              Navigator.of(context).pop(
                NfceInvoice.fallback(
                  rawUrl: val,
                  errorMessage: 'Erro inesperado na consulta: $e',
                ),
              );
            }
          }
          return;
        }
      }
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
          // 1. Câmera contínua de alta taxa de quadros (mobile_scanner)
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcodeDetected,
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

          // 4. Barra Superior (Voltar, Título, Lanterna e Alternar Câmera)
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
                  ],
                ),
              ),
            ),
          ),

          // 5. Barra Inferior (Instruções e Dica Amigável de Timeout)
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

          // 6. Overlay de Carregamento durante Consulta à SEFAZ
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.78),
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
