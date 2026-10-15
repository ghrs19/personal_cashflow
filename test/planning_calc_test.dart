import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cashflow/models/models.dart';
import 'package:personal_cashflow/utils/calc.dart';

void main() {
  group('advanceDate', () {
    test('weekly adds 7 days', () {
      expect(advanceDate(DateTime(2026, 10, 15), 'weekly'), DateTime(2026, 10, 22));
    });
    test('monthly keeps anchor day, clamped at month end', () {
      expect(advanceDate(DateTime(2026, 1, 31), 'monthly', anchorDay: 31),
          DateTime(2026, 2, 28));
      expect(advanceDate(DateTime(2026, 2, 28), 'monthly', anchorDay: 31),
          DateTime(2026, 3, 31));
    });
    test('yearly handles leap day anchor', () {
      expect(advanceDate(DateTime(2024, 2, 29), 'yearly', anchorDay: 29),
          DateTime(2025, 2, 28));
    });
  });

  group('dueOccurrences', () {
    test('returns all missed monthly occurrences up to today', () {
      final due = dueOccurrences(
        DateTime(2026, 8, 5),
        'monthly',
        startDate: DateTime(2026, 8, 5),
        today: DateTime(2026, 10, 15),
      );
      expect(due, [DateTime(2026, 8, 5), DateTime(2026, 9, 5), DateTime(2026, 10, 5)]);
    });
    test('empty when next run is in the future', () {
      final due = dueOccurrences(
        DateTime(2026, 11, 1),
        'monthly',
        startDate: DateTime(2026, 11, 1),
        today: DateTime(2026, 10, 15),
      );
      expect(due, isEmpty);
    });
  });

  group('debts & budgets', () {
    test('debtRemaining subtracts payments and never goes negative', () {
      final d = Debt(person: 'A', isReceivable: true, amount: 1000, createdDate: DateTime(2026));
      final payments = [
        DebtPayment(debtId: 1, amount: 400, date: DateTime(2026)),
        DebtPayment(debtId: 1, amount: 700, date: DateTime(2026)),
      ];
      expect(debtRemaining(d, payments), 0);
      expect(debtRemaining(d, payments.take(1)), 600);
    });
    test('budgetFraction guards zero limit', () {
      expect(budgetFraction(50, 0), 0);
      expect(budgetFraction(50, 100), 0.5);
    });
  });

  group('trend & projection', () {
    test('cumulativeSeries accumulates daily net', () {
      final days = [DateTime(2026, 10, 1), DateTime(2026, 10, 2), DateTime(2026, 10, 3)];
      final byDay = {
        DateTime(2026, 10, 1): (cashIn: 100.0, cashOut: 30.0),
        DateTime(2026, 10, 3): (cashIn: 0.0, cashOut: 20.0),
      };
      expect(cumulativeSeries(byDay, days), [70, 70, 50]);
    });
    test('projectMonthEnd extrapolates average daily net', () {
      final v = projectMonthEnd(
        currentBalance: 1000,
        monthNetSoFar: 300,
        elapsedDays: 10,
        remainingDays: 20,
        scheduledNetRemaining: 50,
      );
      expect(v, 1000 + 30 * 20 + 50);
    });
  });
}
