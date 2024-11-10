import 'dart:io';
import 'package:finsight/models/monthly_spending.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class SpendingReportGenerator {
  static Future<void> generateReport(
      List<MonthlySpending> monthlySpending, BuildContext context) async {
    try {
      final directory = await getTemporaryDirectory();
      final dataDir = Directory('${directory.path}/financial_data');
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
      }

      await _generateCSVFiles(monthlySpending, dataDir.path);

      final pdfPath = '${directory.path}/financial_report.pdf';
      await _generatePDFReport(monthlySpending, pdfPath);

      await OpenFile.open(pdfPath);
    } catch (e) {
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

  static Future<void> _generatePDFReport(
      List<MonthlySpending> monthlySpending, String outputPath) async {
    final pdf = pw.Document();

    // Create PDF content
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            _buildHeader(document: pdf),
            _buildSummarySection(
                document: pdf, monthlySpending: monthlySpending),
            _buildSpendingBreakdown(
                document: pdf, monthlySpending: monthlySpending),
            _buildMonthlyTrends(
                document: pdf, monthlySpending: monthlySpending),
          ];
        },
      ),
    );

    // Save the PDF
    final file = File(outputPath);
    await file.writeAsBytes(await pdf.save());
  }

  static pw.Widget _buildHeader({required pw.Document document}) {
    return pw.Header(
      level: 0,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Financial Report',
              style:
                  pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.Text(
              'Generated on ${DateFormat('MMMM d, y').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 20),
        ],
      ),
    );
  }

  static pw.Widget _buildSummarySection(
      {required pw.Document document,
      required List<MonthlySpending> monthlySpending}) {
    final totalSpent =
        monthlySpending.fold<double>(0, (sum, month) => sum + month.totalSpent);
    final avgMonthlySpend = totalSpent / monthlySpending.length;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 1, text: 'Summary'),
        pw.Paragraph(
          text:
              'Total Spending this Year: ${NumberFormat.currency(symbol: '\$').format(totalSpent)}',
        ),
        pw.Paragraph(
          text:
              'Average Monthly Spend: ${NumberFormat.currency(symbol: '\$').format(avgMonthlySpend)}',
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildSpendingBreakdown(
      {required pw.Document document,
      required List<MonthlySpending> monthlySpending}) {
    final latestMonth = monthlySpending.last;
    final breakdown = latestMonth.categoryBreakdown;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 1, text: 'Latest Month Breakdown'),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: ['Category', 'Amount', 'Percentage'],
          data: breakdown.entries
              .map((entry) => [
                    entry.key,
                    NumberFormat.currency(symbol: '\$').format(entry.value),
                    '${(entry.value / latestMonth.totalSpent * 100).toStringAsFixed(1)}%'
                  ])
              .toList(),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildMonthlyTrends(
      {required pw.Document document,
      required List<MonthlySpending> monthlySpending}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 1, text: 'Monthly Spending Trend'),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: ['Month', 'Total Spent'],
          data: monthlySpending
              .map((month) => [
                    DateFormat('MMM yyyy').format(month.date),
                    NumberFormat.currency(symbol: '\$')
                        .format(month.totalSpent),
                  ])
              .toList(),
        ),
      ],
    );
  }

  static Future<void> _generateCSVFiles(
      List<MonthlySpending> monthlySpending, String dirPath) async {
    // Generate monthly_spending_categories.csv
    final spendingCategories = monthlySpending
        .map((ms) => {
              'Month': DateFormat('yyyy-MM').format(ms.date),
              ...ms.categoryBreakdown,
            })
        .toList();
    await _writeCSV(
        '${dirPath}/monthly_spending_categories.csv', spendingCategories);

    // Generate monthly_cashflow.csv
    final cashflow = monthlySpending
        .where((ms) => ms.income != null)
        .map((ms) => {
              'Month': DateFormat('yyyy-MM').format(ms.date),
              'Expenses': ms.totalSpent,
              'Net_Savings': (ms.income ?? 0) - ms.totalSpent,
            })
        .toList();
    await _writeCSV('${dirPath}/monthly_cashflow.csv', cashflow);
  }

  static Future<void> _writeCSV(
      String path, List<Map<String, dynamic>> data) async {
    if (data.isEmpty) return;

    final file = File(path);
    final header = data.first.keys.toList();
    final rows =
        data.map((row) => header.map((key) => row[key]).toList()).toList();

    final csv = const ListToCsvConverter().convert([
      header,
      ...rows,
    ]);

    await file.writeAsString(csv);
  }
}
