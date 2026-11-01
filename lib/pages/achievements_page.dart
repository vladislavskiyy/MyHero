// lib/pages/achievements_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../models/achievement.dart';
import '../widgets/custom_app_bar.dart';
import '../theme/app_theme.dart';

class AchievementsPage extends StatelessWidget {
  static const routeName = '/achievements';
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final achievements = st.achievements;

    final unlockedCount = achievements.where((a) => a.isUnlocked).length;
    final total = achievements.length;
    final headerProgress = total == 0 ? 0.0 : (unlockedCount / total).clamp(0.0, 1.0);

    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Достижения', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: _AchievementsHeader(
                  unlocked: unlockedCount,
                  total: total,
                  progress: headerProgress,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.84,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final a = achievements[index];
                    return _AchievementCard(achievement: a, state: st);
                  },
                  childCount: achievements.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementsHeader extends StatelessWidget {
  final int unlocked;
  final int total;
  final double progress;

  const _AchievementsHeader({
    required this.unlocked,
    required this.total,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.emoji_events_rounded, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Прогресс',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$unlocked из $total открыто',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final AppState state;

  const _AchievementCard({
    required this.achievement,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final unlocked = a.isUnlocked;

    final progress = _calcProgress(a, state).clamp(0.0, 1.0);
    final percent = (progress * 100).round();

    final borderColor = unlocked ? const Color(0xFF22C55E) : AppColors.border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        onTap: () {
          // Лёгкая подсказка без отдельного экрана
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(unlocked ? 'Достижение уже открыто ✅' : 'Прогресс: $percent%'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            color: unlocked ? AppColors.surface : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: AppShadows.card,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // top row (icon + status)
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.pageBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(
                        unlocked ? Icons.emoji_events_rounded : Icons.lock_rounded,
                        color: unlocked ? const Color(0xFFF59E0B) : AppColors.textMuted,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: unlocked
                            ? const Color(0x1622C55E)
                            : const Color(0x14000000),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: unlocked ? const Color(0x3322C55E) : AppColors.border,
                        ),
                      ),
                      child: Text(
                        unlocked ? 'Открыто' : '$percent%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: unlocked ? const Color(0xFF16A34A) : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Text(
                  a.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),

                Text(
                  a.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12.5,
                      ),
                ),

                const Spacer(),

                if (a.type != AchievementType.level) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: unlocked ? 1.0 : progress,
                      minHeight: 8,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        unlocked ? const Color(0xFF22C55E) : AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    unlocked ? 'Выполнено ✅' : 'Осталось: ${100 - percent}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: unlocked ? const Color(0xFF16A34A) : AppColors.textMuted,
                        ),
                  ),
                ] else ...[
                  // Для level-достижений без прогресс-бара
                  Text(
                    unlocked ? 'Достигнуто ✅' : 'Открывается по уровню',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: unlocked ? const Color(0xFF16A34A) : AppColors.textMuted,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _calcProgress(Achievement a, AppState st) {
    if (a.isUnlocked) return 1.0;
    if (a.type == AchievementType.level) return 0.0;

    switch (a.type) {
      case AchievementType.tasks:
        final req = a.requiredCount ?? 0;
        if (req <= 0) return 0.0;
        return (st.totalCompleted / req).clamp(0.0, 1.0);

      case AchievementType.habitStreak:
        final req = a.requiredHabitStreak ?? 0;
        if (req <= 0) return 0.0;
        final best = st.habits
            .map((h) => st.habitCurrentStreak(h))
            .fold<int>(0, (prev, cur) => cur > prev ? cur : prev);
        return (best / req).clamp(0.0, 1.0);

      default:
        return 0.0;
    }
  }
}
