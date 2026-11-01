// lib/pages/habit_tracker_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../dialogs/habit_dialog.dart';
import '../widgets/custom_app_bar.dart';
import '../theme/app_theme.dart';
import 'habit_detail_page.dart';

class HabitTrackerPage extends StatelessWidget {
  static const routeName = '/habits';

  const HabitTrackerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final habits = st.habits;
    final today = DateTime.now();

    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Трекер привычек', style: TextStyle(color: Colors.white)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showHabitDialog(context),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Привычка', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: habits.isEmpty
            ? _EmptyHabits(
                onAdd: () => showHabitDialog(context),
              )
            : ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: habits.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final h = habits[i];
                  final streak = st.habitCurrentStreak(h);
                  final doneToday = h.isDoneOn(today);

                  return InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => HabitDetailPage(habit: h)),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppShadows.card,
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          // Icon badge
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

                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        h.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.textPrimary,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Lives
                                    _Lives(lives: h.lives),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Streak chip
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _ChipPill(
                                      icon: Icons.local_fire_department_rounded,
                                      label: '$streak дней подряд',
                                      color: const Color(0xFFF59E0B),
                                    ),
                                    _ChipPill(
                                      icon: doneToday ? Icons.check_rounded : Icons.circle_outlined,
                                      label: doneToday ? 'Сегодня выполнено' : 'Сегодня не отмечено',
                                      color: doneToday ? const Color(0xFF10B981) : AppColors.textMuted,
                                      filled: doneToday,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 10),

                          // Actions (checkbox + edit)
                          Column(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.pageBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Checkbox(
                                  value: doneToday,
                                  onChanged: (_) async {
                                    final wasDone = doneToday;
                                    await st.toggleHabitDay(h, today);
                                    if (!wasDone && h.isDoneOn(today)) {
                                      ScaffoldMessenger.of(context)
                                        ..clearSnackBars()
                                        ..showSnackBar(
                                          const SnackBar(content: Text('+2 XP за привычку!')),
                                        );
                                    }
                                  },
                                  activeColor: h.color,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.pageBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.edit_rounded, size: 20, color: AppColors.textMuted),
                                  onPressed: () => showHabitDialog(context, habit: h),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _Lives extends StatelessWidget {
  final int lives;
  const _Lives({required this.lives});

  @override
  Widget build(BuildContext context) {
    if (lives <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.redAccent.withAlpha((0.10 * 255).round()),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.redAccent.withAlpha((0.18 * 255).round())),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded, size: 16, color: Colors.redAccent),
            SizedBox(width: 6),
            Text('0', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.redAccent.withAlpha((0.10 * 255).round()),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.redAccent.withAlpha((0.18 * 255).round())),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_rounded, size: 16, color: Colors.redAccent),
          const SizedBox(width: 6),
          Text(
            '$lives',
            style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _ChipPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;

  const _ChipPill({
    required this.icon,
    required this.label,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled ? color.withAlpha((0.14 * 255).round()) : AppColors.pageBg;
    final bd = filled ? color.withAlpha((0.22 * 255).round()) : AppColors.border;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: filled ? color : AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _EmptyHabits extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyHabits({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha((0.12 * 255).round()),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.accent.withAlpha((0.18 * 255).round())),
              ),
              child: const Icon(Icons.track_changes_rounded, color: AppColors.accent),
            ),
            const SizedBox(height: 14),
            Text(
              'Привычек пока нет',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Создай привычку и отмечай выполнение каждый день — так будет расти серия и XP.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Добавить привычку'),
            ),
          ],
        ),
      ),
    );
  }
}
