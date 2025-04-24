// Imports for Flutter UI, painting, and math utilities.
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math';

// A widget that displays a graphical representation of certificate of deposit (CD) growth.
class CDGrowthWidget extends StatelessWidget {
  // Constructor for the widget.
  const CDGrowthWidget({super.key});

  // Builds a sized box containing the custom painter for the graph.
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

// Custom painter for drawing the CD growth graph.
class CDGrowthPainter extends CustomPainter {
  // Constructor for the painter.
  const CDGrowthPainter();

  // Paints the graph on the provided canvas.
  @override
  void paint(Canvas canvas, Size size) {
    final axesPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3) 
      ..strokeWidth = 1; 

    // Defines the bounds for the graph.
    var startX = 40.0; 
    var endX = size.width - 40;
    var startY = size.height - 40; 
    var endY = 20.0;

    // Draws the Y-axis.
    canvas.drawLine(
      Offset(startX, startY),
      Offset(startX, endY),
      axesPaint,
    );

    // Draws the X-axis.
    canvas.drawLine(
      Offset(startX, startY),
      Offset(endX, startY),
      axesPaint,
    );

    // Paint for drawing the exponential growth curve.
    final curvePaint = Paint()
      ..color = const Color(0xFF2B3A55) 
      ..strokeWidth = 2 
      ..style = PaintingStyle.stroke; 

    // Path for the exponential curve.
    final path = Path();
    path.moveTo(startX, startY);

    // Plots the exponential curve using a simple growth formula.
    for (double x = 0; x <= endX - startX; x++) {
      double progress = x / (endX - startX); 
      double y = startY - (pow(1.045, progress * 3) - 1) * 50; 
      path.lineTo(startX + x, y);
    }

    // Draws the curve on the canvas.
    canvas.drawPath(path, curvePaint);

    // Paint for drawing key points on the curve.
    final pointPaint = Paint()
      ..color = const Color(0xFFE5BA73) 
      ..style = PaintingStyle.fill; 

    // Defines three key points on the curve (start, middle, end).
    final points = [
      Offset(startX, startY), 
      Offset((startX + endX) / 2, startY - 25),
      Offset(endX, startY - 50), 
    ];

    // Draws each point as a small circle.
    for (var point in points) {
      canvas.drawCircle(point, 4, pointPaint);
    }

    // Style for the Y-axis label.
    final style = ui.ParagraphStyle(
      fontSize: 12,
      height: 1.0,
    );

    // Creates a label for the Y-axis ("15K").
    final yAxisLabel = ui.ParagraphBuilder(style)
      ..pushStyle(ui.TextStyle(
        color: Colors.grey,
        fontSize: 12,
      ))
      ..addText('15K');

    // Renders the Y-axis label.
    final yParagraph = yAxisLabel.build()
      ..layout(const ui.ParagraphConstraints(width: 40));

    canvas.drawParagraph(
      yParagraph,
      Offset(0, endY),
    );
  }

  // Indicates that the painter does not need to repaint.
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}