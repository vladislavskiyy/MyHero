import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dialogs/task_dialog.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/task_tile.dart';
import '../widgets/day_plan_editor.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  static const routeName = '/today';

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final today = DateTime.now();

    final acceptedPlan = st.acceptedPlanForDay(today);
    final acceptedReview = acceptedPlan == null
        ? null
        : st.reviewPlan(acceptedPlan);
    final workingTasks = acceptedPlan == null
        ? <Task>[]
        : st.tasksForPlan(acceptedPlan);
    final pending = workingTasks.where((task) => !task.isDone).toList();
    final completed = workingTasks.where((task) => task.isDone).toList();
    final selectedIds =
        acceptedReview?.entries.map((entry) => entry.id).toSet() ?? <String>{};
    final otherTasks = st.lists
        .expand((list) => list.tasks)
        .where((task) => !task.isDone && !selectedIds.contains(task.id))
        .toList();
    final habitsForToday = st.habits
        .where((habit) => !habit.isDoneOn(today))
        .take(3)
        .toList();
    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Сегодня', style: TextStyle(color: Colors.white)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTaskDialog(context),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Задача', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TodaySummaryCard(
                dateLabel: _formatDate(today),
                pendingCount: pending.length,
                doneCount: completed.length,
                habitsCount: habitsForToday.length,
                level: st.level,
                xp: st.xpBalance,
              ),
              const SizedBox(height: 14),

              DayPlanEditor(day: today, showAcceptedTasks: false),
              const SizedBox(height: 14),

              if (habitsForToday.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Привычки сегодня',
                  subtitle: '${habitsForToday.length} к выполнению',
                ),
                const SizedBox(height: 8),
                ...habitsForToday.map((habit) {
                  final done = habit.isDoneOn(today);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppShadows.card,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: habit.color.withAlpha((0.12 * 255).round()),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: habit.color.withAlpha((0.18 * 255).round()),
                          ),
                        ),
                        child: Icon(habit.icon, color: habit.color),
                      ),
                      title: Text(
                        habit.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${st.habitCurrentStreak(habit)} дней подряд',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      trailing: Checkbox(
                        value: done,
                        onChanged: (_) async {
                          final wasDone = habit.isDoneOn(today);
                          await st.toggleHabitDay(habit, today);
                          if (!context.mounted) return;
                          if (!wasDone &&
                              st.habits.any(
                                (h) => h.id == habit.id && h.isDoneOn(today),
                              )) {
                            ScaffoldMessenger.of(context)
                              ..clearSnackBars()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text('+2 XP за привычку!'),
                                ),
                              );
                          }
                        },
                        activeColor: habit.color,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],

              _SectionHeader(
                title: 'Рабочий список дня',
                subtitle:
                    '${pending.length} активных · ${completed.length} готово',
              ),
              const SizedBox(height: 8),
              if (acceptedReview == null)
                const Text(
                  'Принятого плана на сегодня пока нет. Задачи появятся здесь после подтверждения плана.',
                )
              else if (acceptedReview.entries.isEmpty)
                const Text(
                  'Принят пустой план. Можно отредактировать его и добавить задачи.',
                )
              else
                for (final entry in acceptedReview.entries)
                  if (entry.task == null)
                    Container(
                      key: ValueKey('working-task-${entry.id}'),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(14),
                      decoration: AppDecorations.card(),
                      child: Text(
                        'Задача «${entry.title}» удалена. Исправьте принятый план.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    )
                  else
                    _taskTile(
                      st,
                      entry.task!,
                      key: ValueKey('working-task-${entry.id}'),
                    ),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: ExpansionTile(
                  key: const ValueKey('other-tasks'),
                  title: Text('Остальные задачи (${otherTasks.length})'),
                  subtitle: const Text(
                    'Задачи вне принятого плана, включая другие дни',
                  ),
                  children: [
                    for (final task in otherTasks) _taskTile(st, task),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _taskTile(AppState state, Task task, {Key? key}) => IntrinsicHeight(
    key: key,
    child: TaskTile(
      task,
      (task, value) async {
        final wasDone = task.isDone;
        await state.toggleDone(task, value);
        if (!mounted) return;
        if (!wasDone && (value ?? false)) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('+5 XP за задачу!')));
        }
      },
      (task) => showTaskDialog(context, task: task),
      (task) => state.deleteTask(task),
    ),
  );
  String _formatDate(DateTime date) {
    const months = [
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

class _TodaySummaryCard extends StatelessWidget {
  final String dateLabel;
  final int pendingCount;
  final int doneCount;
  final int habitsCount;
  final int level;
  final int xp;

  const _TodaySummaryCard({
    required this.dateLabel,
    required this.pendingCount,
    required this.doneCount,
    required this.habitsCount,
    required this.level,
    required this.xp,
  });

  @override
  Widget build(BuildContext context) {
    final total = pendingCount + doneCount;
    final ratio = total == 0 ? 0.0 : doneCount / total;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Сегодня',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.12 * 255).round()),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Lv.$level',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricPill(
                    label: 'В работе',
                    value: '$pendingCount',
                    accent: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricPill(
                    label: 'Готово',
                    value: '$doneCount',
                    accent: const Color(0xFF86EFAC),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricPill(
                    label: 'XP',
                    value: '$xp',
                    accent: const Color(0xFFFDE68A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: ratio,
                backgroundColor: Colors.white.withAlpha((0.18 * 255).round()),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Завершенность дня',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.8 * 255).round()),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${(ratio * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              habitsCount > 0
                  ? 'Сегодня есть $habitsCount привычек к выполнению.'
                  : 'Все привычки уже на месте — отличный день для фокуса.',
              style: TextStyle(
                color: Colors.white.withAlpha((0.86 * 255).round()),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.10 * 255).round()),
        borderRadius: BorderRadius.circular(AppRadii.l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha((0.82 * 255).round()),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
