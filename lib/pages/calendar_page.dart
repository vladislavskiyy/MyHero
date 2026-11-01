// lib/pages/calendar_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../state/app_state.dart';
import '../models/task.dart';
import '../widgets/custom_app_bar.dart';
import '../dialogs/task_dialog.dart';
import '../theme/app_theme.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  static const routeName = '/calendar';

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _completedExpanded = true;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final allTasks = st.lists.expand((list) => list.tasks);

    final selectedDate = _selectedDay ?? _focusedDay;

    final dayTasks = allTasks
        .where((t) => t.date != null && t.appearsOn(selectedDate))
        .toList();

    final pending = dayTasks.where((t) => !t.isDone).toList();
    final completed = dayTasks.where((t) => t.isDone).toList();

    final headerDateText = '${selectedDate.day}.${selectedDate.month}.${selectedDate.year}';
    final totalForDay = dayTasks.length;

    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Календарь', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // календарь в карточке
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Container(
                decoration: AppDecorations.card(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: TableCalendar<Task>(
                  firstDay: DateTime(2020),
                  lastDay: DateTime(2030),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selectedDay = selected;
                      _focusedDay = focused;
                    });
                  },
                  eventLoader: (day) => allTasks
                      .where((t) => t.date != null && t.appearsOn(day))
                      .toList(),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    leftChevronIcon: const Icon(Icons.chevron_left_rounded),
                    rightChevronIcon: const Icon(Icons.chevron_right_rounded),
                    titleTextStyle: Theme.of(context).textTheme.titleMedium!.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                    weekendStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                  ),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    todayDecoration: BoxDecoration(
                      color: AppColors.accent.withAlpha((0.16 * 255).round()),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent, width: 1.2),
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    todayTextStyle: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                    defaultTextStyle: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    weekendTextStyle: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    markerMargin: const EdgeInsets.only(top: 6),
                    markersAlignment: Alignment.bottomCenter,
                  ),
                  calendarBuilders: CalendarBuilders<Task>(
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return const SizedBox.shrink();
                      final dots = events.take(3).map((e) {
                        final task = e;
                        final color = (task.category?.isNotEmpty ?? false) ? task.color : AppColors.textMuted;
                        return Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        );
                      }).toList();

                      return Positioned(
                        bottom: 6,
                        child: Row(mainAxisSize: MainAxisSize.min, children: dots),
                      );
                    },
                  ),
                ),
              ),
            ),

            // компактный заголовок дня/сводка
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.pageBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.event_available_rounded, color: AppColors.accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headerDateText,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            totalForDay == 0
                                ? 'На этот день задач нет'
                                : 'Задач: $totalForDay • В ожидании: ${pending.length} • Выполнено: ${completed.length}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // список задач
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    if (pending.isEmpty && completed.isEmpty) ...[
                      const SizedBox(height: 28),
                      _EmptyState(
                        onCreate: () => showTaskDialog(context),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      for (final t in pending) _buildTaskTile(st, t),
                      if (completed.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(bottom: 6),
                            title: Text(
                              'Выполненные (${completed.length})',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontSize: 14.5,
                                    color: AppColors.textMuted,
                                  ),
                            ),
                            initiallyExpanded: _completedExpanded,
                            onExpansionChanged: (e) => setState(() => _completedExpanded = e),
                            children: [
                              for (final t in completed) _buildTaskTile(st, t),
                            ],
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTile(AppState st, Task t) {
    final subtitle = t.date != null ? '${t.date!.day}.${t.date!.month}.${t.date!.year}' : null;

    return Dismissible(
      key: ValueKey(t.key ?? t.hashCode),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withAlpha((0.12 * 255).round()),
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: const Color(0xFFEF4444).withAlpha((0.25 * 255).round())),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444)),
      ),
      confirmDismiss: (_) async {
        st.deleteTask(t);
        return true;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          boxShadow: AppShadows.card,
          border: Border.all(color: AppColors.border),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: Checkbox(
            value: t.isDone,
            onChanged: (v) => st.toggleDone(t, v),
            activeColor: AppColors.accent,
          ),
          title: Text(
            t.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              decoration: t.isDone ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
          trailing: IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.accent),
            onPressed: () => showTaskDialog(context, task: t),
            tooltip: 'Редактировать',
          ),
          onLongPress: () => st.deleteTask(t),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.inbox_rounded, color: AppColors.accent),
          ),
          const SizedBox(height: 12),
          Text(
            'Задач на этот день нет',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Добавь первую задачу, чтобы начать планирование.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить задачу'),
          ),
        ],
      ),
    );
  }
}
