// This screen visualizes income and expense flows using a Sankey diagram.
import 'package:flutter/material.dart';
import 'package:finsight/models/monthly_spending.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

// Main widget for the Sankey diagram screen, displaying financial flows for a given month.
class SankeyDiagramScreen extends StatefulWidget {
  // Monthly spending data to visualize.
  final MonthlySpending monthlySpending;

  const SankeyDiagramScreen({Key? key, required this.monthlySpending})
      : super(key: key);

  @override
  State<SankeyDiagramScreen> createState() => _SankeyDiagramScreenState();
}

// State class managing the UI and custom painting for the Sankey diagram.
class _SankeyDiagramScreenState extends State<SankeyDiagramScreen> {
  @override
  Widget build(BuildContext context) {
    // Main scaffold with an app bar, diagram, and legend.
    return Scaffold(
      appBar: AppBar(
        // Display the month and year of the spending data.
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
              // Container for the custom Sankey diagram.
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
              // Legend explaining the colors used in the diagram.
              _buildLegend(),
            ],
          ),
        ),
      ),
    );
  }

  // Build the legend for the Sankey diagram, showing categories and their colors.
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

  // Build a single legend item with a colored square and label.
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

// Custom painter for drawing the Sankey diagram.
class SankeyDiagramPainter extends CustomPainter {
  // Monthly spending data to visualize.
  final MonthlySpending monthlySpending;

  SankeyDiagramPainter({required this.monthlySpending});

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate financial values from the monthly spending data.
    double grossIncome = monthlySpending.earnings ?? 0;
    // Assume a fixed tax rate of 25%.
    double taxRate = 0.25;
    double taxes = grossIncome * taxRate;
    double netIncome = grossIncome - taxes;

    // Aggregate expenses by category.
    double housing = monthlySpending.rent;
    double food = monthlySpending.groceries + monthlySpending.diningOut;
    double health = monthlySpending.healthcare;
    double lifestyle = monthlySpending.entertainment +
        monthlySpending.shopping +
        monthlySpending.transportation;
    double utilities = monthlySpending.utilities;
    double insurance = monthlySpending.insurance;
    double misc = monthlySpending.miscellaneous;

    // Calculate total expenses and savings.
    double totalExpenses =
        housing + food + health + lifestyle + utilities + insurance + misc;
    double savings = netIncome - totalExpenses;
    if (savings < 0) savings = 0; // Ensure savings is non-negative.

    // Define horizontal positions for the three columns of the Sankey diagram.
    final List<double> columnPositions = [
      60,
      size.width * 0.4,
      size.width - 100,
    ];

    // Map categories to their respective colors.
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

    // Calculate the height scaling factor based on available space and gross income.
    double availableHeight = size.height - 60; // Leave space for labels
    double heightFactor = availableHeight / grossIncome;

    final double columnWidth = 40;

    // Draw first column: Gross Income node.
    double startY = 30;

    _drawNode(canvas, 'Gross\nIncome', columnPositions[0], startY, columnWidth,
        grossIncome * heightFactor, colors['grossIncome']!);

    // Display the gross income amount.
    _drawMoneyValue(canvas, grossIncome, columnPositions[0] + columnWidth / 2,
        startY + 250, true, true);

    // Draw second column: Split into Taxes and Net Income.
    double taxY = startY;
    double netIncomeY = taxY + taxes * heightFactor + 5;

    // Draw flow from Gross Income to Taxes.
    _drawFlow(canvas, columnPositions[0] + columnWidth, startY,
        columnPositions[1], taxY, taxes * heightFactor, colors['taxes']!);
    // Draw flow from Gross Income to Net Income.
    _drawFlow(
        canvas,
        columnPositions[0] + columnWidth,
        startY + taxes * heightFactor,
        columnPositions[1],
        netIncomeY,
        netIncome * heightFactor,
        colors['netIncome']!);

    // Draw Taxes and Net Income nodes.
    _drawNode(canvas, 'Taxes', columnPositions[1], taxY, columnWidth,
        taxes * heightFactor, colors['taxes']!);
    _drawNode(canvas, 'Net\nIncome', columnPositions[1], netIncomeY,
        columnWidth, netIncome * heightFactor, colors['netIncome']!);

    // Display amounts for Taxes and Net Income.
    _drawMoneyValue(canvas, taxes, columnPositions[1] + columnWidth / 2,
        taxY + (taxes * heightFactor / 2) - 30, true, false);

    _drawMoneyValue(canvas, netIncome, columnPositions[1] + columnWidth / 2,
        netIncomeY + (netIncome * heightFactor / 2) - 30, true, false);

    // List of expenses to display in the third column.
    List<Map<String, dynamic>> expenses = [
      {'name': 'Housing', 'amount': housing, 'color': colors['housing']!},
      {'name': 'Food', 'amount': food, 'color': colors['food']!},
      {'name': 'Lifestyle', 'amount': lifestyle, 'color': colors['lifestyle']!},
      {'name': 'Misc', 'amount': misc, 'color': colors['misc']!},
      {'name': 'INS.', 'amount': insurance, 'color': colors['insurance']!},
      {'name': 'Utilities', 'amount': utilities, 'color': colors['utilities']!},
      {'name': 'Health', 'amount': health, 'color': colors['health']!},
    ];

    // Always include savings in the expense list.
    expenses.add(
        {'name': 'Savings', 'amount': savings, 'color': colors['savings']!});

    // Sort expenses by amount (largest first) for visual clarity.
    expenses.sort(
        (a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    // Ensure Net Income flows connect properly with all expenses.
    double fullNetIncomeHeight = netIncome * heightFactor;
    double expensesTotalHeight = expenses.fold(0.0,
        (sum, expense) => sum + ((expense['amount'] as double) * heightFactor));

    // Adjust flow heights if Net Income height is less than total expenses height.
    double adjustmentFactor = 1.0;
    if (fullNetIncomeHeight < expensesTotalHeight) {
      adjustmentFactor = fullNetIncomeHeight / expensesTotalHeight;
    }

    double currentSourceY = netIncomeY;
    double currentTargetY = startY;

    // Draw flows and nodes for each expense.
    for (var i = 0; i < expenses.length; i++) {
      var expense = expenses[i];
      if (expense['amount'] <= 0) continue; // Skip zero-amount expenses.

      double expenseHeight =
          expense['amount'] * heightFactor * adjustmentFactor;

      // Draw flow from Net Income to the expense.
      _drawFlow(canvas, columnPositions[1] + columnWidth, currentSourceY,
          columnPositions[2], currentTargetY, expenseHeight, expense['color']);

      // Draw the expense node.
      _drawNode(canvas, expense['name'], columnPositions[2], currentTargetY,
          columnWidth, expenseHeight, expense['color']);

      // Display the expense amount.
      _drawMoneyValue(
          canvas,
          expense['amount'] as double,
          columnPositions[2] + columnWidth + 5,
          currentTargetY + expenseHeight / 2,
          false,
          false);

      // Update positions for the next flow/node.
      currentSourceY += expenseHeight;
      currentTargetY += expenseHeight;
    }
  }

  // Draw a rectangular node with a label.
  void _drawNode(Canvas canvas, String label, double x, double y, double width,
      double height, Color color) {
    final rect = Rect.fromLTWH(x, y, width, height);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, paint);

    // Only draw the label if the node is tall enough.
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

  // Draw a curved flow between two points with a specified height and color.
  void _drawFlow(Canvas canvas, double startX, double startY, double endX,
      double endY, double height, Color color) {
    final path = Path();

    // Use a control point for smooth cubic Bezier curves.
    final controlPointX = (startX + endX) / 2;

    path.moveTo(startX, startY);
    path.cubicTo(controlPointX, startY, controlPointX, endY, endX, endY);
    path.lineTo(endX, endY + height);
    path.cubicTo(controlPointX, endY + height, controlPointX, startY + height,
        startX, startY + height);
    path.close();

    // Draw the filled flow with slight transparency.
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // Draw an outline for better visual definition.
    final outlinePaint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawPath(path, outlinePaint);
  }

  // Draw a formatted money value with a white background for readability.
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

    // Adjust text position based on centering and above/below placement.
    double xPos = x;
    if (centered) {
      xPos = x - textPainter.width / 2;
    }

    double yPos = above ? y - textPainter.height : y - textPainter.height / 2;

    // Draw a white background for the text.
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

  // Always repaint the diagram to ensure updates are reflected.
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}