import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dialogs/task_dialog.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/task_tile.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  static const routeName = '/today';

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final TextEditingController _planMinutesController = TextEditingController(
    text: '120',
  );
  Map<String, dynamic>? _planProposal;

  @override
  void dispose() {
    _planMinutesController.dispose();
    super.dispose();
  }

  void _generatePlan(BuildContext context) {
    final appState = context.read<AppState>();
    final minutes = int.tryParse(_planMinutesController.text) ?? 120;
    final tasks = appState.lists.expand((list) => list.tasks).toList();
    final proposal = appState.generatePlanForDay(
      DateTime.now(),
      minutes,
      tasks: tasks,
    );
    setState(() => _planProposal = proposal);
  }

  Future<void> _savePlan(BuildContext context) async {
    final appState = context.read<AppState>();
    if (_planProposal == null) return;
    await appState.savePlan(Map<String, dynamic>.from(_planProposal!));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('План сохранён на сегодня')));
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final today = DateTime.now();

    final tasksForToday =
        st.lists
            .expand((list) => list.tasks)
            .where((task) => task.date != null && task.appearsOn(today))
            .toList()
          ..sort((a, b) {
            if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
            final aPriority = a.priority ?? 0;
            final bPriority = b.priority ?? 0;
            if (aPriority != bPriority) return bPriority.compareTo(aPriority);
            return (a.title).toLowerCase().compareTo(b.title.toLowerCase());
          });

    final pending = tasksForToday.where((task) => !task.isDone).toList();
    final completed = tasksForToday.where((task) => task.isDone).toList();
    final habitsForToday = st.habits
        .where((habit) => !habit.isDoneOn(today))
        .take(3)
        .toList();
    final selectedTasks = _planProposal == null
        ? <Task>[]
        : st.tasksForPlan(_planProposal!);

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

              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.accent.withAlpha((0.12 * 255).round()),
                      AppColors.surface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.card,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withAlpha(
                              (0.14 * 255).round(),
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'План на сегодня',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _planMinutesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Доступно минут',
                        hintStyle: TextStyle(
                          color: AppColors.textMuted.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w500,
                        ),
                        filled: true,
                        fillColor: AppColors.pageBg,
                        prefixIcon: const Icon(
                          Icons.timer_rounded,
                          color: AppColors.textMuted,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.accent,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _generatePlan(context),
                            icon: const Icon(Icons.bolt_rounded),
                            label: const Text('Сгенерировать'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _planProposal == null
                                ? null
                                : () => _savePlan(context),
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('Сохранить'),
                          ),
                        ),
                      ],
                    ),
                    if (_planProposal != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.pageBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Рекомендовано: ${_planProposal!['selectedTaskIds'].length} задач · ${_planProposal!['usedMinutes']} мин',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (selectedTasks.isEmpty)
                              const Text(
                                'В план не вошло ничего — попробуйте увеличить время.',
                              )
                            else
                              ...selectedTasks.map(
                                (task) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 18,
                                        color: AppColors.accent,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          task.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
                title: 'Задачи на сегодня',
                subtitle:
                    '${pending.length} активных · ${completed.length} готово',
              ),
              const SizedBox(height: 8),

              if (pending.isEmpty && completed.isEmpty)
                _EmptyTodayState(onAdd: () => showTaskDialog(context))
              else ...[
                if (pending.isNotEmpty)
                  ...pending.map(
                    (task) => TaskTile(
                      task,
                      (tk, value) async {
                        final wasDone = tk.isDone;
                        await st.toggleDone(tk, value);
                        if (!wasDone && (value ?? false)) {
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(
                              const SnackBar(content: Text('+5 XP за задачу!')),
                            );
                        }
                      },
                      (tk) => showTaskDialog(context, task: tk),
                      (tk) => st.deleteTask(tk),
                    ),
                  ),
                if (completed.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Готово',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...completed.map(
                    (task) => TaskTile(
                      task,
                      (tk, value) async {
                        final wasDone = tk.isDone;
                        await st.toggleDone(tk, value);
                        if (!wasDone && (value ?? false)) {
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(
                              const SnackBar(content: Text('+5 XP за задачу!')),
                            );
                        }
                      },
                      (tk) => showTaskDialog(context, task: tk),
                      (tk) => st.deleteTask(tk),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

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

class _EmptyTodayState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyTodayState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.checklist_rounded,
              size: 30,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'На сегодня задач нет',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Добавьте важную задачу или перенесите её из Inbox — и день будет собран по плану.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить задачу'),
          ),
        ],
      ),
    );
  }
}
