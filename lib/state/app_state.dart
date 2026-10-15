import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../l10n/strings.dart';
import '../models/models.dart';

/// Single app-wide state holder (ChangeNotifier via provider).
class AppState extends ChangeNotifier {
  final Repository repo = Repository();

  bool loading = true;
  List<Account> accounts = [];
  List<Account> archivedAccounts = [];
  final Map<int, double> balances = {};
  double total = 0;
  List<CashEntry> monthEntries = [];

  // settings
  String lang = 'id';
  String currencyCode = 'IDR';
  ThemeMode themeMode = ThemeMode.system;
  bool lockEnabled = false;

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
    await reload();
  }

  Future<void> reload() async {
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
    loading = false;
    notifyListeners();
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
