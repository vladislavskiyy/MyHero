// lib/dialogs/habit_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../models/habit.dart';
import '../theme/app_theme.dart';

Future<void> showHabitDialog(BuildContext context, {Habit? habit}) async {
  final isEdit = habit != null;

  final nameCtrl = TextEditingController(text: habit?.title ?? '');
  Color pickColor = habit?.color ?? AppColors.accent;
  IconData pickIcon = habit?.icon ?? Icons.self_improvement_rounded;

  final icons = <IconData>[
    Icons.self_improvement_rounded,
    Icons.fitness_center_rounded,
    Icons.menu_book_rounded,
    Icons.nights_stay_rounded,
    Icons.brush_rounded,
    Icons.music_note_rounded,
    Icons.water_drop_rounded,
    Icons.fastfood_rounded,
  ];

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (ctx, setState) {
              Widget colorDot(Color c) {
                final selected = pickColor.toARGB32() == c.toARGB32();
                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => setState(() => pickColor = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? Colors.black.withValues(alpha: 0.65)
                            : Colors.white,
                        width: selected ? 2.5 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: c.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          )
                        : null,
                  ),
                );
              }

              Widget iconChip(IconData ic) {
                final selected = pickIcon == ic;
                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => setState(() => pickIcon = ic),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected
                          ? pickColor.withValues(alpha: 0.14)
                          : AppColors.pageBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? pickColor : AppColors.border,
                        width: selected ? 1.8 : 1.2,
                      ),
                    ),
                    child: Icon(
                      ic,
                      color: selected ? pickColor : AppColors.textMuted,
                      size: 24,
                    ),
                  ),
                );
              }

              final canSave = nameCtrl.text.trim().isNotEmpty;

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadii.xl),
                  ),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 24,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isEdit
                                ? 'Редактировать привычку'
                                : 'Новая привычка',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Закрыть',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Название привычки',
                        prefixIcon: Icon(Icons.edit_rounded),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Цвет',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        colorDot(const Color(0xFF4F46E5)),
                        colorDot(const Color(0xFF14B8A6)),
                        colorDot(const Color(0xFFF97316)),
                        colorDot(const Color(0xFFEF4444)),
                        colorDot(const Color(0xFF22C55E)),
                        colorDot(const Color(0xFF06B6D4)),
                        colorDot(const Color(0xFFA855F7)),
                        colorDot(const Color(0xFFF59E0B)),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Иконка',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: icons.map(iconChip).toList(),
                    ),

                    const SizedBox(height: 18),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canSave ? pickColor : AppColors.border,
                        foregroundColor: canSave
                            ? Colors.white
                            : AppColors.textMuted,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.m),
                        ),
                        elevation: 0,
                      ),
                      onPressed: canSave
                          ? () {
                              final name = nameCtrl.text.trim();
                              final appState = context.read<AppState>();

                              if (!isEdit) {
                                final newHabit = Habit(
                                  id: DateTime.now().toIso8601String(),
                                  title: name,
                                  colorValue: pickColor.toARGB32(),
                                  iconCodePoint: pickIcon.codePoint,
                                  iconFontFamily: pickIcon.fontFamily ?? '',
                                );
                                appState.addHabit(newHabit);
                              } else {
                                habit.title = name;
                                habit.color = pickColor;
                                habit.icon = pickIcon;

                                appState.updateHabit(
                                  habit,
                                  title: name,
                                  color: pickColor,
                                  icon: pickIcon,
                                );
                              }

                              Navigator.pop(ctx);
                            }
                          : null,
                      icon: Icon(
                        isEdit ? Icons.save_rounded : Icons.add_rounded,
                      ),
                      label: Text(isEdit ? 'Сохранить' : 'Создать'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
}
