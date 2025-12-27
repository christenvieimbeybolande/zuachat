import 'package:flutter/material.dart';
import 'dart:math' as math;

/// ✅ Badge Vérifié ZuaChat (BLEU)
class VerifiedBadge extends StatelessWidget {
  final double size;
  final bool isVerified;
  final double spacing;

  const VerifiedBadge({
    super.key,
    required this.isVerified,
    this.size = 18,
    this.spacing = 4,
  });

  /// 🔹 Variante mini
  factory VerifiedBadge.mini({required bool isVerified}) {
    return VerifiedBadge(
      isVerified: isVerified,
      size: 14,
      spacing: 3,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(left: spacing),
      child: CustomPaint(
        size: Size.square(size),
        painter: _BlueBadgePainter(),
      ),
    );
  }
}

/// 🎨 Badge bleu (étoile + check)
class _BlueBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w / 2;
    final cx = w / 2;
    final cy = h / 2;

    // 🔵 Bleu vérifié (pro, fiable)
    const blue = Color(0xFF1877F2); // Facebook-style verified

    // --- Ombre légère ---
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    // --- Forme étoilée ---
    Path starPath(double offset) {
      final path = Path();
      const spikes = 8;

      for (int i = 0; i < spikes * 2; i++) {
        final angle = i * math.pi / spikes;
        final radius = (i.isEven) ? r : r * 0.78;
        final x = cx + radius * math.cos(angle);
        final y = cy + radius * math.sin(angle) + offset;

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      return path;
    }

    // Ombre
    canvas.drawPath(starPath(1.2), shadowPaint);

    // Badge bleu
    final fill = Paint()
      ..color = blue
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(starPath(0), fill);

    // --- Check blanc ---
    final tick = Paint()
      ..color = Colors.white
      ..strokeWidth = w * 0.13
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final checkPath = Path()
      ..moveTo(w * 0.28, h * 0.55)
      ..lineTo(w * 0.45, h * 0.72)
      ..lineTo(w * 0.74, h * 0.38);

    canvas.drawPath(checkPath, tick);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
