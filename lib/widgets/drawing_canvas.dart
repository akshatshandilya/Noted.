import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class _DrawStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  _DrawStroke({required this.points, required this.color, required this.width});
}

/// A freehand sketch surface: pen color/size, undo/redo, clear. Exports a
/// PNG snapshot (base64) via [onChanged] after each completed stroke, so the
/// note editor's normal save path can treat it like any other field.
class DrawingCanvas extends StatefulWidget {
  final String? initialPng;
  final ValueChanged<String> onChanged;
  const DrawingCanvas({super.key, required this.initialPng, required this.onChanged});

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  final GlobalKey _boundaryKey = GlobalKey();
  final List<_DrawStroke> _strokes = [];
  final List<_DrawStroke> _redoStack = [];
  _DrawStroke? _current;
  Color _color = const Color(0xFF1C1B1A);
  double _width = 4;
  ui.Image? _bgImage;
  bool _loaded = false;

  static const _palette = [
    Color(0xFF1C1B1A), // ink
    Color(0xFFD14343), // red
    Color(0xFF2C4A8C), // accent blue
    Color(0xFF3D8B5F), // green
  ];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final data = widget.initialPng;
    if (data == null || data.isEmpty) {
      setState(() => _loaded = true);
      return;
    }
    try {
      final bytes = base64Decode(data);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) setState(() { _bgImage = frame.image; _loaded = true; });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  void _start(Offset p) {
    setState(() {
      _current = _DrawStroke(points: [p], color: _color, width: _width);
      _redoStack.clear();
    });
  }

  void _update(Offset p) => setState(() => _current?.points.add(p));

  Future<void> _end() async {
    if (_current == null) return;
    setState(() {
      _strokes.add(_current!);
      _current = null;
    });
    await _export();
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _redoStack.add(_strokes.removeLast()));
    _export();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() => _strokes.add(_redoStack.removeLast()));
    _export();
  }

  void _clear() {
    if (_strokes.isEmpty && _bgImage == null) return;
    setState(() {
      _strokes.clear();
      _redoStack.clear();
      _bgImage = null;
    });
    _export();
  }

  Future<void> _export() async {
    try {
      // Let the frame with the latest stroke actually paint before capturing.
      await Future<void>.delayed(const Duration(milliseconds: 16));
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2);
      final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      widget.onChanged(base64Encode(bytes.buffer.asUint8List()));
    } catch (_) {
      // A failed snapshot must never crash the editor -- the rest of the
      // note (title, tags, etc.) still saves normally either way.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!_loaded) {
      return const SizedBox(height: 320, child: Center(child: CircularProgressIndicator()));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final c in _palette) _swatch(c, scheme),
            const SizedBox(width: 4),
            Expanded(
              child: Slider(
                value: _width,
                min: 2,
                max: 20,
                onChanged: (v) => setState(() => _width = v),
              ),
            ),
            IconButton(
              tooltip: 'Undo',
              onPressed: _strokes.isEmpty ? null : _undo,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'Redo',
              onPressed: _redoStack.isEmpty ? null : _redo,
              icon: const Icon(Icons.redo),
            ),
            IconButton(
              tooltip: 'Clear',
              onPressed: _clear,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 340,
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: scheme.outline)),
            child: RepaintBoundary(
              key: _boundaryKey,
              child: GestureDetector(
                onPanStart: (d) => _start(d.localPosition),
                onPanUpdate: (d) => _update(d.localPosition),
                onPanEnd: (_) => _end(),
                child: CustomPaint(
                  painter: _SketchPainter(strokes: _strokes, current: _current, background: _bgImage),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _swatch(Color c, ColorScheme scheme) {
    final selected = c.value == _color.value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Pen color',
        child: GestureDetector(
          onTap: () => setState(() => _color = c),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 2.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _SketchPainter extends CustomPainter {
  final List<_DrawStroke> strokes;
  final _DrawStroke? current;
  final ui.Image? background;
  _SketchPainter({required this.strokes, required this.current, required this.background});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final bg = background;
    if (bg != null) {
      canvas.drawImageRect(
        bg,
        Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble()),
        Offset.zero & size,
        Paint(),
      );
    }
    for (final s in strokes) {
      _paintStroke(canvas, s);
    }
    if (current != null) _paintStroke(canvas, current!);
  }

  void _paintStroke(Canvas canvas, _DrawStroke s) {
    final paint = Paint()
      ..color = s.color
      ..strokeWidth = s.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    if (s.points.length == 1) {
      canvas.drawCircle(s.points.first, s.width / 2, paint..style = PaintingStyle.fill);
      return;
    }
    for (var i = 0; i < s.points.length - 1; i++) {
      canvas.drawLine(s.points[i], s.points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) => true;
}
