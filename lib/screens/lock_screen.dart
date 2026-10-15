import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/lock_service.dart';
import '../state/app_state.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _lock = LockService();
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  Future<void> _tryUnlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final state = context.read<AppState>();
    final ok = await _lock.authenticate(state.s.t('unlockDesc'));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_outline, size: 44, color: scheme.primary),
                ),
                const SizedBox(height: 24),
                Text(
                  s.t('unlockTitle'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(s.t('unlockDesc'), textAlign: TextAlign.center),
                if (_failed) ...[
                  const SizedBox(height: 12),
                  Text(
                    s.t('authFailed'),
                    style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _busy ? null : _tryUnlock,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(s.t('unlock')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
