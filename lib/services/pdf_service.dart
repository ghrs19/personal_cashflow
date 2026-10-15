import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';
import '../utils/calc.dart';
import '../utils/format.dart';

/// Builds a clean PDF cash-flow report for a period.
class PdfService {
  static Future<File> buildReport({
    required String title,
    required String periodLabel,
    required List<CashEntry> entries,
    required Map<int, String> accountNames,
    required String lang,
    required String currencyCode,
    required String inLabel,
    required String outLabel,
    required String totalLabel,
  }) async {
    String money(double v) => fmtMoney(v, lang: lang, currencyCode: currencyCode);

    final doc = pw.Document();
    final totalIn = sumIncome(entries.where((e) => !e.isTransfer));
    final totalOut = sumExpense(entries.where((e) => !e.isTransfer));
    final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(periodLabel, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _summaryBox(inLabel, money(totalIn), PdfColors.green700),
              pw.SizedBox(width: 12),
              _summaryBox(outLabel, money(totalOut), PdfColors.red700),
              pw.SizedBox(width: 12),
              _summaryBox(totalLabel, money(totalIn - totalOut), PdfColors.blueGrey800),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headers: [
              'Date',
              'Book',
              'Category',
              'Notes',
              inLabel,
              outLabel,
            ],
            data: sorted.map((e) {
              return [
                fmtDateShort(e.date, lang: lang),
                accountNames[e.accountId] ?? '-',
                e.category,
                e.notes.isNotEmpty ? e.notes : e.description,
                e.cashIn > 0 ? money(e.cashIn) : '',
                e.cashOut > 0 ? money(e.cashOut) : '',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final out = File('${dir.path}/cashflow_report_$stamp.pdf');
    await out.writeAsBytes(await doc.save());
    return out;
  }

  static pw.Widget _summaryBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
