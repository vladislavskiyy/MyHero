// lib/widgets/task_tile.dart
import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme/app_theme.dart';

class TaskTile extends StatelessWidget {
  final Task task;
  final void Function(Task, bool?) onToggle;
  final void Function(Task) onEdit;
  final void Function(Task) onDelete;

  const TaskTile(
    this.task,
    this.onToggle,
    this.onEdit,
    this.onDelete, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final stripeColor = (task.category?.isNotEmpty ?? false) ? task.color : AppColors.textMuted;
    final dateText = task.date != null
        ? '${task.date!.day.toString().padLeft(2, '0')}.${task.date!.month.toString().padLeft(2, '0')}.${task.date!.year}'
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onLongPress: () => onDelete(task),
            child: Row(
              children: [
                // Цветная “полоса” слева
                Container(
                  width: 8,
                  height: 84,
                  decoration: BoxDecoration(
                    color: stripeColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppRadii.xl),
                      bottomLeft: Radius.circular(AppRadii.xl),
                    ),
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // checkbox в “плашке”
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.pageBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Transform.scale(
                            scale: 1.05,
                            child: Checkbox(
                              value: task.isDone,
                              onChanged: (v) => onToggle(task, v),
                              activeColor: AppColors.accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              side: const BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // текст
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  decoration: task.isDone ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (dateText != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded,
                                        size: 14, color: AppColors.textMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      dateText,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // действия
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _IconPillButton(
                              icon: Icons.edit_rounded,
                              onTap: () => onEdit(task),
                              tooltip: 'Редактировать',
                            ),
                            const SizedBox(width: 6),
                            _IconPillButton(
                              icon: Icons.delete_rounded,
                              onTap: () => onDelete(task),
                              tooltip: 'Удалить',
                              danger: true,
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _IconPillButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool danger;

  const _IconPillButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = danger ? const Color(0xFFEF4444) : AppColors.accent;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.pageBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 18, color: fg),
        ),
      ),
    );
  }
}
