import '../models/models.dart';

/// Pure calculation helpers (unit-testable, no platform channels).

/// Attaches a running balance to each entry. [entries] must already be
/// sorted ascending by date/id, which is how the repository returns them.
List<EntryWithBalance> attachRunningBalances(List<CashEntry> entries) {
  var running = 0.0;
  return entries.map((e) {
    running += e.signed;
    return EntryWithBalance(e, running);
  }).toList();
}

double sumIncome(Iterable<CashEntry> entries) =>
    entries.fold(0.0, (sum, e) => sum + e.cashIn);

double sumExpense(Iterable<CashEntry> entries) =>
    entries.fold(0.0, (sum, e) => sum + e.cashOut);

double netOf(Iterable<CashEntry> entries) =>
    entries.fold(0.0, (sum, e) => sum + e.signed);

/// Totals keyed by category name (regular entries only by default).
Map<String, double> totalsByCategory(Iterable<CashEntry> entries, {required bool income}) {
  final result = <String, double>{};
  for (final e in entries) {
    if (e.isTransfer) continue;
    if (income && e.cashIn > 0) {
      result[e.category] = (result[e.category] ?? 0) + e.cashIn;
    } else if (!income && e.cashOut > 0) {
      result[e.category] = (result[e.category] ?? 0) + e.cashOut;
    }
  }
  return result;
}

/// Cash-in / cash-out totals keyed by day (date truncated to midnight).
Map<DateTime, ({double cashIn, double cashOut})> totalsByDay(Iterable<CashEntry> entries) {
  final result = <DateTime, ({double cashIn, double cashOut})>{};
  for (final e in entries) {
    final day = DateTime(e.date.year, e.date.month, e.date.day);
    final prev = result[day] ?? (cashIn: 0.0, cashOut: 0.0);
    result[day] = (
      cashIn: prev.cashIn + e.cashIn,
      cashOut: prev.cashOut + e.cashOut,
    );
  }
  return result;
}

double denominationTotal(Iterable<Denomination> denoms) =>
    denoms.fold(0.0, (sum, d) => sum + d.subtotal);

/// Parses user money input. Accepts thousand separators ('.', ',',
/// spaces) and one decimal separator; returns null when unparseable.
double? parseAmount(String raw, {required bool idLocale}) {
  var s = raw.trim().replaceAll(' ', '');
  if (s.isEmpty) return null;
  if (idLocale) {
    // Indonesian style: '.' thousands, ',' decimal.
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else {
    s = s.replaceAll(',', '');
  }
  return double.tryParse(s);
}

/// Formats a plain number with thousand separators, no currency symbol.
String groupNumber(double value, {required bool idLocale, int decimals = 0}) {
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  final sep = idLocale ? '.' : ',';
  for (var i = 0; i < intPart.length; i++) {
    final idxFromRight = intPart.length - i;
    buf.write(intPart[i]);
    if (idxFromRight > 1 && idxFromRight % 3 == 1) buf.write(sep);
  }
  if (parts.length > 1 && decimals > 0) {
    buf.write(idLocale ? ',' : '.');
    buf.write(parts[1]);
  }
  return buf.toString();
}
