// Imports for transaction model, PDF generation, file handling, and date formatting.
import 'package:finsight/models/transaction.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter/services.dart';

// Handles exporting transactions to a PDF report.
class TransactionExport {
  // List of transactions to include in the report.
  final List<Transaction> transactions;

  // Constructor requiring the transaction list.
  TransactionExport(this.transactions);

  // Generates a PDF report and opens it for the user.
  Future<void> generateAndDownloadReport() async {
    final pdf = pw.Document(); // Creates a new PDF document.

    // Loads the Roboto font for consistent typography.
    final font = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(font);
    // Loads the logo image for branding.
    final logoImage = pw.MemoryImage(
      (await rootBundle.load('assets/images/logo_cropped.png'))
          .buffer
          .asUint8List(),
    );

    // Adds the main report page to the PDF.
    await _addMainReport(pdf, ttf, logoImage);

    // Saves the PDF to the application documents directory.
    final output = await getApplicationDocumentsDirectory();
    final String fileName =
        'transaction_report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    // Opens the generated PDF file.
    await OpenFile.open(file.path);
  }

  // Builds the main report page with summary, category breakdown, and monthly overview.
  Future<void> _addMainReport(
      pw.Document pdf, pw.Font ttf, pw.MemoryImage logoImage) async {
    // Calculates total credit (income) from transactions.
    final totalCredit = transactions
        .where((t) => t.transactionType == 'Credit')
        .fold(0.0, (sum, t) => sum + t.amount);
    // Calculates total debit (expenses) from transactions.
    final totalDebit = transactions
        .where((t) => t.transactionType == 'Debit')
        .fold(0.0, (sum, t) => sum + t.amount);
    // Tracks spending totals by category.
    final categoryTotals = <String, double>{};
    // Tracks monthly totals for credits and debits.
    final monthlyTotals = <String, Map<String, double>>{};

    // Aggregates transactions by category and month.
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

    // Calculates total spending across all categories.
    final totalSpend =
        categoryTotals.values.fold(0.0, (sum, amount) => sum + amount);

    // Adds a page to the PDF with the report content.
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header with title, date, and logo.
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
                pw.Image(logoImage, width: 60, height: 60), // Displays logo.
              ],
            ),
            pw.SizedBox(height: 20),

            // Summary cards for income, expenses, and net balance.
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

            // Spending breakdown by category with progress bars.
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

            // Monthly overview table with income, expenses, and net.
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

  // Adds a detailed transaction list page to the PDF, if transactions exist.
  Future<void> _addDetailedTransactions(pw.Document pdf, pw.Font ttf) async {
    // Filters out transactions with zero amount.
    final nonEmptyTransactions =
        transactions.where((t) => t.amount > 0).toList();
    if (nonEmptyTransactions.isEmpty) return;

    // Adds a new page for detailed transactions.
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

  // Builds a summary card widget for income, expenses, or net balance.
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

  // Builds a table header row with bold text.
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

  // Builds a table cell with optional color for text.
  pw.Widget _buildTableCell(String text, pw.Font ttf, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: pw.TextStyle(font: ttf, color: color)),
    );
  }
}