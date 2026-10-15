import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

/// One transaction row showing amount and the running balance after it.
class EntryTile extends StatelessWidget {
  final EntryWithBalance item;
  final AppState state;
  final VoidCallback? onTap;

  const EntryTile({super.key, required this.item, required this.state, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = item.entry;
    final income = e.isIncome;
    final title = e.notes.isNotEmpty
        ? e.notes
        : (e.category.isNotEmpty ? e.category : e.description);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).dividerTheme.color!),
        ),
        child: Icon(
          e.isTransfer
              ? Icons.swap_horiz
              : (income ? Icons.arrow_downward : Icons.arrow_upward),
          color: income ? scheme.primary : scheme.onSurfaceVariant,
          size: 17,
        ),
      ),
      title: Text(
        title.isEmpty ? '—' : title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (e.category.isNotEmpty && e.notes.isNotEmpty) e.category,
          fmtDate(e.date, lang: state.lang, withTime: true),
        ].join(' • '),
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            fmtMoneySigned(e.signed, lang: state.lang, currencyCode: state.currencyCode),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
              color: income ? scheme.primary : scheme.onSurface,
            ),
          ),
          Text(
            fmtMoney(item.balanceAfter, lang: state.lang, currencyCode: state.currencyCode),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
