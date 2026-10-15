import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/calc.dart';
import '../utils/format.dart';
import 'book_screen.dart';
import 'budgets_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final scheme = Theme.of(context).colorScheme;
    final monthIn = sumIncome(state.monthEntries.where((e) => !e.isTransfer));
    final monthOut = sumExpense(state.monthEntries.where((e) => !e.isTransfer));

    return Scaffold(
      appBar: AppBar(title: Text(s.t('appName'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Greeting strip — KasirFree POS welcome-card pattern:
          // primary left accent border, greeting + date in primary.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: scheme.primary.withValues(alpha: 0.5), width: 5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_greetingIcon(), color: scheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      _greeting(state),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  fmtDate(DateTime.now(), lang: state.lang),
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Balance card — filled primary gradient, KasirFree summary style.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.primary.withValues(alpha: 0.72)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('totalBalance'),
                  style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 6),
                Text(
                  fmtMoney(state.total, lang: state.lang, currencyCode: state.currencyCode),
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _miniStatOnPrimary(
                      context,
                      '↓ ${s.t('cashIn')} • ${s.t('thisMonth')}',
                      fmtMoney(monthIn, lang: state.lang, currencyCode: state.currencyCode),
                    ),
                    const SizedBox(width: 20),
                    _miniStatOnPrimary(
                      context,
                      '↑ ${s.t('cashOut')} • ${s.t('thisMonth')}',
                      fmtMoney(monthOut, lang: state.lang, currencyCode: state.currencyCode),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (state.budgetAlerts.isNotEmpty) ...[
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BudgetsScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        size: 17, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${s.t('budgetAlmost')}: '
                        '${state.budgetAlerts.map((b) => '${b.category} ${(budgetFraction(state.budgetSpent[b.category] ?? 0, b.limitAmount) * 100).toStringAsFixed(0)}%').join(' • ')}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 17),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          Row(
            children: [
              Text(
                s.t('books'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _accountDialog(context, state),
                icon: const Icon(Icons.add, size: 18),
                label: Text(s.t('addBook')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...state.accounts.map((a) => _accountCard(context, state, a)),
          if (state.accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text(s.t('emptyEntries'))),
            ),
        ],
      ),
    );
  }

  String _greeting(AppState state) {
    final h = DateTime.now().hour;
    if (h < 12) return state.s.t('greetMorning');
    if (h < 15) return state.s.t('greetNoon');
    if (h < 19) return state.s.t('greetEvening');
    return state.s.t('greetNight');
  }

  IconData _greetingIcon() {
    final h = DateTime.now().hour;
    if (h < 12) return Icons.wb_sunny_outlined;
    if (h < 15) return Icons.brightness_7_outlined;
    if (h < 19) return Icons.brightness_5_outlined;
    return Icons.dark_mode_outlined;
  }

  Widget _miniStatOnPrimary(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.8), fontSize: 11),
        ),
        Text(
          value,
          style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ],
    );
  }

  Widget _accountCard(BuildContext context, AppState state, Account a) {
    final balance = state.balances[a.id] ?? 0;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Color(a.colorValue).withValues(alpha: 0.15),
          child: Text(a.icon, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
        subtitle: Text(
          '${state.s.t('balance')}: ${fmtMoney(balance, lang: state.lang, currencyCode: state.currencyCode)}',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_horiz, color: scheme.onSurfaceVariant),
          onSelected: (v) {
            if (v == 'edit') _accountDialog(context, state, existing: a);
            if (v == 'delete') _confirmArchive(context, state, a);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text(state.s.t('edit'))),
            PopupMenuItem(value: 'delete', child: Text(state.s.t('deleteBook'))),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookScreen(account: a)),
        ),
      ),
    );
  }

  Future<void> _confirmArchive(BuildContext context, AppState state, Account a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(state.s.t('deleteBookConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(state.s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(state.s.t('deleteBook'))),
        ],
      ),
    );
    if (ok == true) await state.archiveAccount(a);
  }

  Future<void> _accountDialog(BuildContext context, AppState state, {Account? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final iconCtrl = TextEditingController(text: existing?.icon ?? '💰');
    var color = existing?.colorValue ?? 0xFF0E7C66;
    const palette = [
      0xFF0E7C66, 0xFF1565C0, 0xFF6A1B9A, 0xFFAD1457,
      0xFFEF6C00, 0xFF2E7D32, 0xFF00838F, 0xFF4E342E,
    ];
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? state.s.t('addBook') : state.s.t('editBook')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: state.s.t('bookName')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: iconCtrl,
                decoration: InputDecoration(labelText: state.s.t('bookIcon')),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: palette.map((c) {
                  final selected = c == color;
                  return GestureDetector(
                    onTap: () => setLocal(() => color = c),
                    child: CircleAvatar(
                      radius: selected ? 16 : 13,
                      backgroundColor: Color(c),
                      child: selected
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(state.s.t('cancel'))),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final icon = iconCtrl.text.trim().isEmpty ? '💰' : iconCtrl.text.trim();
                if (existing == null) {
                  await state.addAccount(name, icon, color);
                } else {
                  await state.renameAccount(existing, name, icon, color);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(state.s.t('save')),
            ),
          ],
        ),
      ),
    );
  }
}
