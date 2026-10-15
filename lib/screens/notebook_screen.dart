import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

class NotebookScreen extends StatefulWidget {
  const NotebookScreen({super.key});

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  List<NoteItem> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await context.read<AppState>().repo.getNotes();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('notebook'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Text(
                    s.t('noteEmpty'),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _notes.length,
                  itemBuilder: (ctx, i) {
                    final n = _notes[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Checkbox(
                          value: n.completed,
                          onChanged: (v) async {
                            await state.repo.updateNote(n.copyWith(completed: v ?? false));
                            _load();
                          },
                        ),
                        title: Text(
                          n.note,
                          style: TextStyle(
                            decoration: n.completed ? TextDecoration.lineThrough : null,
                            color: n.completed
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          fmtDateShort(n.date, lang: state.lang),
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await state.repo.deleteNote(n.id!);
                            _load();
                          },
                        ),
                        onTap: () => _noteDialog(existing: n),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _noteDialog(),
        icon: const Icon(Icons.add),
        label: Text(s.t('noteAdd')),
      ),
    );
  }

  Future<void> _noteDialog({NoteItem? existing}) async {
    final state = context.read<AppState>();
    final ctrl = TextEditingController(text: existing?.note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(state.s.t('noteAdd')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          decoration: InputDecoration(hintText: state.s.t('noteHint')),
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
    if (result == null || result.isEmpty) return;
    if (existing == null) {
      await state.repo.insertNote(NoteItem(date: DateTime.now(), note: result));
    } else {
      await state.repo.updateNote(existing.copyWith(note: result, date: DateTime.now()));
    }
    _load();
  }
}
