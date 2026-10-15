import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  List<CashEntry> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await context.read<AppState>().repo.getDeletedEntries();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final accountNames = {for (final a in state.accounts) a.id: a.name};
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('recycleBin')),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever_outlined),
              tooltip: s.t('emptyBin'),
              onPressed: _confirmEmpty,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(child: Text(s.t('binEmpty')))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _items.length,
                  itemBuilder: (ctx, i) {
                    final e = _items[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          e.notes.isNotEmpty ? e.notes : e.category,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${accountNames[e.accountId] ?? ''} • '
                          '${fmtDateShort(e.date, lang: state.lang)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              fmtMoneySigned(e.signed, lang: state.lang, currencyCode: state.currencyCode),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            IconButton(
                              icon: const Icon(Icons.restore_from_trash_outlined),
                              tooltip: s.t('restore'),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                await state.repo.restoreEntry(e);
                                await state.reload();
                                _load();
                                messenger.showSnackBar(
                                  SnackBar(content: Text(s.t('restored'))),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever_outlined),
                              tooltip: s.t('deleteForever'),
                              onPressed: () async {
                                await state.repo.purgeEntry(e.id!);
                                _load();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _confirmEmpty() async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(state.s.t('emptyBinConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(state.s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(state.s.t('emptyBin'))),
        ],
      ),
    );
    if (ok == true) {
      await state.repo.emptyRecycleBin();
      await state.reload();
      _load();
    }
  }
}
