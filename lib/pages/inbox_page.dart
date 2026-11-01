// lib/pages/inbox_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../models/task.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/task_tile.dart';
import '../dialogs/task_dialog.dart';
import '../theme/app_theme.dart';

class InboxPage extends StatefulWidget {
  static const routeName = '/inbox';
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();

    // гарантируем, что currentList = inbox (чтобы edit/update работали ожидаемо)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (st.currentList.id != AppState.inboxId) {
        st.selectListById(AppState.inboxId);
      }
    });

    final inbox = st.inboxList;
    final pending = inbox.tasks.where((t) => !t.isDone).toList();
    final done = inbox.tasks.where((t) => t.isDone).toList();

    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Inbox', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          children: [
            // Quick add
            Container(
              decoration: AppDecorations.card(),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'Быстро добавить задачу…',
                        filled: true,
                        fillColor: AppColors.pageBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.l),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onSubmitted: (_) => _quickAdd(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.l),
                        ),
                      ),
                      onPressed: () => _quickAdd(context),
                      child: const Icon(Icons.add_rounded),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                children: [
                  if (pending.isEmpty && done.isEmpty) ...[
                    const SizedBox(height: 40),
                    Center(
                      child: Text(
                        'Пока пусто. Скидывай сюда всё, что нужно сделать — разберём позже 🙂',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMuted,
                              height: 1.3,
                            ),
                      ),
                    ),
                  ],

                  for (final t in pending)
                    TaskTile(
                      t,
                      (tk, v) => st.toggleDone(tk, v),
                      (tk) => showTaskDialog(context, task: tk),
                      (tk) => st.deleteTask(tk),
                    ),

                  if (done.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Выполненные',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    for (final t in done)
                      TaskTile(
                        t,
                        (tk, v) => st.toggleDone(tk, v),
                        (tk) => showTaskDialog(context, task: tk),
                        (tk) => st.deleteTask(tk),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: () => showTaskDialog(context),
        child: const Icon(Icons.edit_rounded),
      ),
    );
  }

  Future<void> _quickAdd(BuildContext context) async {
    final title = _ctrl.text.trim();
    if (title.isEmpty) return;

    final st = context.read<AppState>();
    await st.addTaskToInbox(
      Task(
        id: DateTime.now().toIso8601String(),
        title: title,
        // MVP: можно сразу дать дефолтную длительность, чтобы планировщик работал лучше
        durationMinutes: 25,
      ),
    );
    _ctrl.clear();
  }
}
