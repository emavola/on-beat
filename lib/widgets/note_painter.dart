import 'dart:math';

import 'package:flutter/material.dart';

class NotePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;

    canvas.save();

    final Offset center = Offset(size.width / 2, size.height / 2);
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.5);

    final Rect ovalRect = Rect.fromCenter(
      center: Offset.zero,
      width: 30,
      height: 20,
    );

    canvas.drawOval(ovalRect, paint);
    final Offset centerRight = ovalRect.centerRight;

    canvas.restore();
    canvas.translate(center.dx, center.dy);
    final Offset newOff = _transformPoint(centerRight, Offset.zero, -0.5);

    canvas.drawLine(
      newOff,
      Offset(newOff.dx, (-size.height / 2) + newOff.dx),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }

  Offset _transformPoint(Offset p, Offset translation, double angleRadians) {
    // Apply rotation
    final double x = p.dx * cos(angleRadians) - p.dy * sin(angleRadians);
    final double y = p.dx * sin(angleRadians) + p.dy * cos(angleRadians);

    // Apply translation
    return Offset(x + translation.dx, y + translation.dy);
  }
}
