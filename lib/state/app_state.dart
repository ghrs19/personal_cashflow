import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../utils/calc.dart';
import '../utils/format.dart';

/// Single app-wide state holder (ChangeNotifier via provider).
class AppState extends ChangeNotifier {
  final Repository repo = Repository();

  bool loading = true;
  List<Account> accounts = [];
  List<Account> archivedAccounts = [];
  final Map<int, double> balances = {};
  double total = 0;
  List<CashEntry> monthEntries = [];

  // v1.2 collections
  List<RecurringRule> recurringRules = [];
  List<Budget> budgets = [];
  Map<String, double> budgetSpent = {};
  List<SavingsGoal> goals = [];
  List<Debt> debts = [];
  Map<int, double> debtPaid = {};
  List<EntryTemplate> templates = [];

  // settings
  String lang = 'id';
  String currencyCode = 'IDR';
  ThemeMode themeMode = ThemeMode.system;
  bool lockEnabled = false;
  int accentIndex = 6; // Teal — see AppTheme.accents
  bool reminderEnabled = false;
  int reminderHour = 20;
  int reminderMinute = 0;

  S get s => S(lang);
  bool get isId => lang == 'id';

  Future<void> init() async {
    lang = await repo.getSetting('lang') ?? 'id';
    currencyCode = await repo.getSetting('currency') ?? 'IDR';
    final theme = await repo.getSetting('theme') ?? 'system';
    themeMode = switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    lockEnabled = (await repo.getSetting('lock')) == '1';
    accentIndex = int.tryParse(await repo.getSetting('accent') ?? '') ?? 6;
    reminderEnabled = (await repo.getSetting('reminder')) == '1';
    final rt = await repo.getSetting('reminder_time');
    if (rt != null && rt.contains(':')) {
      reminderHour = int.tryParse(rt.split(':')[0]) ?? 20;
      reminderMinute = int.tryParse(rt.split(':')[1]) ?? 0;
    }
    await reload();
    if (reminderEnabled) await _applyDailyReminder();
  }

  Future<void> reload() async {
    // Generate any due recurring entries first so balances include them.
    try {
      await repo.processRecurringRules();
    } catch (_) {}
    accounts = await repo.getAccounts();
    final all = await repo.getAccounts(includeDeleted: true);
    archivedAccounts = all.where((a) => a.isDeleted).toList();
    balances.clear();
    for (final a in accounts) {
      balances[a.id!] = await repo.accountBalance(a.id!);
    }
    total = await repo.totalBalance();
    final now = DateTime.now();
    monthEntries = await repo.getAllEntries(
      from: DateTime(now.year, now.month, 1),
      to: DateTime(now.year, now.month + 1, 1),
    );
    recurringRules = await repo.getRecurringRules();
    budgets = await repo.getBudgets();
    budgetSpent = await repo.expenseByCategory(
      DateTime(now.year, now.month, 1),
      DateTime(now.year, now.month + 1, 1),
    );
    goals = await repo.getGoals();
    debts = await repo.getDebts();
    debtPaid = await repo.debtPaidTotals();
    templates = await repo.getTemplates();
    loading = false;
    notifyListeners();
    _syncWidget();
  }

  void _syncWidget() {
    final plainIn = monthEntries.where((e) => !e.isTransfer);
    WidgetService.sync(
      balance: fmtMoney(total, lang: lang, currencyCode: currencyCode),
      monthIn: fmtMoney(sumIncome(plainIn), lang: lang, currencyCode: currencyCode),
      monthOut: fmtMoney(sumExpense(plainIn), lang: lang, currencyCode: currencyCode),
    );
  }

  /// Budgets at or above 80% of their limit this month (for Home alerts).
  List<Budget> get budgetAlerts => budgets
      .where((b) => budgetFraction(budgetSpent[b.category] ?? 0, b.limitAmount) >= 0.8)
      .toList();

  double debtRemainingOf(Debt d) {
    final paid = debtPaid[d.id] ?? 0;
    final remaining = d.amount - paid;
    return remaining < 0 ? 0 : remaining;
  }

  // ---- settings ----
  Future<void> setLang(String v) async {
    lang = v;
    await repo.setSetting('lang', v);
    notifyListeners();
  }

  Future<void> setCurrency(String v) async {
    currencyCode = v;
    await repo.setSetting('currency', v);
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeMode = mode;
    await repo.setSetting(
      'theme',
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system',
      },
    );
    notifyListeners();
  }

  Future<void> setLock(bool v) async {
    lockEnabled = v;
    await repo.setSetting('lock', v ? '1' : '0');
    notifyListeners();
  }

  Future<void> setAccent(int index) async {
    accentIndex = index;
    await repo.setSetting('accent', '$index');
    _syncWidget();
    notifyListeners();
  }

  // ---- accounts ----
  Future<void> addAccount(String name, String icon, int colorValue) async {
    await repo.insertAccount(
      Account(name: name, icon: icon, colorValue: colorValue, createdAt: DateTime.now()),
    );
    await reload();
  }

  Future<void> renameAccount(Account a, String name, String icon, int colorValue) async {
    await repo.updateAccount(a.copyWith(name: name, icon: icon, colorValue: colorValue));
    await reload();
  }

  Future<void> archiveAccount(Account a) async {
    await repo.deleteAccount(a.id!);
    await reload();
  }

  Future<void> unarchiveAccount(Account a) async {
    await repo.restoreAccount(a.id!);
    await reload();
  }

  // ---- entries ----
  Future<List<EntryWithBalance>> entriesFor(int accountId) =>
      repo.getEntriesWithBalance(accountId);

  Future<void> addEntry(CashEntry e) async {
    await repo.insertEntry(e);
    await reload();
  }

  Future<void> editEntry(CashEntry e) async {
    await repo.updateEntry(e);
    await reload();
  }

  Future<void> deleteEntry(CashEntry e) async {
    await repo.softDeleteEntry(e);
    await reload();
  }

  Future<void> doTransfer({
    required int fromId,
    required int toId,
    required double amount,
    required DateTime date,
    String notes = '',
  }) async {
    await repo.transfer(
      fromAccountId: fromId,
      toAccountId: toId,
      amount: amount,
      date: date,
      notes: notes,
      outLabel: s.t('transfer'),
      inLabel: s.t('transfer'),
    );
    await reload();
  }

  // ---- reminders ----
  Future<void> _applyDailyReminder() async {
    try {
      await NotificationService.scheduleDaily(
        hour: reminderHour,
        minute: reminderMinute,
        title: s.t('appName'),
        body: s.t('reminderBody'),
      );
    } catch (_) {}
  }

  Future<void> setReminder(bool enabled, {int? hour, int? minute}) async {
    reminderEnabled = enabled;
    if (hour != null) reminderHour = hour;
    if (minute != null) reminderMinute = minute;
    await repo.setSetting('reminder', enabled ? '1' : '0');
    await repo.setSetting('reminder_time', '$reminderHour:$reminderMinute');
    try {
      if (enabled) {
        await NotificationService.requestPermission();
        await _applyDailyReminder();
      } else {
        await NotificationService.cancelDaily();
      }
    } catch (_) {}
    notifyListeners();
  }

  // ---- recurring ----
  Future<void> saveRecurringRule(RecurringRule r) async {
    if (r.id == null) {
      await repo.insertRecurringRule(r);
    } else {
      await repo.updateRecurringRule(r);
    }
    await reload();
  }

  Future<void> deleteRecurringRule(RecurringRule r) async {
    await repo.deleteRecurringRule(r.id!);
    await reload();
  }

  Future<void> toggleRecurringRule(RecurringRule r) async {
    await repo.updateRecurringRule(r.copyWith(active: !r.active));
    await reload();
  }

  // ---- budgets ----
  Future<void> saveBudget(Budget b) async {
    await repo.upsertBudget(b);
    await reload();
  }

  Future<void> removeBudget(Budget b) async {
    await repo.deleteBudget(b.id!);
    await reload();
  }

  // ---- goals ----
  Future<void> saveGoal(SavingsGoal g) async {
    if (g.id == null) {
      await repo.insertGoal(g);
    } else {
      await repo.updateGoal(g);
    }
    await reload();
  }

  Future<void> removeGoal(SavingsGoal g) async {
    await repo.deleteGoal(g.id!);
    await reload();
  }

  Future<void> adjustGoal(SavingsGoal g, double delta) async {
    final next = g.currentAmount + delta;
    await repo.updateGoal(g.copyWith(currentAmount: next < 0 ? 0 : next));
    await reload();
  }

  // ---- debts ----
  Future<void> saveDebt(Debt d) async {
    int id;
    if (d.id == null) {
      id = await repo.insertDebt(d);
    } else {
      id = d.id!;
      await repo.updateDebt(d);
    }
    try {
      if (!d.settled && d.dueDate != null) {
        await NotificationService.scheduleDebtReminder(
          debtId: id,
          dueDate: d.dueDate!,
          title: s.t('appName'),
          body:
              '${s.t('debtDueSoon')}: ${d.person} — ${fmtMoney(d.amount, lang: lang, currencyCode: currencyCode)}',
        );
      } else {
        await NotificationService.cancelDebtReminder(id);
      }
    } catch (_) {}
    await reload();
  }

  Future<void> removeDebt(Debt d) async {
    try {
      await NotificationService.cancelDebtReminder(d.id!);
    } catch (_) {}
    await repo.deleteDebt(d.id!);
    await reload();
  }

  Future<void> addDebtPayment(DebtPayment p) async {
    await repo.insertDebtPayment(p);
    await reload();
  }

  Future<void> removeDebtPayment(DebtPayment p) async {
    await repo.deleteDebtPayment(p.id!);
    await reload();
  }

  Future<void> setDebtSettled(Debt d, bool settled) async {
    await repo.updateDebt(d.copyWith(settled: settled));
    try {
      if (settled) {
        await NotificationService.cancelDebtReminder(d.id!);
      }
    } catch (_) {}
    await reload();
  }

  // ---- templates ----
  Future<void> saveTemplate(EntryTemplate t) async {
    await repo.insertTemplate(t);
    await reload();
  }

  Future<void> removeTemplate(EntryTemplate t) async {
    await repo.deleteTemplate(t.id!);
    await reload();
  }

  /// JSON dump of all tables (used by the unencrypted export).
  Future<Map<String, Object?>> dumpJson() async {
    final entries = await repo.getAllEntries();
    final notes = await repo.getNotes();
    return {
      'exported_at': DateTime.now().toIso8601String(),
      'accounts': accounts.map((a) => a.toMap()).toList(),
      'transactions': entries.map((e) => e.toMap()).toList(),
      'notebook': notes.map((n) => n.toMap()).toList(),
    };
  }
}
