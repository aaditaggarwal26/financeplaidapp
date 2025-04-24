import 'dart:io';
import 'package:finsight/models/monthly_spending.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Utility class for generating spending reports as PDF and CSV files.
class SpendingReportGenerator {
  // Generate both PDF and CSV versions of the spending report.
  // Automatically opens the PDF report once created.
  static Future<void> generateReport(
      List<MonthlySpending> monthlySpending, BuildContext context) async {
    try {
      // Create a temporary directory for saving the files
      final directory = await getTemporaryDirectory();
      final dataDir = Directory('${directory.path}/financial_data');

      // Ensure the directory exists
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
      }

      // Save spending data as CSV
      await _generateCSVFiles(monthlySpending, dataDir.path);

      // Generate PDF report and open it
      final pdfPath = '${directory.path}/financial_report.pdf';
      await _generatePDFReport(monthlySpending, pdfPath);
      await OpenFile.open(pdfPath);
    } catch (e) {
      // Show error dialog if something goes wrong during report generation
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to generate report: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      rethrow;
    }
  }

  /// Builds the PDF report content and writes it to a file.
  static Future<void> _generatePDFReport(
      List<MonthlySpending> monthlySpending, String outputPath) async {
    final pdf = pw.Document();

    // Structure the PDF with multiple pages
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          _buildHeader(document: pdf),
          _buildSummarySection(document: pdf, monthlySpending: monthlySpending),
          _buildSpendingBreakdown(document: pdf, monthlySpending: monthlySpending),
          _buildMonthlyTrends(document: pdf, monthlySpending: monthlySpending),
        ],
      ),
    );

    // Write the PDF to file
    final file = File(outputPath);
    await file.writeAsBytes(await pdf.save());
  }

  /// Builds the top header section of the report.
  static pw.Widget _buildHeader({required pw.Document document}) {
    return pw.Header(
      level: 0,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Financial Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.Text('Generated on ${DateFormat('MMMM d, y').format(DateTime.now())}', style: pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Summary of total and average spending.
  static pw.Widget _buildSummarySection({required pw.Document document, required List<MonthlySpending> monthlySpending}) {
    final totalSpent = monthlySpending.fold(0.0, (sum, m) => sum + m.totalSpent);
    final avgMonthlySpend = totalSpent / monthlySpending.length;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 1, text: 'Summary'),
        pw.Paragraph(text: 'Total Spending this Year: ${NumberFormat.currency(symbol: '\$').format(totalSpent)}'),
        pw.Paragraph(text: 'Average Monthly Spend: ${NumberFormat.currency(symbol: '\$').format(avgMonthlySpend)}'),
        pw.SizedBox(height: 20),
      ],
    );
  }

  /// Breakdown of the latest month's spending by category.
  static pw.Widget _buildSpendingBreakdown({required pw.Document document, required List<MonthlySpending> monthlySpending}) {
    final latestMonth = monthlySpending.last;
    final breakdown = latestMonth.categoryBreakdown;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 1, text: 'Latest Month Breakdown'),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: ['Category', 'Amount', 'Percentage'],
          data: breakdown.entries.map((entry) => [
            entry.key,
            NumberFormat.currency(symbol: '\$').format(entry.value),
            '${(entry.value / latestMonth.totalSpent * 100).toStringAsFixed(1)}%'
          ]).toList(),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  /// Shows spending trend by month.
  static pw.Widget _buildMonthlyTrends({required pw.Document document, required List<MonthlySpending> monthlySpending}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 1, text: 'Monthly Spending Trend'),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: ['Month', 'Total Spent'],
          data: monthlySpending.map((month) => [
            DateFormat('MMM yyyy').format(month.date),
            NumberFormat.currency(symbol: '\$').format(month.totalSpent)
          ]).toList(),
        ),
      ],
    );
  }

  /// Generates CSV files for spending categories and cashflow.
  static Future<void> _generateCSVFiles(List<MonthlySpending> monthlySpending, String dirPath) async {
    // Categories by month
    final spendingCategories = monthlySpending.map((ms) => {
      'Month': DateFormat('yyyy-MM').format(ms.date),
      ...ms.categoryBreakdown,
    }).toList();
    await _writeCSV('$dirPath/monthly_spending_categories.csv', spendingCategories);

    // Cashflow with income vs expenses
    final cashflow = monthlySpending.where((ms) => ms.income != null).map((ms) => {
      'Month': DateFormat('yyyy-MM').format(ms.date),
      'Expenses': ms.totalSpent,
      'Net_Savings': (ms.income ?? 0) - ms.totalSpent,
    }).toList();
    await _writeCSV('$dirPath/monthly_cashflow.csv', cashflow);
  }

  /// Helper method to write a list of maps to a CSV file.
  static Future<void> _writeCSV(String path, List<Map<String, dynamic>> data) async {
    if (data.isEmpty) return;

    final file = File(path);
    final headers = data.first.keys.toList();
    final rows = data.map((row) => headers.map((key) => row[key]).toList()).toList();

    final csv = const ListToCsvConverter().convert([
      headers,
      ...rows,
    ]);

    await file.writeAsString(csv);
  }
}
