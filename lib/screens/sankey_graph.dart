import 'package:flutter/material.dart';
import 'package:finsight/models/monthly_spending.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

class SankeyDiagramScreen extends StatefulWidget {
  final MonthlySpending monthlySpending;

  const SankeyDiagramScreen({Key? key, required this.monthlySpending})
      : super(key: key);

  @override
  State<SankeyDiagramScreen> createState() => _SankeyDiagramScreenState();
}

class _SankeyDiagramScreenState extends State<SankeyDiagramScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Money Flow - ${DateFormat('MMMM yyyy').format(widget.monthlySpending.date)}'),
        backgroundColor: const Color(0xFF2B3A55),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Income and Expense Flow',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                height: 600,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: SankeyDiagramPainter(
                      monthlySpending: widget.monthlySpending,
                    ),
                  ),
                ),
              ),
              _buildLegend(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Legend',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              _legendItem('Gross Income', const Color(0xFF8ECAE6)),
              _legendItem('Net Income', const Color(0xFFE5BA73)),
              _legendItem('Taxes', const Color(0xFFE76F51)),
              _legendItem('Housing', const Color(0xFF9CC5A1)),
              _legendItem('Food', const Color(0xFFFFB380)),
              _legendItem('Lifestyle', const Color(0xFFD8BBD0)),
              _legendItem('Savings', const Color(0xFFBFD7EA)),
              _legendItem('Misc', const Color(0xFF95A5A6)),
              _legendItem('Utilities', const Color(0xFF73A9AD)),
              _legendItem('Insurance', const Color.fromARGB(255, 83, 199, 139)),
              _legendItem('Health', const Color(0xFFAA98A9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}

class SankeyDiagramPainter extends CustomPainter {
  final MonthlySpending monthlySpending;

  SankeyDiagramPainter({required this.monthlySpending});

  @override
  void paint(Canvas canvas, Size size) {
    double grossIncome = monthlySpending.earnings ?? 0;
    double taxRate = 0.25;
    double taxes = grossIncome * taxRate;
    double netIncome = grossIncome - taxes;

    double housing = monthlySpending.rent;
    double food = monthlySpending.groceries + monthlySpending.diningOut;
    double health = monthlySpending.healthcare;
    double lifestyle = monthlySpending.entertainment +
        monthlySpending.shopping +
        monthlySpending.transportation;
    double utilities = monthlySpending.utilities;
    double insurance = monthlySpending.insurance;
    double misc = monthlySpending.miscellaneous;

    double totalExpenses =
        housing + food + health + lifestyle + utilities + insurance + misc;
    double savings = netIncome - totalExpenses;
    if (savings < 0) savings = 0;

    final List<double> columnPositions = [
      60,
      size.width * 0.4,
      size.width - 100,
    ];

    final Map<String, Color> colors = {
      'grossIncome': const Color(0xFF8ECAE6),
      'netIncome': const Color(0xFFE5BA73),
      'taxes': const Color(0xFFE76F51),
      'housing': const Color(0xFF9CC5A1),
      'savings': const Color(0xFFBFD7EA),
      'lifestyle': const Color(0xFFD8BBD0),
      'food': const Color(0xFFFFB380),
      'health': const Color(0xFFAA98A9),
      'utilities': const Color(0xFF73A9AD),
      'insurance': const Color.fromARGB(255, 83, 199, 139),
      'misc': const Color(0xFF95A5A6),
    };

    double availableHeight = size.height - 60; // Leave space for labels
    double heightFactor = availableHeight / grossIncome;

    final double columnWidth = 40;

    // First column - Gross Income
    double startY = 30;

    _drawNode(canvas, 'Gross\nIncome', columnPositions[0], startY, columnWidth,
        grossIncome * heightFactor, colors['grossIncome']!);

    _drawMoneyValue(canvas, grossIncome, columnPositions[0] + columnWidth / 2,
        startY + 250, true, true);

    // Second column - Split into Net Income and Taxes
    double taxY = startY;
    double netIncomeY = taxY + taxes * heightFactor + 5;

    _drawFlow(canvas, columnPositions[0] + columnWidth, startY,
        columnPositions[1], taxY, taxes * heightFactor, colors['taxes']!);
    _drawFlow(
        canvas,
        columnPositions[0] + columnWidth,
        startY + taxes * heightFactor,
        columnPositions[1],
        netIncomeY,
        netIncome * heightFactor,
        colors['netIncome']!);

    _drawNode(canvas, 'Taxes', columnPositions[1], taxY, columnWidth,
        taxes * heightFactor, colors['taxes']!);
    _drawNode(canvas, 'Net\nIncome', columnPositions[1], netIncomeY,
        columnWidth, netIncome * heightFactor, colors['netIncome']!);

    _drawMoneyValue(canvas, taxes, columnPositions[1] + columnWidth / 2,
        taxY + (taxes * heightFactor / 2) - 30, true, false);

    _drawMoneyValue(canvas, netIncome, columnPositions[1] + columnWidth / 2,
        netIncomeY + (netIncome * heightFactor / 2) - 30, true, false);

    List<Map<String, dynamic>> expenses = [
      {'name': 'Housing', 'amount': housing, 'color': colors['housing']!},
      {'name': 'Food', 'amount': food, 'color': colors['food']!},
      {'name': 'Lifestyle', 'amount': lifestyle, 'color': colors['lifestyle']!},
      {'name': 'Misc', 'amount': misc, 'color': colors['misc']!},
      {'name': 'INS.', 'amount': insurance, 'color': colors['insurance']!},
      {'name': 'Utilities', 'amount': utilities, 'color': colors['utilities']!},
      {'name': 'Health', 'amount': health, 'color': colors['health']!},
    ];

    // Always include savings in the expense list
    expenses.add(
        {'name': 'Savings', 'amount': savings, 'color': colors['savings']!});

    // Sort expenses by amount (largest first)
    expenses.sort(
        (a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    // Make sure netIncome flows fully connect with all expenses
    // Ensure net income node extends far enough to connect all flows
    double fullNetIncomeHeight = netIncome * heightFactor;
    double expensesTotalHeight = expenses.fold(0.0,
        (sum, expense) => sum + ((expense['amount'] as double) * heightFactor));

    // If the net income height is less than the total expenses height,
    // adjust how we distribute the flows
    double adjustmentFactor = 1.0;
    if (fullNetIncomeHeight < expensesTotalHeight) {
      adjustmentFactor = fullNetIncomeHeight / expensesTotalHeight;
    }

    double currentSourceY = netIncomeY;
    double currentTargetY = startY;

    for (var i = 0; i < expenses.length; i++) {
      var expense = expenses[i];
      if (expense['amount'] <= 0) continue;

      double expenseHeight =
          expense['amount'] * heightFactor * adjustmentFactor;

      _drawFlow(canvas, columnPositions[1] + columnWidth, currentSourceY,
          columnPositions[2], currentTargetY, expenseHeight, expense['color']);

      _drawNode(canvas, expense['name'], columnPositions[2], currentTargetY,
          columnWidth, expenseHeight, expense['color']);

      _drawMoneyValue(
          canvas,
          expense['amount'] as double,
          columnPositions[2] + columnWidth + 5,
          currentTargetY + expenseHeight / 2,
          false,
          false);

      currentSourceY += expenseHeight;
      currentTargetY += expenseHeight;
    }
  }

  void _drawNode(Canvas canvas, String label, double x, double y, double width,
      double height, Color color) {
    final rect = Rect.fromLTWH(x, y, width, height);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, paint);

    if (height >= 20) {
      final textSpan = TextSpan(
        text: label,
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );

      textPainter.layout(maxWidth: width);

      textPainter.paint(
          canvas,
          Offset(x + width / 2 - textPainter.width / 2,
              y + height / 2 - textPainter.height / 2));
    }
  }

  void _drawFlow(Canvas canvas, double startX, double startY, double endX,
      double endY, double height, Color color) {
    final path = Path();

    final controlPointX = (startX + endX) / 2;

    path.moveTo(startX, startY);
    path.cubicTo(controlPointX, startY, controlPointX, endY, endX, endY);
    path.lineTo(endX, endY + height);
    path.cubicTo(controlPointX, endY + height, controlPointX, startY + height,
        startX, startY + height);
    path.close();

    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    final outlinePaint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawPath(path, outlinePaint);
  }

  void _drawMoneyValue(Canvas canvas, double amount, double x, double y,
      bool centered, bool above) {
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final text = formatter.format(amount);

    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    );

    textPainter.layout();

    double xPos = x;
    if (centered) {
      xPos = x - textPainter.width / 2;
    }

    double yPos = above ? y - textPainter.height : y - textPainter.height / 2;

    final bgRect = Rect.fromLTWH(
      xPos - 2,
      yPos - 2,
      textPainter.width + 4,
      textPainter.height + 4,
    );

    canvas.drawRect(
      bgRect,
      Paint()..color = Colors.white.withOpacity(0.85),
    );

    textPainter.paint(canvas, Offset(xPos, yPos));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
