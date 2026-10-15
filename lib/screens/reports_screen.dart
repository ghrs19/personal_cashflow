import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../services/pdf_service.dart';
import '../state/app_state.dart';
import '../utils/calc.dart';
import '../utils/format.dart';
import '../widgets/bar_chart.dart';

enum _Period { week, month, year }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _Period _period = _Period.month;
  List<CashEntry> _entries = [];
  bool _loading = true;
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _setRange();
    _load();
  }

  void _setRange() {
    final now = DateTime.now();
    switch (_period) {
      case _Period.week:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        _from = DateTime(monday.year, monday.month, monday.day);
        _to = _from.add(const Duration(days: 7));
      case _Period.month:
        _from = DateTime(now.year, now.month, 1);
        _to = DateTime(now.year, now.month + 1, 1);
      case _Period.year:
        _from = DateTime(now.year, 1, 1);
        _to = DateTime(now.year + 1, 1, 1);
    }
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final entries = await state.repo.getAllEntries(from: _from, to: _to);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  void _changePeriod(_Period p) {
    setState(() {
      _period = p;
      _loading = true;
    });
    _setRange();
    _load();
  }

  List<({String label, double cashIn, double cashOut})> _chartData(AppState state) {
    if (_period == _Period.year) {
      return List.generate(12, (i) {
        final m = i + 1;
        final inM = _entries.where((e) => e.date.month == m);
        return (
          label: fmtMonth(DateTime(_from.year, m), lang: state.lang).substring(0, 3),
          cashIn: sumIncome(inM),
          cashOut: sumExpense(inM),
        );
      });
    }
    final days = totalsByDay(_entries);
    final count = _period == _Period.week ? 7 : DateTime(_from.year, _from.month + 1, 0).day;
    return List.generate(count, (i) {
      final day = _from.add(Duration(days: i));
      final t = days[DateTime(day.year, day.month, day.day)];
      return (
        label: _period == _Period.week
            ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i]
            : '${day.day}',
        cashIn: t?.cashIn ?? 0,
        cashOut: t?.cashOut ?? 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final regular = _entries.where((e) => !e.isTransfer).toList();
    final totalIn = sumIncome(regular);
    final totalOut = sumExpense(regular);
    final byCatOut = totalsByCategory(regular, income: false);
    final byCatIn = totalsByCategory(regular, income: true);
    final accountNames = {for (final a in state.accounts) a.id!: a.name};

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('reports')),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: s.t('exportPdf'),
            onPressed: _entries.isEmpty ? null : () => _exportPdf(state, accountNames),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                SegmentedButton<_Period>(
                  segments: [
                    ButtonSegment(value: _Period.week, label: Text(s.t('week'))),
                    ButtonSegment(value: _Period.month, label: Text(s.t('month'))),
                    ButtonSegment(value: _Period.year, label: Text(s.t('year'))),
                  ],
                  selected: {_period},
                  onSelectionChanged: (v) => _changePeriod(v.first),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _totalStat(context, s.t('cashIn'), totalIn, accent: true),
                    _vRule(context),
                    _totalStat(context, s.t('cashOut'), totalOut),
                    _vRule(context),
                    _totalStat(context, s.t('net'), totalIn - totalOut),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionTitle(context, s.t('dailyFlow')),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FlowBarChart(
                      data: _chartData(state),
                      inLabel: s.t('cashIn'),
                      outLabel: s.t('cashOut'),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _sectionTitle(context, '${s.t('byCategory')} • ${s.t('cashOut')}'),
                _categoryCard(context, state, byCatOut, totalOut),
                const SizedBox(height: 12),
                _sectionTitle(context, '${s.t('byCategory')} • ${s.t('cashIn')}'),
                _categoryCard(context, state, byCatIn, totalIn),
                const SizedBox(height: 20),
                _sectionTitle(context, s.t('calendar')),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _calendarGrid(state),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _vRule(BuildContext context) => Container(
        width: 1,
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 14),
        color: Theme.of(context).dividerTheme.color,
      );

  Widget _totalStat(BuildContext context, String label, double v, {bool accent = false}) {
    final state = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
              color: accent ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              fmtMoney(v, lang: state.lang, currencyCode: state.currencyCode),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
        ),
      );

  Widget _categoryCard(
    BuildContext context,
    AppState state,
    Map<String, double> data,
    double total,
  ) {
    if (data.isEmpty || total <= 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(state.s.t('noCategoryData')),
        ),
      );
    }
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: entries.map((e) {
            final pct = e.value / total;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(e.key.isEmpty ? '—' : e.key)),
                      Text(
                        fmtMoney(e.value, lang: state.lang, currencyCode: state.currencyCode),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Text('${(pct * 100).toStringAsFixed(0)}%',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 7,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Month calendar with a dot per day coloured by net direction.
  Widget _calendarGrid(AppState state) {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final leading = first.weekday - 1; // Monday-first
    final byDay = totalsByDay(_entries);
    final scheme = Theme.of(context).colorScheme;
    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(now.year, now.month, d);
      final t = byDay[day];
      final net = (t?.cashIn ?? 0) - (t?.cashOut ?? 0);
      final has = t != null;
      cells.add(
        Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: d == now.day ? scheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$d', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: !has
                      ? Colors.transparent
                      : (net >= 0 ? scheme.primary : scheme.error),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Text(fmtMonth(now, lang: state.lang),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cells,
        ),
      ],
    );
  }

  Future<void> _exportPdf(AppState state, Map<int, String> accountNames) async {
    final s = state.s;
    final file = await PdfService.buildReport(
      title: s.t('appName'),
      periodLabel: '${fmtDateShort(_from, lang: state.lang)} — ${fmtDateShort(_to.subtract(const Duration(days: 1)), lang: state.lang)}',
      entries: _entries,
      accountNames: accountNames,
      lang: state.lang,
      currencyCode: state.currencyCode,
      inLabel: s.t('cashIn'),
      outLabel: s.t('cashOut'),
      totalLabel: s.t('net'),
    );
    await Share.shareXFiles([XFile(file.path)]);
  }
}
