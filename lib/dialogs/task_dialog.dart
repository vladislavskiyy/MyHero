// lib/dialogs/task_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../services/task_ai_service.dart';

Future<void> showTaskDialog(BuildContext context, {Task? task}) async {
  final isEdit = task != null;

  final titleController = TextEditingController(text: task?.title ?? '');
  DateTime? selectedDate = task?.date;

  String category = task?.category ?? '';
  Color selectedColor = task?.color ?? AppColors.accent;

  int? durationMinutes = task?.durationMinutes;
  final estimatedDurationMinutes = task?.estimatedDurationMinutes;
  final breakdownSteps = task?.breakdownSteps ?? <String>[];
  int? priority = task?.priority;
  TaskRecurrenceType recurrenceType =
      task?.recurrenceType ?? TaskRecurrenceType.none;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: _TaskSheet(
            isEdit: isEdit,
            titleController: titleController,
            initialDate: selectedDate,
            initialCategory: category,
            initialColor: selectedColor,
            initialDuration: durationMinutes,
            initialEstimatedDuration: estimatedDurationMinutes,
            initialBreakdownSteps: breakdownSteps,
            initialPriority: priority,
            initialRecurrenceType: recurrenceType,
            onSave:
                ({
                  required String title,
                  required DateTime? date,
                  required String category,
                  required Color color,
                  required int? duration,
                  required int? estimatedDuration,
                  required List<String> breakdownSteps,
                  required int? priority,
                  required TaskRecurrenceType recurrenceType,
                }) async {
                  final appState = context.read<AppState>();

                  final catToSave = category.trim().isNotEmpty
                      ? category.trim()
                      : null;
                  final colorToSave = category.trim().isNotEmpty ? color : null;

                  if (isEdit) {
                    task
                      ..title = title
                      ..date = date
                      ..category = catToSave
                      ..color = colorToSave
                      ..durationMinutes = duration
                      ..estimatedDurationMinutes = estimatedDuration
                      ..breakdownSteps = breakdownSteps
                      ..priority = priority
                      ..recurrenceType = recurrenceType;

                    await appState.updateTask(
                      task,
                      title: title,
                      date: date,
                      category: catToSave,
                      color: colorToSave,
                    );
                  } else {
                    await appState.addTask(
                      Task(
                        id: DateTime.now().toIso8601String(),
                        title: title,
                        date: date,
                        category: catToSave,
                        color: colorToSave,
                        durationMinutes: duration,
                        estimatedDurationMinutes: estimatedDuration,
                        breakdownSteps: breakdownSteps,
                        priority: priority,
                        recurrenceType: recurrenceType,
                      ),
                    );
                  }

                  if (date != null && appState.notificationsEnabled) {
                    final reminderDate = date.subtract(
                      const Duration(minutes: 30),
                    );
                    if (reminderDate.isAfter(DateTime.now())) {
                      await NotificationService().scheduleNotification(
                        id: date.millisecondsSinceEpoch ~/ 1000,
                        title: 'Напоминание о задаче',
                        body: title,
                        scheduledDate: reminderDate,
                        payload: title,
                      );
                    }
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                },
          ),
        ),
      ),
    ),
  );
}

class _TaskSheet extends StatefulWidget {
  final bool isEdit;
  final TextEditingController titleController;

  final DateTime? initialDate;
  final String initialCategory;
  final Color initialColor;
  final int? initialDuration;
  final int? initialEstimatedDuration;
  final List<String> initialBreakdownSteps;
  final int? initialPriority;
  final TaskRecurrenceType initialRecurrenceType;

  final Future<void> Function({
    required String title,
    required DateTime? date,
    required String category,
    required Color color,
    required int? duration,
    required int? estimatedDuration,
    required List<String> breakdownSteps,
    required int? priority,
    required TaskRecurrenceType recurrenceType,
  })
  onSave;

  const _TaskSheet({
    required this.isEdit,
    required this.titleController,
    required this.initialDate,
    required this.initialCategory,
    required this.initialColor,
    required this.initialDuration,
    required this.initialEstimatedDuration,
    required this.initialBreakdownSteps,
    required this.initialPriority,
    required this.initialRecurrenceType,
    required this.onSave,
  });

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  late DateTime? _date = widget.initialDate;
  late String _category = widget.initialCategory;
  late Color _color = widget.initialColor;
  late int? _duration = widget.initialDuration;
  late int? _estimatedDuration = widget.initialEstimatedDuration;
  late List<String> _breakdownSteps = List.of(widget.initialBreakdownSteps);
  late int? _priority = widget.initialPriority;
  late TaskRecurrenceType _recurrenceType = widget.initialRecurrenceType;

  bool _advanced = false;
  bool _isGeneratingSuggestion = false;
  bool _isSaving = false;
  String? _saveError;
  String? _aiError;
  String? _estimateRange;
  String? _estimateAssumptions;

  Future<void> _generateSuggestion() async {
    final title = widget.titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _aiError = 'Сначала введите название задачи.');
      return;
    }

    setState(() {
      _isGeneratingSuggestion = true;
      _aiError = null;
    });

    try {
      final suggestion = await TaskAiService().estimateAndBreakDown(title);
      if (!mounted) return;
      setState(() {
        _estimatedDuration = suggestion.estimateMinutes;
        _breakdownSteps = suggestion.steps;
        _estimateRange =
            '${suggestion.minMinutes}–${suggestion.maxMinutes} мин';
        _estimateAssumptions = suggestion.assumptions;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _aiError = 'Не удалось получить оценку: $error');
    } finally {
      if (mounted) setState(() => _isGeneratingSuggestion = false);
    }
  }

  String get _dateText {
    final d = _date;
    if (d == null) return 'Без даты';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEdit ? 'Редактирование задачи' : 'Новая задача';
    final isAiSupported =
        kIsWeb || defaultTargetPlatform == TargetPlatform.android;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.xl),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grabber + title
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
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Закрыть',
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title input
            TextField(
              controller: widget.titleController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Название задачи',
                prefixIcon: Icon(Icons.edit_rounded),
              ),
            ),

            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: !isAiSupported || _isGeneratingSuggestion
                  ? null
                  : _generateSuggestion,
              icon: _isGeneratingSuggestion
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                !isAiSupported
                    ? 'AI-помощник доступен в Android-приложении и Web'
                    : _isGeneratingSuggestion
                    ? 'Оцениваю задачу...'
                    : 'Оценить длительность и разбить',
              ),
            ),
            if (_aiError != null) ...[
              const SizedBox(height: 4),
              Text(
                _aiError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_estimatedDuration != null || _breakdownSteps.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha((0.08 * 255).round()),
                  borderRadius: BorderRadius.circular(AppRadii.l),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_estimatedDuration != null)
                      Text(
                        'Оценка: около $_estimatedDuration мин'
                        '${_estimateRange == null ? '' : ' ($_estimateRange)'}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    if (_estimateAssumptions?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        _estimateAssumptions!,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (_breakdownSteps.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      for (var i = 0; i < _breakdownSteps.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text('${i + 1}. ${_breakdownSteps[i]}'),
                        ),
                    ],
                    const SizedBox(height: 6),
                    const Text(
                      'Шаги и оценка сохранятся вместе с задачей. '
                      'Проверьте их перед сохранением.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Date + Category row
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.calendar_today_rounded,
                    title: 'Дата',
                    value: _dateText,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.sell_rounded,
                    title: 'Тег',
                    value: _category.trim().isEmpty ? 'Не задан' : _category,
                    trailing: _category.trim().isEmpty
                        ? null
                        : Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _color,
                              shape: BoxShape.circle,
                            ),
                          ),
                    onTap: () => _openCategoryDialog(context),
                  ),
                ),
              ],
            ),

            if (_category.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _category = '';
                  _color = AppColors.accent;
                }),
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Убрать тег'),
              ),
            ],

            const SizedBox(height: 10),

            // Advanced section
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: _advanced,
                onExpansionChanged: (v) => setState(() => _advanced = v),
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Дополнительно',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                children: [
                  const SizedBox(height: 4),
                  _LabeledDropdown<int>(
                    label: 'Длительность',
                    value: _duration,
                    hint: 'Не указано',
                    items: const [15, 30, 45, 60, 90, 120, 180],
                    itemLabel: (m) => '$m минут',
                    icon: Icons.timer_rounded,
                    onChanged: (v) => setState(() => _duration = v),
                  ),
                  const SizedBox(height: 12),
                  _LabeledDropdown<int>(
                    label: 'Приоритет',
                    value: _priority,
                    hint: 'Не указано',
                    items: const [1, 2, 3, 4, 5],
                    itemLabel: (p) => 'Приоритет $p',
                    icon: Icons.flag_rounded,
                    onChanged: (v) => setState(() => _priority = v),
                  ),
                  const SizedBox(height: 6),
                  _LabeledDropdown<TaskRecurrenceType>(
                    label: 'Повторение',
                    value: _recurrenceType,
                    hint: 'Без повтора',
                    items: TaskRecurrenceType.values,
                    itemLabel: (value) {
                      switch (value) {
                        case TaskRecurrenceType.none:
                          return 'Без повтора';
                        case TaskRecurrenceType.daily:
                          return 'Каждый день';
                        case TaskRecurrenceType.weekly:
                          return 'Каждую неделю';
                        case TaskRecurrenceType.monthly:
                          return 'Каждый месяц';
                      }
                    },
                    icon: Icons.repeat_rounded,
                    onChanged: (v) => setState(
                      () => _recurrenceType = v ?? TaskRecurrenceType.none,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Save
            if (_saveError != null) ...[
              const SizedBox(height: 8),
              Text(
                'Не удалось сохранить задачу: $_saveError',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            ElevatedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () async {
                      final title = widget.titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text('Введите название задачи'),
                            ),
                          );
                        return;
                      }

                      setState(() {
                        _isSaving = true;
                        _saveError = null;
                      });
                      try {
                        await widget.onSave(
                          title: title,
                          date: _date,
                          category: _category,
                          color: _color,
                          duration: _duration,
                          estimatedDuration: _estimatedDuration,
                          breakdownSteps: _breakdownSteps,
                          priority: _priority,
                          recurrenceType: _recurrenceType,
                        );
                      } catch (error) {
                        if (mounted) {
                          setState(() => _saveError = error.toString());
                        }
                      } finally {
                        if (mounted) setState(() => _isSaving = false);
                      }
                    },
              icon: const Icon(Icons.check_rounded),
              label: Text(
                _isSaving
                    ? 'Сохраняю...'
                    : widget.isEdit
                    ? 'Сохранить'
                    : 'Создать',
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCategoryDialog(BuildContext context) async {
    final catCtrl = TextEditingController(text: _category);
    Color pickColor = _color;

    await showDialog<void>(
      context: context,
      builder: (dctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          title: const Text('Тег и цвет'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: catCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Название тега',
                    prefixIcon: Icon(Icons.sell_rounded),
                  ),
                ),
                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Цвет',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                StatefulBuilder(
                  builder: (_, setAlertState) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: Colors.primaries.map((c) {
                        final isSel = c == pickColor;
                        return InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => setAlertState(() => pickColor = c),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: isSel
                                  ? Border.all(width: 3, color: Colors.black)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _category = catCtrl.text.trim();
                  _color = pickColor;
                });
                Navigator.pop(dctx);
              },
              child: const Text('Готово'),
            ),
          ],
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.l),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.pageBg,
          borderRadius: BorderRadius.circular(AppRadii.l),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final String hint;
  final List<T> items;
  final String Function(T) itemLabel;
  final IconData icon;
  final ValueChanged<T?> onChanged;

  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.itemLabel,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(AppRadii.l),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    value: value,
                    isExpanded: true,
                    hint: Text(hint),
                    items: items
                        .map(
                          (x) => DropdownMenuItem<T>(
                            value: x,
                            child: Text(itemLabel(x)),
                          ),
                        )
                        .toList(),
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
