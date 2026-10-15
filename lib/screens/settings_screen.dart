import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/backup_service.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('settings'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Language
          Card(
            child: ListTile(
              leading: const Icon(Icons.language_outlined),
              title: Text(s.t('language')),
              subtitle: Text(state.lang == 'id' ? 'Bahasa Indonesia' : 'English'),
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'id', label: Text('ID')),
                  ButtonSegment(value: 'en', label: Text('EN')),
                ],
                selected: {state.lang},
                onSelectionChanged: (v) => state.setLang(v.first),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Currency
          Card(
            child: ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: Text(s.t('currency')),
              trailing: DropdownButton<String>(
                value: state.currencyCode,
                underline: const SizedBox(),
                items: currencyOptions
                    .map((c) => DropdownMenuItem(value: c.code, child: Text(c.code)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) state.setCurrency(v);
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Theme
          Card(
            child: ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: Text(s.t('theme')),
              trailing: DropdownButton<ThemeMode>(
                value: state.themeMode,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: ThemeMode.system, child: Text(s.t('themeSystem'))),
                  DropdownMenuItem(value: ThemeMode.light, child: Text(s.t('themeLight'))),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text(s.t('themeDark'))),
                ],
                onChanged: (v) {
                  if (v != null) state.setTheme(v);
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          // App lock
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.lock_outline),
              title: Text(s.t('appLock')),
              subtitle: Text(s.t('appLockDesc')),
              value: state.lockEnabled,
              onChanged: (v) => state.setLock(v),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            s.t('backup'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            s.t('backupDesc'),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _exportEncrypted(context),
            icon: const Icon(Icons.enhanced_encryption_outlined),
            label: Text(s.t('backupExport')),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _exportJson(context),
            icon: const Icon(Icons.data_object),
            label: Text(s.t('exportJson')),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _restore(context),
            icon: const Icon(Icons.restore),
            label: Text(s.t('backupRestore')),
          ),
        ],
      ),
    );
  }

  Future<String?> _askPassphrase(BuildContext context, AppState state) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(state.s.t('passphrase')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              obscureText: true,
              decoration: InputDecoration(labelText: state.s.t('passphrase')),
            ),
            const SizedBox(height: 8),
            Text(state.s.t('passphraseHint'), style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(state.s.t('cancel'))),
          FilledButton(
            onPressed: () {
              if (ctrl.text.length >= 6) Navigator.pop(ctx, ctrl.text);
            },
            child: Text(state.s.t('confirm')),
          ),
        ],
      ),
    );
  }

  Future<void> _exportEncrypted(BuildContext context) async {
    final state = context.read<AppState>();
    final pass = await _askPassphrase(context, state);
    if (pass == null || !context.mounted) return;
    try {
      final file = await BackupService.exportEncrypted(pass);
      await Share.shareXFiles([XFile(file.path)]);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.s.t('backupDone'))));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.s.t('operationFailed'))));
      }
    }
  }

  Future<void> _exportJson(BuildContext context) async {
    final state = context.read<AppState>();
    try {
      final file = await BackupService.exportJson(state.dumpJson);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.s.t('operationFailed'))));
      }
    }
  }

  Future<void> _restore(BuildContext context) async {
    final state = context.read<AppState>();
    final s = state.s;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(s.t('restoreConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.t('confirm'))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    final path = picked?.files.single.path;
    if (path == null || !context.mounted) return;

    final pass = await _askPassphrase(context, state);
    if (pass == null || !context.mounted) return;
    try {
      await BackupService.restoreEncrypted(File(path), pass);
      await state.reload();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.t('restoreDone'))));
      }
    } on BackupException {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.t('wrongPassphrase'))));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.t('operationFailed'))));
      }
    }
  }
}
