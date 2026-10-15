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
