import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Tabular exports (CSV / Excel) of transaction lists, complementing the
/// PDF report. Files land in the temp dir and are shared by the caller.
class ExportService {
  static const headers = [
    'Tanggal',
    'Buku Kas',
    'Tipe',
    'Kategori',
    'Catatan',
    'Keterangan',
    'Masuk',
    'Keluar',
  ];

  static List<Object> _row(CashEntry e, Map<int, String> accountNames) {
    final d = e.date;
    final date =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final type = e.isTransfer ? 'Transfer' : (e.isIncome ? 'Masuk' : 'Keluar');
    return [
      date,
      accountNames[e.accountId] ?? '',
      type,
      e.category,
      e.notes,
      e.description,
      e.cashIn,
      e.cashOut,
    ];
  }

  static String _csvEscape(Object v) {
    final s = v.toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static String buildCsv(List<CashEntry> entries, Map<int, String> accountNames) {
    final buf = StringBuffer();
    buf.writeln(headers.map(_csvEscape).join(','));
    for (final e in entries) {
      buf.writeln(_row(e, accountNames).map(_csvEscape).join(','));
    }
    return buf.toString();
  }

  static Future<File> exportCsv(
    List<CashEntry> entries,
    Map<int, String> accountNames,
  ) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(p.join(dir.path, 'personal_cashflow_$stamp.csv'));
    // BOM so Excel opens UTF-8 correctly.
    await file.writeAsString('\uFEFF${buildCsv(entries, accountNames)}',
        encoding: utf8);
    return file;
  }

  static Future<File> exportExcel(
    List<CashEntry> entries,
    Map<int, String> accountNames,
  ) async {
    final book = Excel.createExcel();
    final sheet = book['Transaksi'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (final e in entries) {
      final r = _row(e, accountNames);
      sheet.appendRow([
        TextCellValue(r[0] as String),
        TextCellValue(r[1] as String),
        TextCellValue(r[2] as String),
        TextCellValue(r[3] as String),
        TextCellValue(r[4] as String),
        TextCellValue(r[5] as String),
        DoubleCellValue((r[6] as num).toDouble()),
        DoubleCellValue((r[7] as num).toDouble()),
      ]);
    }
    final bytes = book.encode();
    if (bytes == null) throw StateError('Excel encode failed');
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(p.join(dir.path, 'personal_cashflow_$stamp.xlsx'));
    await file.writeAsBytes(bytes);
    return file;
  }
}
