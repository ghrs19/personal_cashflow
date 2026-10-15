import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/calc.dart';
import '../utils/format.dart';

class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final receivables = state.debts.where((d) => d.isReceivable).toList();
    final payables = state.debts.where((d) => !d.isReceivable).toList();
    return Scaffold(
      appBar: AppBar(title: Text(s.t('debts'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _sectionHeader(context, s.t('receivable')),
          if (receivables.isEmpty)
            _empty(context, s.t('noDebts'))
          else
            ...receivables.map((d) => _debtRow(context, state, d)),
          const SizedBox(height: 20),
          _sectionHeader(context, s.t('payable')),
          if (payables.isEmpty)
            _empty(context, s.t('noDebts'))
          else
            ...payables.map((d) => _debtRow(context, state, d)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDebtEditor(context),
        icon: const Icon(Icons.add),
        label: Text(s.t('addDebt')),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4, top: 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );

  Widget _empty(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          text,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );

  Widget _debtRow(BuildContext context, AppState state, Debt d) {
    final scheme = Theme.of(context).colorScheme;
    final s = state.s;
    final remaining = state.debtRemainingOf(d);
    final paid = d.amount - remaining;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerTheme.color!)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        title: Text(
          d.person,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: d.settled ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          [
            '${s.t('remaining')}: ${fmtMoney(remaining, lang: state.lang, currencyCode: state.currencyCode)}'
                ' / ${fmtMoney(d.amount, lang: state.lang, currencyCode: state.currencyCode)}',
            if (paid > 0)
              '${s.t('paidAmount')}: ${fmtMoney(paid, lang: state.lang, currencyCode: state.currencyCode)}',
            if (d.dueDate != null)
              '${s.t('dueDate')}: ${fmtDateShort(d.dueDate!, lang: state.lang)}',
            if (d.settled) s.t('settled'),
          ].join('\n'),
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DebtDetailScreen(debtId: d.id!)),
        ),
      ),
    );
  }
}

Future<void> showDebtEditor(BuildContext context, {Debt? existing}) async {
  final state = context.read<AppState>();
  final s = state.s;
  final personCtrl = TextEditingController(text: existing?.person ?? '');
  final amountCtrl = TextEditingController(
    text: existing != null ? groupNumber(existing.amount, idLocale: state.isId) : '',
  );
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  var isReceivable = existing?.isReceivable ?? true;
  DateTime? dueDate = existing?.dueDate;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(existing == null ? s.t('addDebt') : s.t('editDebt')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text(s.t('receivable'))),
                  ButtonSegment(value: false, label: Text(s.t('payable'))),
                ],
                selected: {isReceivable},
                onSelectionChanged: (v) => setLocal(() => isReceivable = v.first),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: personCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: s.t('person')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: s.t('amount')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(labelText: s.t('notes')),
              ),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.t('dueDate')),
                subtitle: Text(dueDate == null ? '—' : fmtDate(dueDate!, lang: state.lang)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: dueDate ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setLocal(() => dueDate = d);
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
              if (personCtrl.text.trim().isEmpty || amount == null || amount <= 0) return;
              await state.saveDebt(
                Debt(
                  id: existing?.id,
                  person: personCtrl.text.trim(),
                  isReceivable: isReceivable,
                  amount: amount,
                  notes: notesCtrl.text.trim(),
                  createdDate: existing?.createdDate ?? DateTime.now(),
                  dueDate: dueDate,
                  settled: existing?.settled ?? false,
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

class DebtDetailScreen extends StatefulWidget {
  final int debtId;
  const DebtDetailScreen({super.key, required this.debtId});

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  List<DebtPayment> _payments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final payments = await state.repo.getDebtPayments(widget.debtId);
    if (!mounted) return;
    setState(() => _payments = payments);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final scheme = Theme.of(context).colorScheme;
    Debt? debt;
    for (final d in state.debts) {
      if (d.id == widget.debtId) debt = d;
    }
    if (debt == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.t('debts'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final d = debt;
    final remaining = state.debtRemainingOf(d);
    return Scaffold(
      appBar: AppBar(
        title: Text(d.person),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              final navigator = Navigator.of(context);
              if (v == 'edit') {
                await showDebtEditor(context, existing: d);
              } else if (v == 'settled') {
                await state.setDebtSettled(d, !d.settled);
              } else if (v == 'delete') {
                await state.removeDebt(d);
                navigator.pop();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(s.t('edit'))),
              PopupMenuItem(
                value: 'settled',
                child: Text(d.settled ? s.t('markUnsettled') : s.t('markSettled')),
              ),
              PopupMenuItem(value: 'delete', child: Text(s.t('delete'))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            d.isReceivable ? s.t('receivable') : s.t('payable'),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          Text(
            fmtMoney(remaining, lang: state.lang, currencyCode: state.currencyCode),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w300, letterSpacing: -0.6),
          ),
          const SizedBox(height: 4),
          Text(
            '${s.t('remaining')} • ${s.t('total')}: ${fmtMoney(d.amount, lang: state.lang, currencyCode: state.currencyCode)}',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (d.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(d.notes),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: d.settled ? null : () => _paymentDialog(context, d),
            icon: const Icon(Icons.payments_outlined),
            label: Text(s.t('recordPayment')),
          ),
          const SizedBox(height: 22),
          Text(
            s.t('paymentHistory'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (_payments.isEmpty)
            Text(s.t('noteEmpty'), style: TextStyle(color: scheme.onSurfaceVariant)),
          ..._payments.map(
            (p) => Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerTheme.color!)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(fmtMoney(p.amount, lang: state.lang, currencyCode: state.currencyCode)),
                subtitle: Text(
                  [
                    fmtDate(p.date, lang: state.lang),
                    if (p.note.isNotEmpty) p.note,
                  ].join(' • '),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () async {
                    await state.removeDebtPayment(p);
                    await _load();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _paymentDialog(BuildContext context, Debt d) async {
    final state = context.read<AppState>();
    final s = state.s;
    final ctrl = TextEditingController();
    final noteCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('recordPayment')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: s.t('amount')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(labelText: s.t('notes')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('cancel'))),
          FilledButton(
            onPressed: () async {
              final v = parseAmount(ctrl.text, idLocale: state.isId);
              if (v == null || v <= 0) return;
              await state.addDebtPayment(
                DebtPayment(
                  debtId: d.id!,
                  amount: v,
                  date: DateTime.now(),
                  note: noteCtrl.text.trim(),
                ),
              );
              // Auto-settle when fully paid.
              final updated = state.debtRemainingOf(d);
              if (updated <= 0 && !d.settled) {
                await state.setDebtSettled(d, true);
              }
              await _load();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(s.t('save')),
          ),
        ],
      ),
    );
  }
}
