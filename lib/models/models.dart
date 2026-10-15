/// Core data models for Personal Cashflow.
///
/// The schema intentionally mirrors the proven structure found in the
/// reference cash book application (accounts / cash transactions /
/// currency notes / notebook), modernised with categories, soft-delete
/// bookkeeping and transfer pairing.
library;

class Account {
  final int? id;
  final String name;
  final String icon; // emoji shown in the UI
  final int colorValue; // material color value
  final DateTime createdAt;
  final bool isDeleted;

  const Account({
    this.id,
    required this.name,
    this.icon = '💰',
    this.colorValue = 0xFF0E7C66,
    required this.createdAt,
    this.isDeleted = false,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': colorValue,
        'created_at': createdAt.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory Account.fromMap(Map<String, Object?> m) => Account(
        id: m['id'] as int?,
        name: m['name'] as String,
        icon: (m['icon'] as String?) ?? '💰',
        colorValue: (m['color'] as int?) ?? 0xFF0E7C66,
        createdAt: DateTime.parse(m['created_at'] as String),
        isDeleted: (m['is_deleted'] as int? ?? 0) == 1,
      );

  Account copyWith({String? name, String? icon, int? colorValue, bool? isDeleted}) =>
      Account(
        id: id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        colorValue: colorValue ?? this.colorValue,
        createdAt: createdAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );
}

/// One cash transaction. Exactly one of [cashIn] / [cashOut] is > 0,
/// mirroring the original schema.
class CashEntry {
  final int? id;
  final int accountId;
  final DateTime date;
  final double cashIn;
  final double cashOut;
  final String notes;
  final String description;
  final String category;
  final List<String> bills; // up to 3 photo paths (bill, bill2, bill3)
  final bool isDeleted;
  final DateTime? deletedAt;

  /// 0 = regular, 1 = transfer out, 2 = transfer in.
  final int transactionType;

  /// Links the two legs of a transfer together.
  final String? transferGroup;

  const CashEntry({
    this.id,
    required this.accountId,
    required this.date,
    this.cashIn = 0,
    this.cashOut = 0,
    this.notes = '',
    this.description = '',
    this.category = '',
    this.bills = const [],
    this.isDeleted = false,
    this.deletedAt,
    this.transactionType = 0,
    this.transferGroup,
  });

  bool get isIncome => cashIn > 0;
  double get amount => isIncome ? cashIn : cashOut;
  double get signed => cashIn - cashOut;
  bool get isTransfer => transactionType != 0;

  Map<String, Object?> toMap() => {
        'id': id,
        'account_id': accountId,
        'date': date.toIso8601String(),
        'cash_in': cashIn,
        'cash_out': cashOut,
        'notes': notes,
        'description': description,
        'category': category,
        'bill': bills.isNotEmpty ? bills[0] : null,
        'bill2': bills.length > 1 ? bills[1] : null,
        'bill3': bills.length > 2 ? bills[2] : null,
        'is_deleted': isDeleted ? 1 : 0,
        'deleted_at': deletedAt?.toIso8601String(),
        'transaction_type': transactionType,
        'transfer_group': transferGroup,
      };

  factory CashEntry.fromMap(Map<String, Object?> m) {
    final bills = <String>[
      if ((m['bill'] as String?)?.isNotEmpty ?? false) m['bill'] as String,
      if ((m['bill2'] as String?)?.isNotEmpty ?? false) m['bill2'] as String,
      if ((m['bill3'] as String?)?.isNotEmpty ?? false) m['bill3'] as String,
    ];
    return CashEntry(
      id: m['id'] as int?,
      accountId: m['account_id'] as int,
      date: DateTime.parse(m['date'] as String),
      cashIn: (m['cash_in'] as num?)?.toDouble() ?? 0,
      cashOut: (m['cash_out'] as num?)?.toDouble() ?? 0,
      notes: (m['notes'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      category: (m['category'] as String?) ?? '',
      bills: bills,
      isDeleted: (m['is_deleted'] as int? ?? 0) == 1,
      deletedAt: m['deleted_at'] == null ? null : DateTime.parse(m['deleted_at'] as String),
      transactionType: (m['transaction_type'] as int?) ?? 0,
      transferGroup: m['transfer_group'] as String?,
    );
  }

  CashEntry copyWith({
    int? accountId,
    DateTime? date,
    double? cashIn,
    double? cashOut,
    String? notes,
    String? description,
    String? category,
    List<String>? bills,
    bool? isDeleted,
    DateTime? deletedAt,
    int? transactionType,
    String? transferGroup,
  }) =>
      CashEntry(
        id: id,
        accountId: accountId ?? this.accountId,
        date: date ?? this.date,
        cashIn: cashIn ?? this.cashIn,
        cashOut: cashOut ?? this.cashOut,
        notes: notes ?? this.notes,
        description: description ?? this.description,
        category: category ?? this.category,
        bills: bills ?? this.bills,
        isDeleted: isDeleted ?? this.isDeleted,
        deletedAt: deletedAt ?? this.deletedAt,
        transactionType: transactionType ?? this.transactionType,
        transferGroup: transferGroup ?? this.transferGroup,
      );
}

class NoteItem {
  final int? id;
  final DateTime date;
  final String note;
  final bool completed;

  const NoteItem({this.id, required this.date, required this.note, this.completed = false});

  Map<String, Object?> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'note': note,
        'completed': completed ? 1 : 0,
      };

  factory NoteItem.fromMap(Map<String, Object?> m) => NoteItem(
        id: m['id'] as int?,
        date: DateTime.parse(m['date'] as String),
        note: m['note'] as String,
        completed: (m['completed'] as int? ?? 0) == 1,
      );

  NoteItem copyWith({String? note, bool? completed, DateTime? date}) => NoteItem(
        id: id,
        date: date ?? this.date,
        note: note ?? this.note,
        completed: completed ?? this.completed,
      );
}

class Denomination {
  final int? id;
  final double denomination;
  final String currency;
  final int count;
  final bool visible;

  const Denomination({
    this.id,
    required this.denomination,
    this.currency = 'IDR',
    this.count = 0,
    this.visible = true,
  });

  double get subtotal => denomination * count;

  Map<String, Object?> toMap() => {
        'id': id,
        'denomination': denomination,
        'currency': currency,
        'count': count,
        'show': visible ? 1 : 0,
      };

  factory Denomination.fromMap(Map<String, Object?> m) => Denomination(
        id: m['id'] as int?,
        denomination: (m['denomination'] as num).toDouble(),
        currency: (m['currency'] as String?) ?? 'IDR',
        count: (m['count'] as int?) ?? 0,
        visible: (m['show'] as int? ?? 1) == 1,
      );

  Denomination copyWith({int? count, bool? visible}) => Denomination(
        id: id,
        denomination: denomination,
        currency: currency,
        count: count ?? this.count,
        visible: visible ?? this.visible,
      );
}

class CategoryItem {
  final int? id;
  final String name;
  final bool isIncome;

  const CategoryItem({this.id, required this.name, required this.isIncome});

  Map<String, Object?> toMap() => {'id': id, 'name': name, 'is_income': isIncome ? 1 : 0};

  factory CategoryItem.fromMap(Map<String, Object?> m) => CategoryItem(
        id: m['id'] as int?,
        name: m['name'] as String,
        isIncome: (m['is_income'] as int? ?? 0) == 1,
      );
}

/// An entry paired with its running balance (computed ascending by date).
class EntryWithBalance {
  final CashEntry entry;
  final double balanceAfter;
  const EntryWithBalance(this.entry, this.balanceAfter);
}

/// A recurring transaction rule (salary, subscription, installment…).
/// [frequency] is 'weekly' | 'monthly' | 'yearly'. [nextRun] is the next
/// date (day precision) on which an entry should be generated.
class RecurringRule {
  final int? id;
  final int accountId;
  final bool isIncome;
  final double amount;
  final String category;
  final String notes;
  final String frequency;
  final DateTime startDate;
  final DateTime nextRun;
  final bool active;

  const RecurringRule({
    this.id,
    required this.accountId,
    required this.isIncome,
    required this.amount,
    this.category = '',
    this.notes = '',
    this.frequency = 'monthly',
    required this.startDate,
    required this.nextRun,
    this.active = true,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'account_id': accountId,
        'is_income': isIncome ? 1 : 0,
        'amount': amount,
        'category': category,
        'notes': notes,
        'frequency': frequency,
        'start_date': startDate.toIso8601String(),
        'next_run': nextRun.toIso8601String(),
        'active': active ? 1 : 0,
      };

  factory RecurringRule.fromMap(Map<String, Object?> m) => RecurringRule(
        id: m['id'] as int?,
        accountId: m['account_id'] as int,
        isIncome: (m['is_income'] as int? ?? 0) == 1,
        amount: (m['amount'] as num).toDouble(),
        category: (m['category'] as String?) ?? '',
        notes: (m['notes'] as String?) ?? '',
        frequency: (m['frequency'] as String?) ?? 'monthly',
        startDate: DateTime.parse(m['start_date'] as String),
        nextRun: DateTime.parse(m['next_run'] as String),
        active: (m['active'] as int? ?? 1) == 1,
      );

  RecurringRule copyWith({DateTime? nextRun, bool? active}) => RecurringRule(
        id: id,
        accountId: accountId,
        isIncome: isIncome,
        amount: amount,
        category: category,
        notes: notes,
        frequency: frequency,
        startDate: startDate,
        nextRun: nextRun ?? this.nextRun,
        active: active ?? this.active,
      );
}

/// A monthly spending limit for one expense category.
class Budget {
  final int? id;
  final String category;
  final double limitAmount;

  const Budget({this.id, required this.category, required this.limitAmount});

  Map<String, Object?> toMap() => {
        'id': id,
        'category': category,
        'limit_amount': limitAmount,
      };

  factory Budget.fromMap(Map<String, Object?> m) => Budget(
        id: m['id'] as int?,
        category: m['category'] as String,
        limitAmount: (m['limit_amount'] as num).toDouble(),
      );
}

/// A savings goal with manually tracked contributions.
class SavingsGoal {
  final int? id;
  final String name;
  final String icon;
  final double targetAmount;
  final double currentAmount;
  final DateTime? deadline;

  const SavingsGoal({
    this.id,
    required this.name,
    this.icon = '🎯',
    required this.targetAmount,
    this.currentAmount = 0,
    this.deadline,
  });

  double get progress =>
      targetAmount <= 0 ? 0 : (currentAmount / targetAmount).clamp(0.0, 1.0);
  bool get reached => currentAmount >= targetAmount && targetAmount > 0;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        'deadline': deadline?.toIso8601String(),
      };

  factory SavingsGoal.fromMap(Map<String, Object?> m) => SavingsGoal(
        id: m['id'] as int?,
        name: m['name'] as String,
        icon: (m['icon'] as String?) ?? '🎯',
        targetAmount: (m['target_amount'] as num).toDouble(),
        currentAmount: (m['current_amount'] as num?)?.toDouble() ?? 0,
        deadline:
            m['deadline'] == null ? null : DateTime.parse(m['deadline'] as String),
      );

  SavingsGoal copyWith({double? currentAmount, String? name, String? icon, double? targetAmount, DateTime? deadline}) =>
      SavingsGoal(
        id: id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        targetAmount: targetAmount ?? this.targetAmount,
        currentAmount: currentAmount ?? this.currentAmount,
        deadline: deadline ?? this.deadline,
      );
}

/// Money lent or borrowed. [isReceivable] = someone owes the user;
/// otherwise the user owes someone. Remaining = amount − payments.
class Debt {
  final int? id;
  final String person;
  final bool isReceivable;
  final double amount;
  final String notes;
  final DateTime createdDate;
  final DateTime? dueDate;
  final bool settled;

  const Debt({
    this.id,
    required this.person,
    required this.isReceivable,
    required this.amount,
    this.notes = '',
    required this.createdDate,
    this.dueDate,
    this.settled = false,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'person': person,
        'is_receivable': isReceivable ? 1 : 0,
        'amount': amount,
        'notes': notes,
        'created_date': createdDate.toIso8601String(),
        'due_date': dueDate?.toIso8601String(),
        'settled': settled ? 1 : 0,
      };

  factory Debt.fromMap(Map<String, Object?> m) => Debt(
        id: m['id'] as int?,
        person: m['person'] as String,
        isReceivable: (m['is_receivable'] as int? ?? 1) == 1,
        amount: (m['amount'] as num).toDouble(),
        notes: (m['notes'] as String?) ?? '',
        createdDate: DateTime.parse(m['created_date'] as String),
        dueDate: m['due_date'] == null ? null : DateTime.parse(m['due_date'] as String),
        settled: (m['settled'] as int? ?? 0) == 1,
      );

  Debt copyWith({bool? settled}) => Debt(
        id: id,
        person: person,
        isReceivable: isReceivable,
        amount: amount,
        notes: notes,
        createdDate: createdDate,
        dueDate: dueDate,
        settled: settled ?? this.settled,
      );
}

class DebtPayment {
  final int? id;
  final int debtId;
  final double amount;
  final DateTime date;
  final String note;

  const DebtPayment({
    this.id,
    required this.debtId,
    required this.amount,
    required this.date,
    this.note = '',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'debt_id': debtId,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory DebtPayment.fromMap(Map<String, Object?> m) => DebtPayment(
        id: m['id'] as int?,
        debtId: m['debt_id'] as int,
        amount: (m['amount'] as num).toDouble(),
        date: DateTime.parse(m['date'] as String),
        note: (m['note'] as String?) ?? '',
      );
}

/// A reusable transaction template (one-tap prefill in the editor).
class EntryTemplate {
  final int? id;
  final String name;
  final int accountId;
  final bool isIncome;
  final double amount;
  final String category;
  final String notes;

  const EntryTemplate({
    this.id,
    required this.name,
    required this.accountId,
    required this.isIncome,
    required this.amount,
    this.category = '',
    this.notes = '',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'account_id': accountId,
        'is_income': isIncome ? 1 : 0,
        'amount': amount,
        'category': category,
        'notes': notes,
      };

  factory EntryTemplate.fromMap(Map<String, Object?> m) => EntryTemplate(
        id: m['id'] as int?,
        name: m['name'] as String,
        accountId: m['account_id'] as int,
        isIncome: (m['is_income'] as int? ?? 0) == 1,
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        category: (m['category'] as String?) ?? '',
        notes: (m['notes'] as String?) ?? '',
      );
}
