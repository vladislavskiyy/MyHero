// lib/widgets/custom_app_bar.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showStats;

  const CustomAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.showStats = true,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final stats = _StatsPills(
      level: state.level,
      xp: state.xpBalance,
      coins: state.coins,
    );

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      leading: leading,
      centerTitle: false,
      title: DefaultTextStyle.merge(
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        child: title,
      ),
      actions: [
        if (showStats) stats,
        if (actions != null) ...actions!,
        const SizedBox(width: 8),
      ],
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Градиент
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.accent,
                    AppColors.accent.withAlpha((0.65 * 255).round()),
                    const Color(0xFF111827),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
            // Мягкий “glass” слой
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                color: Colors.white.withAlpha((0.05 * 255).round()),
              ),
            ),
            // Декоративные блики
            Positioned(
              top: -36,
              right: -40,
              child: _GlowBlob(
                color: Colors.white.withAlpha((0.14 * 255).round()),
                size: 140,
              ),
            ),
            Positioned(
              bottom: -44,
              left: -42,
              child: _GlowBlob(
                color: Colors.white.withAlpha((0.10 * 255).round()),
                size: 170,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 6);
}

class _StatsPills extends StatelessWidget {
  final int level;
  final int xp;
  final int coins;

  const _StatsPills({
    required this.level,
    required this.xp,
    required this.coins,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Row(
        children: [
          _Pill(
            icon: Icons.bolt_rounded,
            iconColor: Colors.white,
            label: 'Lv.$level',
          ),
          const SizedBox(width: 8),
          _Pill(
            icon: Icons.star_rounded,
            iconColor: const Color(0xFFFFD54A),
            label: '$xp',
          ),
          const SizedBox(width: 8),
          _Pill(
            icon: Icons.monetization_on_rounded,
            iconColor: const Color(0xFFFFC107),
            label: '$coins',
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _Pill({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.14 * 255).round()),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withAlpha((0.18 * 255).round()),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
