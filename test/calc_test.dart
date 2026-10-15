import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cashflow/models/models.dart';
import 'package:personal_cashflow/utils/calc.dart';

CashEntry entry({
  double cashIn = 0,
  double cashOut = 0,
  int type = 0,
  String category = '',
  DateTime? date,
}) =>
    CashEntry(
      accountId: 1,
      date: date ?? DateTime(2026, 10, 1, 9),
      cashIn: cashIn,
      cashOut: cashOut,
      category: category,
      transactionType: type,
    );

void main() {
  group('running balances', () {
    test('accumulates signed amounts in order', () {
      final result = attachRunningBalances([
        entry(cashIn: 1000),
        entry(cashOut: 250),
        entry(cashIn: 500),
      ]);
      expect(result.map((r) => r.balanceAfter).toList(), [1000.0, 750.0, 1250.0]);
    });

    test('empty list stays empty', () {
      expect(attachRunningBalances(const []), isEmpty);
    });
  });

  group('sums', () {
    test('income/expense/net exclude nothing by themselves', () {
      final entries = [entry(cashIn: 100), entry(cashOut: 40), entry(cashIn: 10)];
      expect(sumIncome(entries), 110);
      expect(sumExpense(entries), 40);
      expect(netOf(entries), 70);
    });

    test('category totals skip transfers', () {
      final entries = [
        entry(cashOut: 50, category: 'Makanan'),
        entry(cashOut: 30, category: 'Makanan'),
        entry(cashOut: 999, category: 'Transfer', type: 1),
        entry(cashIn: 200, category: 'Gaji'),
      ];
      expect(totalsByCategory(entries, income: false), {'Makanan': 80.0});
      expect(totalsByCategory(entries, income: true), {'Gaji': 200.0});
    });

    test('daily totals group by calendar day', () {
      final entries = [
        entry(cashIn: 100, date: DateTime(2026, 10, 1, 8)),
        entry(cashOut: 25, date: DateTime(2026, 10, 1, 20)),
        entry(cashIn: 50, date: DateTime(2026, 10, 2, 9)),
      ];
      final byDay = totalsByDay(entries);
      expect(byDay[DateTime(2026, 10, 1)]?.cashIn, 100);
      expect(byDay[DateTime(2026, 10, 1)]?.cashOut, 25);
      expect(byDay[DateTime(2026, 10, 2)]?.cashIn, 50);
    });
  });

  group('amount parsing & grouping', () {
    test('indonesian format: dot thousands, comma decimal', () {
      expect(parseAmount('1.500.000', idLocale: true), 1500000);
      expect(parseAmount('25.500,75', idLocale: true), 25500.75);
    });

    test('english format: comma thousands, dot decimal', () {
      expect(parseAmount('1,500,000', idLocale: false), 1500000);
      expect(parseAmount('25,500.75', idLocale: false), 25500.75);
    });

    test('garbage returns null', () {
      expect(parseAmount('abc', idLocale: true), isNull);
      expect(parseAmount('', idLocale: true), isNull);
    });

    test('groupNumber formats with the right separator', () {
      expect(groupNumber(1500000, idLocale: true), '1.500.000');
      expect(groupNumber(1500000, idLocale: false), '1,500,000');
      expect(groupNumber(500, idLocale: true), '500');
    });
  });

  group('denominations', () {
    test('total multiplies count by denomination', () {
      const denoms = [
        Denomination(denomination: 100000, count: 2),
        Denomination(denomination: 20000, count: 3),
        Denomination(denomination: 1000, count: 0),
      ];
      expect(denominationTotal(denoms), 260000);
    });
  });
}
