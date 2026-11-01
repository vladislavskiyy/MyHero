// lib/pages/lists_overview_page.dart
//
// Главная (Инструменты):
// - добавил Inbox как 5-й инструмент
// - сделал плитки чуть меньше (aspectRatio + padding + иконки)
// - вместо GridView.count -> GridView.builder (чтобы 5 элементов красиво легли в 2 колонки)

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_app_bar.dart';
import 'task_lists_page.dart';
import 'habit_tracker_page.dart';
import 'journal_page.dart';
import 'scheduler_page.dart';
import 'inbox_page.dart';
import 'calendar_page.dart';

class ToolsOverviewPage extends StatelessWidget {
  const ToolsOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();

    final tools = <_ToolCardData>[
      _ToolCardData(
        icon: Icons.today_rounded,
        title: 'Сегодня',
        subtitle: 'План дня, задачи и привычки',
        cta: 'Открыть день',
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        ),
        onTap: () => Navigator.pushNamed(context, '/today'),
      ),
      _ToolCardData(
        icon: Icons.calendar_month_rounded,
        title: 'Календарь',
        subtitle: 'Просмотр задач по датам',
        cta: 'Открыть календарь',
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0EA5A4), Color(0xFF14B8A6)],
        ),
        onTap: () => Navigator.pushNamed(context, '/calendar'),
      ),
      _ToolCardData(
        icon: Icons.inbox_rounded,
        title: 'Inbox',
        subtitle: 'Быстрый сбор задач',
        cta: 'Добавить быстро',
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
        ),
        onTap: () => Navigator.pushNamed(context, InboxPage.routeName),
      ),
      _ToolCardData(
        icon: Icons.checklist_rounded,
        title: 'Списки задач',
        subtitle: 'Планы, списки, чек-листы',
        cta: 'К задачам',
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6D28D9), Color(0xFF7C3AED)],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TaskListsPage()),
        ),
      ),
      _ToolCardData(
        icon: Icons.power_settings_new_rounded,
        title: 'Трекер привычек',
        subtitle: 'Серии и прогресс',
        cta: 'Отметить сегодня',
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0EA5A4), Color(0xFF22C55E)],
        ),
        onTap: () => Navigator.pushNamed(context, HabitTrackerPage.routeName),
      ),
      _ToolCardData(
        icon: Icons.menu_book_rounded,
        title: 'Личный дневник',
        subtitle: 'Записи и эмоции',
        cta: 'Новая запись',
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
        ),
        onTap: () => Navigator.pushNamed(context, JournalPage.routeName),
      ),
      _ToolCardData(
        icon: Icons.event_available_rounded,
        title: 'Планировщик',
        subtitle: 'Реалистичный план дня',
        cta: 'Собрать день',
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
        ),
        onTap: () => Navigator.pushNamed(context, SchedulerPage.routeName),
      ),
    ];

    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Инструменты', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderCard(
                title: 'Выберите инструмент',
                subtitle: 'Соберите задачи в Inbox и двигайтесь дальше: списки, привычки, дневник и план дня.',
                level: st.level,
                xp: st.xpBalance,
                coins: st.coins,
                progress: (st.xpRequiredForNextLevel == 0)
                    ? 0
                    : (st.xpProgressInLevel / st.xpRequiredForNextLevel).clamp(0.0, 1.0),
              ),
              const SizedBox(height: 14),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  // чуть меньше плитки
                  childAspectRatio: 1.05,
                ),
                itemCount: tools.length,
                itemBuilder: (context, i) {
                  final t = tools[i];
                  return _ToolCard(
                    icon: t.icon,
                    title: t.title,
                    subtitle: t.subtitle,
                    cta: t.cta,
                    gradient: t.gradient,
                    onTap: t.onTap,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolCardData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String cta;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ToolCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.gradient,
    required this.onTap,
  });
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int level;
  final int xp;
  final int coins;
  final double progress;

  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.level,
    required this.xp,
    required this.coins,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Stack(
          children: [
            Positioned(
              right: -42,
              top: -42,
              child: _BlurBlob(
                size: 140,
                color: AppColors.accent.withAlpha((0.18 * 255).round()),
              ),
            ),
            Positioned(
              left: -48,
              bottom: -48,
              child: _BlurBlob(
                size: 170,
                color: AppColors.accent.withAlpha((0.10 * 255).round()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.pageBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.grid_view_rounded, color: AppColors.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12.5,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      _StatChip(icon: Icons.bolt_rounded, label: 'Lv.$level'),
                      const SizedBox(width: 8),
                      _StatChip(icon: Icons.star_rounded, label: '$xp XP'),
                      const SizedBox(width: 8),
                      _StatChip(icon: Icons.monetization_on_rounded, label: '$coins'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'До следующего уровня: ${(100 * (1 - progress)).clamp(0, 100).round()}%',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontSize: 12.5,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String cta;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            gradient: gradient,
            boxShadow: AppShadows.card,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withAlpha((0.22 * 255).round()),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -40,
                  top: -40,
                  child: _BlurBlob(
                    size: 150,
                    color: Colors.white.withAlpha((0.14 * 255).round()),
                  ),
                ),

                Padding(
                  // меньше паддинг — меньше карточка
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha((0.18 * 255).round()),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withAlpha((0.22 * 255).round()),
                              ),
                            ),
                            child: Icon(icon, color: Colors.white, size: 19),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white.withAlpha((0.92 * 255).round()),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withAlpha((0.88 * 255).round()),
                              fontWeight: FontWeight.w600,
                              fontSize: 12.2,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.18 * 255).round()),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withAlpha((0.22 * 255).round()),
                            ),
                          ),
                          child: Text(
                            cta,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.8,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlurBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _BlurBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
