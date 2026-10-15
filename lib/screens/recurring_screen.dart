import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/calc.dart';
import '../utils/format.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  String _freqLabel(AppState state, String f) => switch (f) {
        'weekly' => state.s.t('freqWeekly'),
        'yearly' => state.s.t('freqYearly'),
        _ => state.s.t('freqMonthly'),
      };

  String _accountName(AppState state, int id) {
    for (final a in state.accounts) {
      if (a.id == id) return '${a.icon} ${a.name}';
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final scheme = Theme.of(context).colorScheme;
    final rules = state.recurringRules;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('recurring'))),
      body: rules.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  s.t('noRecurring'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: rules.map((r) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Theme.of(context).dividerTheme.color!),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).dividerTheme.color!),
                      ),
                      child: Icon(
                        r.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 17,
                        color: r.isIncome ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(
                      r.notes.isNotEmpty ? r.notes : r.category,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      [
                        _accountName(state, r.accountId),
                        _freqLabel(state, r.frequency),
                        if (!r.active) s.t('pausedLabel'),
                        if (r.active)
                          '${s.t('nextRun')}: ${fmtDateShort(r.nextRun, lang: state.lang)}',
                      ].join(' • '),
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          fmtMoney(r.amount, lang: state.lang, currencyCode: state.currencyCode),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: r.isIncome ? scheme.primary : scheme.onSurface,
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_horiz, color: scheme.onSurfaceVariant),
                          onSelected: (v) async {
                            if (v == 'edit') {
                              await showRecurringEditor(context, existing: r);
                            } else if (v == 'toggle') {
                              await state.toggleRecurringRule(r);
                            } else if (v == 'delete') {
                              await state.deleteRecurringRule(r);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Text(s.t('edit'))),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(r.active ? s.t('pausedLabel') : s.t('nextRun')),
                            ),
                            PopupMenuItem(value: 'delete', child: Text(s.t('delete'))),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRecurringEditor(context),
        icon: const Icon(Icons.add),
        label: Text(s.t('addRecurring')),
      ),
    );
  }
}

Future<void> showRecurringEditor(BuildContext context, {RecurringRule? existing}) async {
  final state = context.read<AppState>();
  final s = state.s;
  final amountCtrl = TextEditingController(
    text: existing != null ? groupNumber(existing.amount, idLocale: state.isId) : '',
  );
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  var isIncome = existing?.isIncome ?? false;
  var accountId = existing?.accountId ??
      (state.accounts.isNotEmpty ? state.accounts.first.id : null);
  var frequency = existing?.frequency ?? 'monthly';
  var startDate = existing?.startDate ?? DateTime.now();
  String? category = existing?.category;
  final categories = await state.repo.getCategories(income: isIncome);
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final catNames = categories.map((c) => c.name).toList();
        if (category != null && !catNames.contains(category)) category = null;
        return AlertDialog(
          title: Text(existing == null ? s.t('addRecurring') : s.t('editRecurring')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: true, label: Text(s.t('income'))),
                    ButtonSegment(value: false, label: Text(s.t('expense'))),
                  ],
                  selected: {isIncome},
                  onSelectionChanged: (v) async {
                    setLocal(() => isIncome = v.first);
                    final cats = await state.repo.getCategories(income: v.first);
                    setLocal(() {
                      categories
                        ..clear()
                        ..addAll(cats);
                      category = null;
                    });
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: s.t('amount')),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: accountId,
                  decoration: InputDecoration(labelText: s.t('books')),
                  items: state.accounts
                      .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.icon} ${a.name}')))
                      .toList(),
                  onChanged: (v) => setLocal(() => accountId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(labelText: s.t('category')),
                  items: catNames
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setLocal(() => category = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(labelText: s.t('notes')),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: frequency,
                  decoration: InputDecoration(labelText: s.t('frequency')),
                  items: [
                    DropdownMenuItem(value: 'weekly', child: Text(s.t('freqWeekly'))),
                    DropdownMenuItem(value: 'monthly', child: Text(s.t('freqMonthly'))),
                    DropdownMenuItem(value: 'yearly', child: Text(s.t('freqYearly'))),
                  ],
                  onChanged: (v) => setLocal(() => frequency = v ?? 'monthly'),
                ),
                const SizedBox(height: 4),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.t('startDate')),
                  subtitle: Text(fmtDate(startDate, lang: state.lang)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: startDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setLocal(() => startDate = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('cancel'))),
            FilledButton(
              onPressed: () async {
                final amount = parseAmount(amountCtrl.text, idLocale: state.isId);
                if (amount == null || amount <= 0 || accountId == null) return;
                final start = DateTime(startDate.year, startDate.month, startDate.day);
                final rule = RecurringRule(
                  id: existing?.id,
                  accountId: accountId!,
                  isIncome: isIncome,
                  amount: amount,
                  category: category ?? '',
                  notes: notesCtrl.text.trim(),
                  frequency: frequency,
                  startDate: start,
                  nextRun: existing?.nextRun ?? start,
                  active: existing?.active ?? true,
                );
                await state.saveRecurringRule(rule);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(s.t('save')),
            ),
          ],
        );
      },
    ),
  );
}
