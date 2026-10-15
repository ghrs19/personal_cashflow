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

/// Advances [from] by one recurrence step. Monthly/yearly steps keep the
/// original day-of-month, clamped to the target month's length
/// (e.g. Jan 31 → Feb 28 → Mar 31 when anchored on [anchorDay]).
DateTime advanceDate(DateTime from, String frequency, {int? anchorDay}) {
  final day = DateTime(from.year, from.month, from.day);
  switch (frequency) {
    case 'weekly':
      return day.add(const Duration(days: 7));
    case 'yearly':
      final targetDay = anchorDay ?? day.day;
      final lastDay = DateTime(day.year + 1, day.month + 1, 0).day;
      return DateTime(day.year + 1, day.month, targetDay.clamp(1, lastDay));
    case 'monthly':
    default:
      final targetDay = anchorDay ?? day.day;
      final lastDay = DateTime(day.year, day.month + 2, 0).day;
      return DateTime(day.year, day.month + 1, targetDay.clamp(1, lastDay));
  }
}

/// All occurrence dates of a rule that are due on or before [today],
/// starting at [nextRun]. Capped to avoid runaway catch-up loops.
List<DateTime> dueOccurrences(
  DateTime nextRun,
  String frequency, {
  required DateTime startDate,
  required DateTime today,
  int cap = 24,
}) {
  final result = <DateTime>[];
  var cursor = DateTime(nextRun.year, nextRun.month, nextRun.day);
  final limit = DateTime(today.year, today.month, today.day);
  while (!cursor.isAfter(limit) && result.length < cap) {
    result.add(cursor);
    cursor = advanceDate(cursor, frequency, anchorDay: startDate.day);
  }
  return result;
}

double debtRemaining(Debt debt, Iterable<DebtPayment> payments) {
  final paid = payments.fold(0.0, (sum, p) => sum + p.amount);
  final remaining = debt.amount - paid;
  return remaining < 0 ? 0 : remaining;
}

/// Spent fraction of a budget limit (0..1+, can exceed 1).
double budgetFraction(double spent, double limit) =>
    limit <= 0 ? 0 : spent / limit;

/// Cumulative net series for the balance trend chart: one point per day
/// in [days], each the running sum of that day's net flow up to it.
List<double> cumulativeSeries(Map<DateTime, ({double cashIn, double cashOut})> byDay,
    List<DateTime> days) {
  var running = 0.0;
  return days.map((d) {
    final t = byDay[DateTime(d.year, d.month, d.day)];
    if (t != null) running += t.cashIn - t.cashOut;
    return running;
  }).toList();
}

/// Simple month-end balance projection: current balance plus the
/// average daily net of the elapsed days applied to the remaining days,
/// plus the net of recurring rules still scheduled this month.
double projectMonthEnd({
  required double currentBalance,
  required double monthNetSoFar,
  required int elapsedDays,
  required int remainingDays,
  double scheduledNetRemaining = 0,
}) {
  if (elapsedDays <= 0) return currentBalance + scheduledNetRemaining;
  final avgDaily = monthNetSoFar / elapsedDays;
  return currentBalance + avgDaily * remainingDays + scheduledNetRemaining;
}

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
