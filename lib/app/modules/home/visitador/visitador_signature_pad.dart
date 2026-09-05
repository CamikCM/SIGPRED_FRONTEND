import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class VisitadorSignatureCaptureResult {
  const VisitadorSignatureCaptureResult({
    required this.base64,
    required this.capturedAt,
  });

  final String base64;
  final DateTime capturedAt;
}

Future<VisitadorSignatureCaptureResult?> showVisitadorSignatureCapture(
  BuildContext context, {
  String? initialBase64,
  String signerRole = 'Doctor',
}) {
  return Navigator.of(context).push<VisitadorSignatureCaptureResult>(
    MaterialPageRoute<VisitadorSignatureCaptureResult>(
      fullscreenDialog: true,
      builder: (pageContext) => _VisitadorSignatureCapturePage(
        initialBase64: initialBase64,
        signerRole: signerRole,
      ),
    ),
  );
}

class _VisitadorSignatureCapturePage extends StatefulWidget {
  const _VisitadorSignatureCapturePage({
    required this.initialBase64,
    required this.signerRole,
  });

  final String? initialBase64;
  final String signerRole;

  @override
  State<_VisitadorSignatureCapturePage> createState() =>
      _VisitadorSignatureCapturePageState();
}

class _VisitadorSignatureCapturePageState
    extends State<_VisitadorSignatureCapturePage> {
  String? _workingBase64;

  @override
  void initState() {
    super.initState();
    _workingBase64 = widget.initialBase64;
  }

  bool get _hasSignature =>
      _workingBase64 != null && _workingBase64!.trim().isNotEmpty;

  void _confirm() {
    if (!_hasSignature) return;

    Navigator.of(context).pop(
      VisitadorSignatureCaptureResult(
        base64: _workingBase64!,
        capturedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Firma de conformidad'),
        leading: IconButton(
          tooltip: 'Cancelar',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desiredHeight = constraints.maxHeight - 220;
            final padHeight = desiredHeight.clamp(230.0, 430.0);

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withOpacity(.45),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.draw_rounded,
                          color: scheme.primary,
                          size: 23,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Solicita la firma',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.signerRole}: firme dentro del recuadro '
                                'y luego pulse “Confirmar firma”.',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  VisitadorSignaturePad(
                    initialBase64: widget.initialBase64,
                    height: padHeight,
                    onChanged: (value) {
                      if (!mounted) return;
                      setState(() => _workingBase64 = value);
                    },
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _hasSignature ? _confirm : null,
                          icon: const Icon(Icons.verified_rounded),
                          label: const Text('Confirmar firma'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class VisitadorSignaturePad extends StatefulWidget {
  const VisitadorSignaturePad({
    super.key,
    required this.onChanged,
    this.initialBase64,
    this.enabled = true,
    this.height = 170,
  });

  final String? initialBase64;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final double height;

  @override
  State<VisitadorSignaturePad> createState() => _VisitadorSignaturePadState();
}

class _VisitadorSignaturePadState extends State<VisitadorSignaturePad> {
  final GlobalKey _boundaryKey = GlobalKey();
  final List<Offset?> _points = <Offset?>[];
  Uint8List? _initialBytes;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _initialBytes = _decode(widget.initialBase64);
  }

  @override
  void didUpdateWidget(covariant VisitadorSignaturePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialBase64 != widget.initialBase64 && _points.isEmpty) {
      _initialBytes = _decode(widget.initialBase64);
    }
  }

  Uint8List? _decode(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    try {
      return base64Decode(text);
    } catch (_) {
      return null;
    }
  }

  void _start(DragStartDetails details) {
    if (!widget.enabled) return;
    setState(() {
      _points.add(details.localPosition);
    });
  }

  void _update(DragUpdateDetails details) {
    if (!widget.enabled) return;
    setState(() {
      _points.add(details.localPosition);
    });
  }

  Future<void> _end(DragEndDetails details) async {
    if (!widget.enabled) return;
    setState(() => _points.add(null));
    await _capture();
  }

  Future<void> _capture() async {
    if (_capturing) return;
    _capturing = true;
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _boundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return;

      final image = await boundary.toImage(pixelRatio: 1.35);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return;

      final data = bytes.buffer.asUint8List();
      widget.onChanged(base64Encode(data));
    } finally {
      _capturing = false;
    }
  }

  void _clear() {
    setState(() {
      _points.clear();
      _initialBytes = null;
    });
    widget.onChanged(null);
  }

  bool get _hasSignature => _initialBytes != null || _points.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RepaintBoundary(
          key: _boundaryKey,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: widget.enabled ? _start : null,
            onPanUpdate: widget.enabled ? _update : null,
            onPanEnd: widget.enabled ? _end : null,
            child: Container(
              height: widget.height,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _hasSignature
                      ? const Color(0xFF12B76A)
                      : const Color(0xFFD0D5DD),
                  width: _hasSignature ? 1.5 : 1,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_initialBytes != null)
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Image.memory(
                        _initialBytes!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  CustomPaint(painter: _SignaturePainter(_points)),
                  if (!_hasSignature)
                    const IgnorePointer(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.draw_outlined,
                              color: Color(0xFF98A2B3),
                              size: 27,
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Firma aquí',
                              style: TextStyle(
                                color: Color(0xFF667085),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: Text(
                _hasSignature
                    ? 'Firma dibujada. Confírmala para regresar al formulario.'
                    : 'Utiliza el dedo o lápiz táctil dentro del recuadro.',
                style: TextStyle(
                  color: _hasSignature
                      ? const Color(0xFF027A48)
                      : scheme.onSurfaceVariant,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: widget.enabled && _hasSignature ? _clear : null,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Limpiar'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF101828)
      ..strokeWidth = 2.25
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      if (current != null && next != null) {
        canvas.drawLine(current, next, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
