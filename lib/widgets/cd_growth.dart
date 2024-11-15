import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math';

class CDGrowthWidget extends StatelessWidget {
  const CDGrowthWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 150,
      child: CustomPaint(
        painter: CDGrowthPainter(),
      ),
    );
  }
}

class CDGrowthPainter extends CustomPainter {
  const CDGrowthPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Draw axes
    final axesPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1;

    var startX = 40.0;
    var endX = size.width - 40;
    var startY = size.height - 40;
    var endY = 20.0;

    // Y-axis
    canvas.drawLine(
      Offset(startX, startY),
      Offset(startX, endY),
      axesPaint,
    );

    // X-axis
    canvas.drawLine(
      Offset(startX, startY),
      Offset(endX, startY),
      axesPaint,
    );

    // Draw the exponential curve
    final curvePaint = Paint()
      ..color = const Color(0xFF2B3A55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(startX, startY); // Start from bottom left

    // Calculate points for smooth exponential curve
    for (double x = 0; x <= endX - startX; x++) {
      double progress = x / (endX - startX);
      double y = startY - (pow(1.045, progress * 3) - 1) * 50;
      path.lineTo(startX + x, y);
    }

    canvas.drawPath(path, curvePaint);

    // Draw points
    final pointPaint = Paint()
      ..color = const Color(0xFFE5BA73)
      ..style = PaintingStyle.fill;

    // Three points on the curve
    final points = [
      Offset(startX, startY), // Initial investment
      Offset((startX + endX) / 2, startY - 25), // Midpoint
      Offset(endX, startY - 50), // Final value
    ];

    for (var point in points) {
      canvas.drawCircle(point, 4, pointPaint);
    }

    // Add Y-axis label ($15K)
    final style = ui.ParagraphStyle(
      fontSize: 12,
      height: 1.0,
    );

    final yAxisLabel = ui.ParagraphBuilder(style)
      ..pushStyle(ui.TextStyle(
        color: Colors.grey,
        fontSize: 12,
      ))
      ..addText('15K');

    final yParagraph = yAxisLabel.build()
      ..layout(const ui.ParagraphConstraints(width: 40));

    canvas.drawParagraph(
      yParagraph,
      Offset(0, endY),
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
