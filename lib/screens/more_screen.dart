import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'budgets_screen.dart';
import 'debts_screen.dart';
import 'denominations_screen.dart';
import 'goals_screen.dart';
import 'recurring_screen.dart';
import 'recycle_bin_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('more'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _tile(
            context,
            icon: Icons.repeat,
            title: s.t('recurring'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecurringScreen()),
            ),
          ),
          _tile(
            context,
            icon: Icons.account_balance_wallet_outlined,
            title: s.t('budgets'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BudgetsScreen()),
            ),
          ),
          _tile(
            context,
            icon: Icons.flag_outlined,
            title: s.t('goals'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GoalsScreen()),
            ),
          ),
          _tile(
            context,
            icon: Icons.handshake_outlined,
            title: s.t('debts'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DebtsScreen()),
            ),
          ),
          _tile(
            context,
            icon: Icons.calculate_outlined,
            title: s.t('denominations'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DenominationsScreen()),
            ),
          ),
          _tile(
            context,
            icon: Icons.delete_outline,
            title: s.t('recycleBin'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecycleBinScreen()),
            ),
          ),
          _tile(
            context,
            icon: Icons.settings_outlined,
            title: s.t('settings'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          if (state.archivedAccounts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              s.t('deletedBooks'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...state.archivedAccounts.map(
              (a) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Text(a.icon, style: const TextStyle(fontSize: 22)),
                  title: Text(a.name),
                  trailing: TextButton(
                    onPressed: () => state.unarchiveAccount(a),
                    child: Text(s.t('unarchive')),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('about'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(s.t('aboutBody')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
