import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/calc.dart';
import '../utils/format.dart';

/// Physical cash counter: how many notes/coins of each denomination,
/// with a live total — counts actual cash against the book balance.
class DenominationsScreen extends StatefulWidget {
  const DenominationsScreen({super.key});

  @override
  State<DenominationsScreen> createState() => _DenominationsScreenState();
}

class _DenominationsScreenState extends State<DenominationsScreen> {
  List<Denomination> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final items = await state.repo.getDenominations(state.currencyCode);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _setCount(Denomination d, int count) async {
    if (count < 0) count = 0;
    await context.read<AppState>().repo.setDenominationCount(d.id!, count);
    setState(() {
      _items = _items.map((x) => x.id == d.id ? x.copyWith(count: count) : x).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final total = denominationTotal(_items);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('denominations')),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: s.t('reset'),
            onPressed: () async {
              await state.repo.resetDenominationCounts(state.currencyCode);
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${s.t('total')} • ${state.currencyCode}',
                          style: const TextStyle(fontSize: 12)),
                      Text(
                        fmtMoney(total, lang: state.lang, currencyCode: state.currencyCode),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final d = _items[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fmtMoney(d.denomination, lang: state.lang, currencyCode: state.currencyCode),
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                    Text(
                                      fmtMoney(d.subtotal, lang: state.lang, currencyCode: state.currencyCode),
                                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => _setCount(d, d.count - 1),
                              ),
                              SizedBox(
                                width: 44,
                                child: Text(
                                  '${d.count}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => _setCount(d, d.count + 1),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () async {
                                  await state.repo.deleteDenomination(d.id!);
                                  _load();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDialog,
        icon: const Icon(Icons.add),
        label: Text(s.t('addDenomination')),
      ),
    );
  }

  Future<void> _addDialog() async {
    final state = context.read<AppState>();
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(state.s.t('addDenomination')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: state.s.t('denominationValue')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(state.s.t('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(state.s.t('save')),
          ),
        ],
      ),
    );
    final parsed = value == null ? null : parseAmount(value, idLocale: state.isId);
    if (parsed == null || parsed <= 0) return;
    await state.repo.insertDenomination(
      Denomination(denomination: parsed, currency: state.currencyCode),
    );
    _load();
  }
}
