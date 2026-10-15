import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/calc.dart';
import '../utils/format.dart';

enum _Mode { income, expense, transfer }

class EntryEditorScreen extends StatefulWidget {
  final int accountId;
  final CashEntry? existing;

  /// Values copied from another entry (duplicate / template apply at the
  /// call site). The saved entry is always a brand-new one.
  final CashEntry? prefill;
  final bool startAsTransfer;

  const EntryEditorScreen({
    super.key,
    required this.accountId,
    this.existing,
    this.prefill,
    this.startAsTransfer = false,
  });

  @override
  State<EntryEditorScreen> createState() => _EntryEditorScreenState();
}

class _EntryEditorScreenState extends State<EntryEditorScreen> {
  _Mode _mode = _Mode.expense;
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String? _category;
  List<CategoryItem> _categories = [];
  List<String> _bills = [];
  int? _fromId;
  int? _toId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fromId = widget.accountId;
    final ex = widget.existing;
    if (ex != null) {
      _mode = ex.isTransfer ? _Mode.transfer : (ex.isIncome ? _Mode.income : _Mode.expense);
      _amountCtrl.text = groupNumber(
        ex.amount,
        idLocale: context.read<AppState>().isId,
      );
      _notesCtrl.text = ex.notes;
      _descCtrl.text = ex.description;
      _date = ex.date;
      _category = ex.category.isEmpty ? null : ex.category;
      _bills = [...ex.bills];
      if (ex.transactionType == 1) _fromId = ex.accountId;
      if (ex.transactionType == 2) _toId = ex.accountId;
    } else if (widget.prefill != null) {
      final pf = widget.prefill!;
      _mode = pf.isIncome ? _Mode.income : _Mode.expense;
      _amountCtrl.text = groupNumber(
        pf.amount,
        idLocale: context.read<AppState>().isId,
      );
      _notesCtrl.text = pf.notes;
      _descCtrl.text = pf.description;
      _category = pf.category.isEmpty ? null : pf.category;
    } else if (widget.startAsTransfer) {
      _mode = _Mode.transfer;
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final state = context.read<AppState>();
    final income = await state.repo.getCategories(income: true);
    final expense = await state.repo.getCategories(income: false);
    if (!mounted) return;
    setState(() => _categories = [...income, ...expense]);
  }

  List<String> get _categoryNames {
    final wantIncome = _mode == _Mode.income;
    return _categories.where((c) => c.isIncome == wantIncome).map((c) => c.name).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final scheme = Theme.of(context).colorScheme;
    final editing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? s.t('editEntry') : s.t('addEntry')),
        actions: [
          if (!editing)
            PopupMenuButton<String>(
              icon: const Icon(Icons.bookmark_outline),
              onSelected: (v) {
                if (v == 'apply') _applyTemplateSheet();
                if (v == 'save') _saveAsTemplate();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'apply', child: Text(s.t('applyTemplate'))),
                PopupMenuItem(value: 'save', child: Text(s.t('saveAsTemplate'))),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SegmentedButton<_Mode>(
            segments: [
              ButtonSegment(value: _Mode.income, label: Text(s.t('income')), icon: const Icon(Icons.arrow_downward, size: 18)),
              ButtonSegment(value: _Mode.expense, label: Text(s.t('expense')), icon: const Icon(Icons.arrow_upward, size: 18)),
              ButtonSegment(value: _Mode.transfer, label: Text(s.t('transfer')), icon: const Icon(Icons.swap_horiz, size: 18)),
            ],
            selected: {_mode},
            onSelectionChanged: editing
                ? null
                : (v) => setState(() {
                      _mode = v.first;
                      _category = null;
                    }),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              labelText: s.t('amount'),
              prefixText: '${currencyByCode(state.currencyCode).symbol} ',
            ),
            onChanged: (v) {
              final parsed = parseAmount(v, idLocale: state.isId);
              if (parsed != null) {
                final formatted = groupNumber(parsed, idLocale: state.isId);
                if (formatted != v) {
                  _amountCtrl.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 16),
          if (_mode == _Mode.transfer) ...[
            _accountPicker(
              label: s.t('fromAccount'),
              value: _fromId,
              exclude: _toId,
              onChanged: (v) => setState(() => _fromId = v),
            ),
            const SizedBox(height: 12),
            _accountPicker(
              label: s.t('toAccount'),
              value: _toId,
              exclude: _fromId,
              onChanged: (v) => setState(() => _toId = v),
            ),
            const SizedBox(height: 16),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text(s.t('date')),
            subtitle: Text(fmtDate(_date, lang: state.lang, withTime: true)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickDateTime,
          ),
          if (_mode != _Mode.transfer) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(labelText: s.t('category')),
              items: _categoryNames
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _addCategory,
                icon: const Icon(Icons.add, size: 16),
                label: Text(s.t('addCategory')),
              ),
            ),
          ],
          TextField(
            controller: _notesCtrl,
            decoration: InputDecoration(labelText: s.t('notes')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: InputDecoration(labelText: s.t('description')),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          Text(s.t('billPhotos'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._bills.map((path) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(path), width: 84, height: 84, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          icon: const Icon(Icons.cancel, size: 20),
                          onPressed: () => setState(() => _bills.remove(path)),
                        ),
                      ),
                    ],
                  )),
              if (_bills.length < 3)
                InkWell(
                  onTap: _pickPhoto,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_outlined),
                        Text(s.t('addPhoto'), style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(s.t('save')),
          ),
        ],
      ),
    );
  }

  Widget _accountPicker({
    required String label,
    required int? value,
    required int? exclude,
    required ValueChanged<int?> onChanged,
  }) {
    final state = context.read<AppState>();
    final options = state.accounts.where((a) => a.id != exclude).toList();
    return DropdownButtonFormField<int>(
      initialValue: options.any((a) => a.id == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: options
          .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.icon} ${a.name}')))
          .toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (!mounted) return;
    setState(() {
      _date = DateTime(date.year, date.month, date.day, time?.hour ?? _date.hour, time?.minute ?? _date.minute);
    });
  }

  Future<void> _addCategory() async {
    final state = context.read<AppState>();
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(state.s.t('addCategory')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: state.s.t('categoryName')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(state.s.t('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(state.s.t('save')),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await state.repo.insertCategory(
      CategoryItem(name: name, isIncome: _mode == _Mode.income),
    );
    await _loadCategories();
    setState(() => _category = name);
  }

  Future<void> _pickPhoto() async {
    final state = context.read<AppState>();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(state.s.t('camera')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(state.s.t('gallery')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final billsDir = Directory(p.join(dir.path, 'bills'));
    await billsDir.create(recursive: true);
    final dest = p.join(
      billsDir.path,
      'bill_${DateTime.now().microsecondsSinceEpoch}${p.extension(picked.path)}',
    );
    await File(picked.path).copy(dest);
    if (!mounted) return;
    setState(() => _bills = [..._bills, dest]);
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final s = state.s;
    final amount = parseAmount(_amountCtrl.text, idLocale: state.isId);
    if (amount == null || amount <= 0) {
      _snack(s.t('amountRequired'));
      return;
    }
    setState(() => _saving = true);
    try {
      if (_mode == _Mode.transfer) {
        if (widget.existing != null) {
          // Editing transfers is intentionally not supported (both legs
          // must stay in sync); delete + recreate instead.
          _snack(s.t('operationFailed'));
          return;
        }
        if (_fromId == null || _toId == null || _fromId == _toId) {
          _snack(s.t('sameAccountError'));
          return;
        }
        await state.doTransfer(
          fromId: _fromId!,
          toId: _toId!,
          amount: amount,
          date: _date,
          notes: _notesCtrl.text.trim(),
        );
      } else {
        final entry = CashEntry(
          id: widget.existing?.id,
          accountId: widget.accountId,
          date: _date,
          cashIn: _mode == _Mode.income ? amount : 0,
          cashOut: _mode == _Mode.expense ? amount : 0,
          notes: _notesCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          category: _category ?? '',
          bills: _bills,
        );
        if (widget.existing == null) {
          await state.addEntry(entry);
        } else {
          await state.editEntry(entry);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('saved'))));
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    setState(() => _saving = false);
  }

  Future<void> _applyTemplateSheet() async {
    final state = context.read<AppState>();
    final s = state.s;
    final templates = state.templates;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                s.t('templates'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (templates.isEmpty)
              ListTile(title: Text(s.t('noTemplates'))),
            ...templates.map(
              (t) => ListTile(
                leading: Icon(
                  t.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 19,
                ),
                title: Text(t.name),
                subtitle: Text(
                  '${t.category} • ${fmtMoney(t.amount, lang: state.lang, currencyCode: state.currencyCode)}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 19),
                  onPressed: () async {
                    await state.removeTemplate(t);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _mode = t.isIncome ? _Mode.income : _Mode.expense;
                    _amountCtrl.text =
                        groupNumber(t.amount, idLocale: state.isId);
                    _notesCtrl.text = t.notes;
                    _category = t.category.isEmpty ? null : t.category;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAsTemplate() async {
    final state = context.read<AppState>();
    final s = state.s;
    if (_mode == _Mode.transfer) {
      _snack(s.t('operationFailed'));
      return;
    }
    final amount = parseAmount(_amountCtrl.text, idLocale: state.isId);
    if (amount == null || amount <= 0) {
      _snack(s.t('amountRequired'));
      return;
    }
    final ctrl = TextEditingController(
      text: _notesCtrl.text.trim().isNotEmpty
          ? _notesCtrl.text.trim()
          : (_category ?? ''),
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('saveAsTemplate')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: s.t('templateName')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(s.t('save')),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await state.saveTemplate(
      EntryTemplate(
        name: name,
        accountId: widget.accountId,
        isIncome: _mode == _Mode.income,
        amount: amount,
        category: _category ?? '',
        notes: _notesCtrl.text.trim(),
      ),
    );
    if (mounted) _snack(s.t('saved'));
  }
}
