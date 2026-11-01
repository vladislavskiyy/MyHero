// lib/pages/task_lists_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/custom_app_bar.dart';
import '../theme/app_theme.dart';
import '../dialogs/list_dialog.dart';
import 'task_list_page.dart';

class TaskListsPage extends StatelessWidget {
  const TaskListsPage({Key? key}) : super(key: key);

  IconData _iconForList(String id) {
    switch (id) {
      case 'my_day':
        return Icons.wb_sunny_rounded;
      case 'important':
        return Icons.priority_high_rounded;
      case 'home':
        return Icons.home_rounded;
      default:
        return Icons.checklist_rounded;
    }
  }

  String _subtitleForList(AppState st, int index) {
    final list = st.lists[index];
    final total = list.tasks.length;
    final done = list.tasks.where((t) => t.isDone).length;
    if (total == 0) return 'Нет задач';
    if (done == 0) return '$total задач';
    return '$done из $total выполнено';
  }

  double _progressForList(AppState st, int index) {
    final list = st.lists[index];
    final total = list.tasks.length;
    if (total == 0) return 0;
    final done = list.tasks.where((t) => t.isDone).length;
    return done / total;
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final lists = st.lists;

    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Списки задач', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: lists.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final list = lists[i];
            final icon = _iconForList(list.id);
            final subtitle = _subtitleForList(st, i);
            final progress = _progressForList(st, i);

            return InkWell(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              onTap: () {
                st.selectList(i);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TaskListPage(listIndex: i)),
                );
              },
              onLongPress: () {
                showListDialog(
                  context,
                  listIndex: i,
                  initialName: list.name,
                  initialColor: list.color,
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.card,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Icon badge
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: list.color.withAlpha((0.12 * 255).round()),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: list.color.withAlpha((0.18 * 255).round()),
                          ),
                        ),
                        child: Icon(icon, color: list.color, size: 26),
                      ),
                      const SizedBox(width: 12),

                      // Title + subtitle + progress
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              list.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 14,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progress == 0 ? null : progress,
                                minHeight: 7,
                                backgroundColor: AppColors.pageBg,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  list.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Chevron
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.pageBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showListDialog(context),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Новый список', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
