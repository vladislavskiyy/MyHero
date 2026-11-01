// lib/pages/habit_detail_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../state/app_state.dart';
import '../models/habit.dart';
import '../widgets/custom_app_bar.dart';
import '../theme/app_theme.dart';

class HabitDetailPage extends StatefulWidget {
  static const routeName = '/habit_detail';

  final Habit habit;
  const HabitDetailPage({Key? key, required this.habit}) : super(key: key);

  @override
  State<HabitDetailPage> createState() => _HabitDetailPageState();
}

class _HabitDetailPageState extends State<HabitDetailPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final h = widget.habit;

    final streak = st.habitCurrentStreak(h);
    final monthDone = st.habitCountThisMonth(h);

    final selected = _selectedDay ?? DateTime.now();

    return Scaffold(
      appBar: CustomAppBar(
        title: Text(h.title, style: const TextStyle(color: Colors.white)),
        leading: const BackButton(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header card
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.card,
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: h.color.withAlpha((0.12 * 255).round()),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: h.color.withAlpha((0.18 * 255).round()),
                        ),
                      ),
                      child: Icon(h.icon, color: h.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Статистика',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _StatChip(
                                color: h.color,
                                label: 'Серия: $streak',
                                icon: Icons.local_fire_department_rounded,
                              ),
                              _StatChip(
                                color: const Color(0xFF10B981),
                                label: 'Месяц: $monthDone',
                                icon: Icons.calendar_month_rounded,
                              ),
                              _StatChip(
                                color: const Color(0xFFF59E0B),
                                label: 'Жизни: ${h.lives}',
                                icon: Icons.favorite_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Calendar card
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.card,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020),
                    lastDay: DateTime.utc(2030),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      st.toggleHabitDay(h, selectedDay);
                    },
                    eventLoader: (day) => h.isDoneOn(day) ? [day] : const [],
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: Theme.of(context).textTheme.titleMedium!.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                      leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: AppColors.textMuted),
                      rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                      weekendStyle: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      isTodayHighlighted: true,

                      todayDecoration: BoxDecoration(
                        color: h.color.withAlpha((0.18 * 255).round()),
                        shape: BoxShape.circle,
                        border: Border.all(color: h.color.withAlpha((0.35 * 255).round())),
                      ),
                      selectedDecoration: BoxDecoration(
                        color: h.color,
                        shape: BoxShape.circle,
                      ),
                      defaultTextStyle: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                      weekendTextStyle: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                      selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                      todayTextStyle: TextStyle(color: h.color, fontWeight: FontWeight.w900),

                      markerSize: 6,
                      markerDecoration: BoxDecoration(
                        color: h.color,
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 1,
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        if (!h.isDoneOn(date)) return const SizedBox.shrink();
                        return Positioned(
                          bottom: 6,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: h.color.withAlpha((0.18 * 255).round()),
                              shape: BoxShape.circle,
                              border: Border.all(color: h.color.withAlpha((0.35 * 255).round())),
                            ),
                            child: Icon(Icons.check_rounded, size: 12, color: h.color),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Footer hint
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.pageBg,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Нажми на день, чтобы отметить выполнение привычки.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${selected.day.toString().padLeft(2, '0')}.${selected.month.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final Color color;
  final String label;
  final IconData icon;

  const _StatChip({
    required this.color,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha((0.10 * 255).round()),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha((0.18 * 255).round())),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
