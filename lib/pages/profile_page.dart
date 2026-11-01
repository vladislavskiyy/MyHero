// lib/pages/profile_page.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/productivity_chart.dart';
import 'achievements_page.dart';
import 'store_page.dart';
import 'settings_page.dart';
import 'login_page.dart';
import 'signup_page.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  static const routeName = '/profile';

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();

    if (!st.isLoggedIn) {
      return Scaffold(
        appBar: const CustomAppBar(
          title: Text('Профиль', style: TextStyle(color: Colors.white)),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: AppDecorations.card(),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.accent,
                              AppColors.accent.withAlpha((0.75 * 255).round()),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: AppShadows.card,
                        ),
                        child: const Icon(Icons.person_rounded, color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Вы не вошли в систему',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Авторизуйтесь, чтобы видеть прогресс, достижения и статистику.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () => Navigator.pushNamed(context, LoginPage.routeName),
                        child: const Text('Войти'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => Navigator.pushNamed(context, SignupPage.routeName),
                        child: const Text('Зарегистрироваться'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final email = st.currentUser ?? '';

    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Профиль', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileHeader(email: email, level: st.level, xp: st.xpBalance),
              const SizedBox(height: 12),

              _XpCard(
                level: st.level,
                xpInLevel: st.xpInLevel,
                xpToNext: st.xpToNextLevel,
                progress: (st.xpRequiredForNextLevel == 0)
                    ? 0
                    : (st.xpProgressInLevel / st.xpRequiredForNextLevel).clamp(0.0, 1.0),
              ),
              const SizedBox(height: 12),

              const _SectionTitle(title: 'Статистика'),
              const SizedBox(height: 10),

              _StatsGrid(
                totalTasks: st.lists.fold<int>(0, (sum, l) => sum + l.tasks.length),
                doneTasks: st.lists.fold<int>(
                  0,
                  (sum, l) => sum + l.tasks.where((t) => t.isDone).length,
                ),
                coins: st.coins,
              ),
              const SizedBox(height: 16),

              const _SectionTitle(title: 'Продуктивность'),
              const SizedBox(height: 10),
              Container(
                decoration: AppDecorations.card(),
                padding: const EdgeInsets.all(14),
                child: const ProductivityChart(),
              ),
              const SizedBox(height: 10),

              _MetaRow(
                left: 'Среднее / день',
                right: st.averagePerDay().toStringAsFixed(1),
              ),
              const SizedBox(height: 8),
              _MetaRow(
                left: 'Макс. серия (неделя)',
                right: '${st.maxStreakThisWeek()}',
              ),
              const SizedBox(height: 18),

              const _SectionTitle(title: 'Действия'),
              const SizedBox(height: 10),

              _ActionTile(
                icon: Icons.emoji_events_rounded,
                title: 'Достижения',
                subtitle: 'Твои награды и прогресс',
                onTap: () => Navigator.pushNamed(context, AchievementsPage.routeName),
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.store_rounded,
                title: 'Магазин',
                subtitle: 'Потрать монеты на улучшения',
                onTap: () => Navigator.pushNamed(context, StorePage.routeName),
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.settings_rounded,
                title: 'Настройки',
                subtitle: 'Оформление и параметры',
                onTap: () => Navigator.pushNamed(context, SettingsPage.routeName),
              ),
              const SizedBox(height: 18),

              _DangerButton(
                label: 'Выйти из аккаунта',
                onPressed: () async {
                  // ignore: use_build_context_synchronously
                  final nav = Navigator.of(context);
                  await AuthService.signOut();
                  context.read<AppState>().setUser(null);
                  nav.pushReplacementNamed(LoginPage.routeName);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String email;
  final int level;
  final int xp;

  const _ProfileHeader({
    required this.email,
    required this.level,
    required this.xp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent,
            AppColors.accent.withAlpha((0.70 * 255).round()),
          ],
        ),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -40,
              child: _BlurBlob(color: Colors.white.withAlpha((0.18 * 255).round()), size: 140),
            ),
            Positioned(
              bottom: -45,
              left: -45,
              child: _BlurBlob(color: Colors.white.withAlpha((0.12 * 255).round()), size: 160),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.18 * 255).round()),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withAlpha((0.22 * 255).round())),
                    ),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Уровень $level • XP $xp',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withAlpha((0.85 * 255).round()),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                        ),
                      ],
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

class _XpCard extends StatelessWidget {
  final int level;
  final int xpInLevel;
  final int xpToNext;
  final double progress;

  const _XpCard({
    required this.level,
    required this.xpInLevel,
    required this.xpToNext,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Прогресс уровня', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.pageBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'LVL $level',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
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
          const SizedBox(height: 10),
          Text(
            'Уровень $level: $xpInLevel XP (осталось $xpToNext)',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _StatsGrid extends StatelessWidget {
  final int totalTasks;
  final int doneTasks;
  final int coins;

  const _StatsGrid({
    required this.totalTasks,
    required this.doneTasks,
    required this.coins,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.0,
      children: [
        _MiniStatCard(icon: Icons.list_alt_rounded, label: 'Задач', value: '$totalTasks'),
        _MiniStatCard(icon: Icons.check_circle_rounded, label: 'Готово', value: '$doneTasks'),
        _MiniStatCard(icon: Icons.monetization_on_rounded, label: 'Монеты', value: '$coins'),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(radius: AppRadii.l),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.accent, size: 18),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String left;
  final String right;

  const _MetaRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.l),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Text(
            left,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          Text(
            right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
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
          decoration: AppDecorations.card(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.pageBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(icon, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted.withAlpha((0.9 * 255).round())),
            ],
          ),
        ),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final String label;
  final Future<void> Function() onPressed;

  const _DangerButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFEF4444),
        foregroundColor: Colors.white,
      ),
      onPressed: () async => onPressed(),
      child: Text(label),
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
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
