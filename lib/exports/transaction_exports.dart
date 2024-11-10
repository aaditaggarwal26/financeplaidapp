import 'package:finsight/models/transaction.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class TransactionExport {
  final List<Transaction> transactions;

  TransactionExport(this.transactions);

  Future<void> generateAndDownloadReport() async {
    final pdf = pw.Document();

    final font = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(font);
    final logoImage = pw.MemoryImage(
      (await rootBundle.load('assets/images/logo_cropped.png'))
          .buffer
          .asUint8List(),
    );

    await _addMainReport(pdf, ttf, logoImage);

    final output = await getApplicationDocumentsDirectory();
    final String fileName =
        'transaction_report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  Future<void> _addMainReport(
      pw.Document pdf, pw.Font ttf, pw.MemoryImage logoImage) async {
    final totalCredit = transactions
        .where((t) => t.transactionType == 'Credit')
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalDebit = transactions
        .where((t) => t.transactionType == 'Debit')
        .fold(0.0, (sum, t) => sum + t.amount);
    final categoryTotals = <String, double>{};
    final monthlyTotals = <String, Map<String, double>>{};

    for (var transaction in transactions) {
      if (transaction.transactionType == 'Debit') {
        categoryTotals[transaction.category] =
            (categoryTotals[transaction.category] ?? 0) + transaction.amount;
      }
      final month = DateFormat('MMM yyyy').format(transaction.date);
      monthlyTotals[month] ??= {'Credit': 0.0, 'Debit': 0.0};
      monthlyTotals[month]![transaction.transactionType] =
          (monthlyTotals[month]![transaction.transactionType] ?? 0) +
              transaction.amount;
    }

    final totalSpend =
        categoryTotals.values.fold(0.0, (sum, amount) => sum + amount);

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Financial Transaction Report',
                      style: pw.TextStyle(
                          font: ttf,
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Generated on ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
                      style: pw.TextStyle(
                          font: ttf, fontSize: 14, color: PdfColors.grey),
                    ),
                  ],
                ),
                pw.Image(logoImage, width: 60, height: 60),
              ],
            ),
            pw.SizedBox(height: 20),

            // Summary cards
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryCard(
                    'Total Income',
                    '\$${totalCredit.toStringAsFixed(2)}',
                    PdfColors.green,
                    ttf),
                _buildSummaryCard('Total Expenses',
                    '\$${totalDebit.toStringAsFixed(2)}', PdfColors.red, ttf),
                _buildSummaryCard(
                    'Net Balance',
                    '\$${(totalCredit - totalDebit).toStringAsFixed(2)}',
                    (totalCredit - totalDebit) >= 0
                        ? PdfColors.green
                        : PdfColors.red,
                    ttf),
              ],
            ),
            pw.SizedBox(height: 30),

            pw.Text('Spending by Category',
                style: pw.TextStyle(
                    font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            ...categoryTotals.entries.map((entry) {
              final percentage =
                  (entry.value / totalSpend * 100).toStringAsFixed(1);
              return pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(entry.key, style: pw.TextStyle(font: ttf)),
                      pw.Text(
                          '\$${entry.value.toStringAsFixed(2)} ($percentage%)',
                          style: pw.TextStyle(font: ttf)),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  pw.LinearProgressIndicator(
                    value: entry.value / totalSpend,
                    backgroundColor: PdfColors.grey300,
                    valueColor: PdfColors.black,
                  ),
                  pw.SizedBox(height: 10),
                ],
              );
            }),
            pw.SizedBox(height: 30),

            pw.Text('Monthly Overview',
                style: pw.TextStyle(
                    font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                _buildTableHeader(['Month', 'Income', 'Expenses', 'Net'], ttf),
                ...monthlyTotals.entries.map((entry) {
                  final credit = entry.value['Credit'] ?? 0.0;
                  final debit = entry.value['Debit'] ?? 0.0;
                  final net = credit - debit;
                  return pw.TableRow(
                    children: [
                      _buildTableCell(entry.key, ttf),
                      _buildTableCell('\$${credit.toStringAsFixed(2)}', ttf,
                          color: PdfColors.green),
                      _buildTableCell('\$${debit.toStringAsFixed(2)}', ttf,
                          color: PdfColors.red),
                      _buildTableCell('\$${net.toStringAsFixed(2)}', ttf,
                          color: net >= 0 ? PdfColors.green : PdfColors.red),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addDetailedTransactions(pw.Document pdf, pw.Font ttf) async {
    final nonEmptyTransactions =
        transactions.where((t) => t.amount > 0).toList();
    if (nonEmptyTransactions.isEmpty) return;

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Detailed Transactions',
              style: pw.TextStyle(
                  font: ttf, fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                _buildTableHeader(
                    ['Date', 'Description', 'Category', 'Amount'], ttf),
                ...nonEmptyTransactions.map((transaction) => pw.TableRow(
                      children: [
                        _buildTableCell(
                            DateFormat('MMM d').format(transaction.date), ttf),
                        _buildTableCell(transaction.description, ttf),
                        _buildTableCell(transaction.category, ttf),
                        _buildTableCell(
                          '${transaction.transactionType == 'Credit' ? '+' : ''}\$${transaction.amount.toStringAsFixed(2)}',
                          ttf,
                          color: transaction.transactionType == 'Credit'
                              ? PdfColors.green
                              : PdfColors.red,
                        ),
                      ],
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildSummaryCard(
      String title, String amount, PdfColor color, pw.Font ttf) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(font: ttf, fontSize: 12)),
          pw.SizedBox(height: 5),
          pw.Text(amount,
              style: pw.TextStyle(
                  font: ttf,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  pw.TableRow _buildTableHeader(List<String> cells, pw.Font ttf) {
    return pw.TableRow(
      children: cells
          .map((cell) => pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(cell,
                    style: pw.TextStyle(
                        font: ttf, fontWeight: pw.FontWeight.bold)),
              ))
          .toList(),
    );
  }

  pw.Widget _buildTableCell(String text, pw.Font ttf, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: pw.TextStyle(font: ttf, color: color)),
    );
  }
}
