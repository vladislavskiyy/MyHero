// lib/pages/settings_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/custom_app_bar.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const routeName = '/settings';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Настройки', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsTile(
            icon: Icons.palette_rounded,
            title: 'Тема приложения',
            subtitle: state.isDarkMode ? 'Тёмная тема' : 'Светлая тема',
            trailing: Switch(
              value: state.isDarkMode,
              onChanged: (value) => context.read<AppState>().toggleDarkMode(value),
              activeColor: AppColors.accent,
            ),
          ),
          const Divider(),
          _SettingsTile(
            icon: Icons.notifications_rounded,
            title: 'Уведомления',
            subtitle: state.notificationsEnabled ? 'Включены' : 'Выключены',
            trailing: Switch(
              value: state.notificationsEnabled,
              onChanged: (value) => context.read<AppState>().toggleNotifications(value),
              activeColor: AppColors.accent,
            ),
          ),
          const Divider(),
          _SettingsTile(
            icon: Icons.info_rounded,
            title: 'О приложении',
            subtitle: 'Версия 1.0.0',
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'PlannerApp',
                applicationVersion: '1.0.0',
                children: const [
                  Text('Приложение с геймификацией для планирования задач и привычек.'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      leading: Icon(icon, color: AppColors.accent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted)),
      trailing: trailing,
    );

    if (onTap == null) {
      return tile;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.l),
      onTap: onTap,
      child: tile,
    );
  }
}
