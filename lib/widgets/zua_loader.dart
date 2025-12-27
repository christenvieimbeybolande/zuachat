import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 🔥 ZuaLoader Rouge (petit + rapide)
class ZuaLoader extends StatefulWidget {
  final double size; // taille du carré
  final bool looping; // si true → tourne sans fin

  const ZuaLoader({super.key, this.size = 60, this.looping = false});

  @override
  State<ZuaLoader> createState() => _ZuaLoaderState();
}

class _ZuaLoaderState extends State<ZuaLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400), // ⚡ beaucoup plus rapide
    );

    if (widget.looping) {
      _ctrl.repeat();
    } else {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFFF0000); // 🔴 rouge ZuaChat

    return Center(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final progress = _ctrl.value;
          final pathLen = 450.0; // adapté à la petite taille
          final dashOffset = pathLen * (1 - progress);

          return Transform.scale(
            scale: 0.94 + 0.06 * math.sin(progress * math.pi * 2),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(widget.size * 0.25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: EdgeInsets.all(widget.size * 0.22),
              child: CustomPaint(
                painter: _ZPainter(
                  color: brand,
                  strokeWidth: widget.size * 0.16, // ligne plus fine
                  dashOffset: dashOffset,
                  totalLength: pathLen,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 🎨 “Z” animé rouge
class _ZPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashOffset;
  final double totalLength;

  _ZPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashOffset,
    required this.totalLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height);

    final visibleRatio = 1 - (dashOffset / totalLength).clamp(0, 1);
    final metrics = path.computeMetrics().first;
    final extractLen = metrics.length * visibleRatio;
    final subPath = metrics.extractPath(0, extractLen);
    canvas.drawPath(subPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
