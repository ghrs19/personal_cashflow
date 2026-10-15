import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/calc.dart';
import '../utils/format.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final scheme = Theme.of(context).colorScheme;
    final goals = state.goals;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('goals'))),
      body: goals.isEmpty
          ? Center(
              child: Text(
                s.t('noGoals'),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: goals.map((g) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(g.icon, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    g.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5),
                                  ),
                                  if (g.deadline != null)
                                    Text(
                                      '${s.t('deadline')}: ${fmtDateShort(g.deadline!, lang: state.lang)}',
                                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 52,
                              height: 52,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: g.progress,
                                    strokeWidth: 5,
                                    backgroundColor: scheme.surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation(scheme.primary),
                                  ),
                                  Text(
                                    '${(g.progress * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_horiz, color: scheme.onSurfaceVariant),
                              onSelected: (v) {
                                if (v == 'edit') _goalDialog(context, existing: g);
                                if (v == 'delete') state.removeGoal(g);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'edit', child: Text(s.t('edit'))),
                                PopupMenuItem(value: 'delete', child: Text(s.t('delete'))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${fmtMoney(g.currentAmount, lang: state.lang, currencyCode: state.currencyCode)}'
                          ' / ${fmtMoney(g.targetAmount, lang: state.lang, currencyCode: state.currencyCode)}',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                        ),
                        if (g.reached)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '🎉 ${s.t('goalReached')}',
                              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _adjustDialog(context, g, positive: false),
                              icon: const Icon(Icons.remove, size: 16),
                              label: Text(s.t('withdrawSaving')),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () => _adjustDialog(context, g, positive: true),
                              icon: const Icon(Icons.add, size: 16),
                              label: Text(s.t('addSaving')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _goalDialog(context),
        icon: const Icon(Icons.add),
        label: Text(s.t('addGoal')),
      ),
    );
  }

  Future<void> _adjustDialog(BuildContext context, SavingsGoal g, {required bool positive}) async {
    final state = context.read<AppState>();
    final s = state.s;
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(positive ? s.t('addSaving') : s.t('withdrawSaving')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: s.t('amount')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('cancel'))),
          FilledButton(
            onPressed: () async {
              final v = parseAmount(ctrl.text, idLocale: state.isId);
              if (v == null || v <= 0) return;
              await state.adjustGoal(g, positive ? v : -v);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(s.t('save')),
          ),
        ],
      ),
    );
  }

  Future<void> _goalDialog(BuildContext context, {SavingsGoal? existing}) async {
    final state = context.read<AppState>();
    final s = state.s;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final iconCtrl = TextEditingController(text: existing?.icon ?? '🎯');
    final targetCtrl = TextEditingController(
      text: existing != null ? groupNumber(existing.targetAmount, idLocale: state.isId) : '',
    );
    DateTime? deadline = existing?.deadline;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? s.t('addGoal') : s.t('editGoal')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: s.t('goalName')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: iconCtrl,
                decoration: InputDecoration(labelText: s.t('bookIcon')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: s.t('targetAmount')),
              ),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.t('deadline')),
                subtitle: Text(
                  deadline == null ? '—' : fmtDate(deadline!, lang: state.lang),
                ),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: deadline ?? DateTime.now().add(const Duration(days: 90)),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setLocal(() => deadline = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('cancel'))),
            FilledButton(
              onPressed: () async {
                final target = parseAmount(targetCtrl.text, idLocale: state.isId);
                if (nameCtrl.text.trim().isEmpty || target == null || target <= 0) return;
                await state.saveGoal(
                  SavingsGoal(
                    id: existing?.id,
                    name: nameCtrl.text.trim(),
                    icon: iconCtrl.text.trim().isEmpty ? '🎯' : iconCtrl.text.trim(),
                    targetAmount: target,
                    currentAmount: existing?.currentAmount ?? 0,
                    deadline: deadline,
                  ),
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
