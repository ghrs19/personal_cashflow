import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/calc.dart';
import '../utils/format.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final scheme = Theme.of(context).colorScheme;
    final budgets = state.budgets;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('budgets'))),
      body: budgets.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  s.t('noBudgets'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: budgets.map((b) {
                final spent = state.budgetSpent[b.category] ?? 0;
                final frac = budgetFraction(spent, b.limitAmount);
                final over = spent > b.limitAmount;
                final warn = !over && frac >= 0.8;
                final barColor = over
                    ? scheme.error
                    : (warn ? Colors.orange.shade700 : scheme.primary);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            b.category,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          const Spacer(),
                          Text(
                            '${fmtMoney(spent, lang: state.lang, currencyCode: state.currencyCode)}'
                            ' / ${fmtMoney(b.limitAmount, lang: state.lang, currencyCode: state.currencyCode)}',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_horiz, size: 20, color: scheme.onSurfaceVariant),
                            onSelected: (v) {
                              if (v == 'edit') _budgetDialog(context, existing: b);
                              if (v == 'delete') state.removeBudget(b);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'edit', child: Text(s.t('edit'))),
                              PopupMenuItem(value: 'delete', child: Text(s.t('delete'))),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: frac.clamp(0.0, 1.0),
                          minHeight: 7,
                          backgroundColor: scheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(barColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        over
                            ? '${s.t('overBudget')}: ${fmtMoney(spent - b.limitAmount, lang: state.lang, currencyCode: state.currencyCode)}'
                            : '${s.t('remaining')}: ${fmtMoney(b.limitAmount - spent, lang: state.lang, currencyCode: state.currencyCode)}'
                                ' • ${(frac * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: over ? scheme.error : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _budgetDialog(context),
        icon: const Icon(Icons.add),
        label: Text(s.t('addBudget')),
      ),
    );
  }

  Future<void> _budgetDialog(BuildContext context, {Budget? existing}) async {
    final state = context.read<AppState>();
    final s = state.s;
    final expenseCats = await state.repo.getCategories(income: false);
    if (!context.mounted) return;
    final used = state.budgets.map((b) => b.category).toSet();
    final available = expenseCats
        .map((c) => c.name)
        .where((n) => existing?.category == n || !used.contains(n))
        .toList();
    var category = existing?.category ?? (available.isNotEmpty ? available.first : null);
    final limitCtrl = TextEditingController(
      text: existing != null ? groupNumber(existing.limitAmount, idLocale: state.isId) : '',
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? s.t('addBudget') : s.t('edit')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: InputDecoration(labelText: s.t('category')),
                items: available
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setLocal(() => category = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: limitCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: s.t('monthlyLimit')),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('cancel'))),
            FilledButton(
              onPressed: () async {
                final limit = parseAmount(limitCtrl.text, idLocale: state.isId);
                if (category == null || limit == null || limit <= 0) return;
                await state.saveBudget(
                  Budget(id: existing?.id, category: category!, limitAmount: limit),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(s.t('save')),
            ),
          ],
        ),
      ),
    );
  }
}
