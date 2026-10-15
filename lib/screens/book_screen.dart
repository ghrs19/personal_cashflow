import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/entry_tile.dart';
import 'entry_editor_screen.dart';

enum _Filter { all, income, expense }

class BookScreen extends StatefulWidget {
  final Account account;
  const BookScreen({super.key, required this.account});

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  List<EntryWithBalance> _items = [];
  bool _loading = true;
  String _query = '';
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final items = await state.entriesFor(widget.account.id!);
    if (!mounted) return;
    setState(() {
      // newest first for display; balance stays attached per entry.
      _items = items.reversed.toList();
      _loading = false;
    });
  }

  List<EntryWithBalance> get _visible {
    return _items.where((it) {
      final e = it.entry;
      if (_filter == _Filter.income && !e.isIncome) return false;
      if (_filter == _Filter.expense && e.isIncome) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final hay = '${e.notes} ${e.description} ${e.category}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final balance = state.balances[widget.account.id] ?? 0;
    final visible = _visible;

    // group by day
    final groups = <String, List<EntryWithBalance>>{};
    for (final it in visible) {
      groups.putIfAbsent(fmtDayKey(it.entry.date), () => []).add(it);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.account.icon} ${widget.account.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: s.t('addEntry'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EntryEditorScreen(accountId: widget.account.id!),
              ),
            ).then((_) => _load()),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: s.t('transfer'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EntryEditorScreen(
                  accountId: widget.account.id!,
                  startAsTransfer: true,
                ),
              ),
            ).then((_) => _load()),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.72),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('balance'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
                Text(
                  fmtMoney(balance, lang: state.lang, currencyCode: state.currencyCode),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: s.t('search'),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _chip(s.t('all'), _Filter.all),
                const SizedBox(width: 8),
                _chip(s.t('income'), _Filter.income),
                const SizedBox(width: 8),
                _chip(s.t('expense'), _Filter.expense),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                    ? Center(
                        child: Text(
                          s.t('emptyEntries'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView(
                        children: groups.entries.map((g) {
                          final dayItems = g.value;
                          final dayNet = dayItems.fold<double>(
                            0,
                            (sum, it) => sum + it.entry.signed,
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                                child: Row(
                                  children: [
                                    Text(
                                      fmtDateShort(dayItems.first.entry.date, lang: state.lang),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        letterSpacing: 0.6,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      fmtMoneySigned(dayNet, lang: state.lang, currencyCode: state.currencyCode),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  for (var i = 0; i < dayItems.length; i++) ...[
                                    EntryTile(
                                      item: dayItems[i],
                                      state: state,
                                      onTap: () => _openActions(dayItems[i].entry),
                                    ),
                                    if (i < dayItems.length - 1)
                                      const Divider(indent: 70, endIndent: 16),
                                  ],
                                ],
                              ),
                            ],
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _Filter f) {
    final selected = _filter == f;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = f),
    );
  }

  Future<void> _openActions(CashEntry entry) async {
    final state = context.read<AppState>();
    final s = state.s;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(s.t('edit')),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EntryEditorScreen(
                      accountId: widget.account.id!,
                      existing: entry,
                    ),
                  ),
                ).then((_) => _load());
              },
            ),
            if (!entry.isTransfer) ...[
              ListTile(
                leading: const Icon(Icons.content_copy_outlined),
                title: Text(s.t('duplicate')),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EntryEditorScreen(
                        accountId: widget.account.id!,
                        prefill: entry,
                      ),
                    ),
                  ).then((_) => _load());
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: Text(s.t('saveAsTemplate')),
                onTap: () async {
                  Navigator.pop(ctx);
                  final name = entry.notes.isNotEmpty
                      ? entry.notes
                      : entry.category;
                  await state.saveTemplate(
                    EntryTemplate(
                      name: name.isEmpty ? s.t('templates') : name,
                      accountId: entry.accountId,
                      isIncome: entry.isIncome,
                      amount: entry.amount,
                      category: entry.category,
                      notes: entry.notes,
                    ),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(s.t('saved'))),
                    );
                  }
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(s.t('delete')),
              onTap: () async {
                Navigator.pop(ctx);
                await state.deleteEntry(entry);
                await _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s.t('movedToBin'))),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
