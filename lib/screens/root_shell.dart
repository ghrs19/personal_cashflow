import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'entry_editor_screen.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'notebook_screen.dart';
import 'reports_screen.dart';

/// Shell styled after KasirFree POS: a bottom bar with a shadow, grey
/// unselected items, primary-colored selection, and a prominent circular
/// center button (there: cashier; here: add transaction).
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final scheme = Theme.of(context).colorScheme;
    final pages = [
      const HomeScreen(),
      const ReportsScreen(),
      const NotebookScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: FloatingActionButton(
        onPressed: state.accounts.isEmpty
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EntryEditorScreen(accountId: state.accounts.first.id!),
                  ),
                ),
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        tooltip: s.t('addEntry'),
        child: const Icon(Icons.add, size: 26),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 15,
              offset: const Offset(0, -3),
              spreadRadius: 2,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                _tab(0, Icons.home_outlined, Icons.home, s.t('home'), scheme),
                _tab(1, Icons.bar_chart_outlined, Icons.bar_chart, s.t('reports'), scheme),
                const SizedBox(width: 64), // space for the center FAB
                _tab(2, Icons.note_alt_outlined, Icons.note_alt, s.t('notebook'), scheme),
                _tab(3, Icons.grid_view_outlined, Icons.grid_view, s.t('more'), scheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(
    int index,
    IconData icon,
    IconData selectedIcon,
    String label,
    ColorScheme scheme,
  ) {
    final selected = _index == index;
    final color = selected ? scheme.primary : Colors.grey.shade500;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
