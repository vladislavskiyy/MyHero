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
  final selectedDeadline = task?.deadline;

  String category = task?.category ?? '';
  Color selectedColor = task?.color ?? AppColors.accent;

  int? durationMinutes = task?.durationMinutes;
  final estimatedDurationMinutes = task?.estimatedDurationMinutes;
  final breakdownSteps = task?.breakdownSteps ?? <String>[];
  final breakdownStepIds = task?.breakdownStepIds ?? <String>[];
  final appState = context.read<AppState>();
  final linkedStepIds = {
    for (final id in breakdownStepIds)
      if (task != null && appState.actionForStep(task.id, id) != null) id,
  };
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
            initialDeadline: selectedDeadline,
            initialCategory: category,
            initialColor: selectedColor,
            initialDuration: durationMinutes,
            initialEstimatedDuration: estimatedDurationMinutes,
            initialBreakdownSteps: breakdownSteps,
            initialBreakdownStepIds: breakdownStepIds,
            linkedStepIds: linkedStepIds,
            initialPriority: priority,
            initialRecurrenceType: recurrenceType,
            onSave:
                ({
                  required String title,
                  required DateTime? date,
                  required DateTime? deadline,
                  required String category,
                  required Color color,
                  required int? duration,
                  required int? estimatedDuration,
                  required List<String> breakdownSteps,
                  required List<String> breakdownStepIds,
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
                      ..deadline = deadline
                      ..category = catToSave
                      ..color = colorToSave
                      ..durationMinutes = duration
                      ..estimatedDurationMinutes = estimatedDuration
                      ..breakdownSteps = breakdownSteps
                      ..breakdownStepIds = breakdownStepIds
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
                        deadline: deadline,
                        category: catToSave,
                        color: colorToSave,
                        durationMinutes: duration,
                        estimatedDurationMinutes: estimatedDuration,
                        breakdownSteps: breakdownSteps,
                        breakdownStepIds: breakdownStepIds,
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
  final DateTime? initialDeadline;
  final String initialCategory;
  final Color initialColor;
  final int? initialDuration;
  final int? initialEstimatedDuration;
  final List<String> initialBreakdownSteps;
  final List<String> initialBreakdownStepIds;
  final Set<String> linkedStepIds;
  final int? initialPriority;
  final TaskRecurrenceType initialRecurrenceType;

  final Future<void> Function({
    required String title,
    required DateTime? date,
    required DateTime? deadline,
    required String category,
    required Color color,
    required int? duration,
    required int? estimatedDuration,
    required List<String> breakdownSteps,
    required List<String> breakdownStepIds,
    required int? priority,
    required TaskRecurrenceType recurrenceType,
  })
  onSave;

  const _TaskSheet({
    required this.isEdit,
    required this.titleController,
    required this.initialDate,
    required this.initialDeadline,
    required this.initialCategory,
    required this.initialColor,
    required this.initialDuration,
    required this.initialEstimatedDuration,
    required this.initialBreakdownSteps,
    required this.initialBreakdownStepIds,
    required this.linkedStepIds,
    required this.initialPriority,
    required this.initialRecurrenceType,
    required this.onSave,
  });

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  late DateTime? _date = widget.initialDate;
  late DateTime? _deadline = widget.initialDeadline;
  late String _category = widget.initialCategory;
  late Color _color = widget.initialColor;
  late int? _duration = widget.initialDuration;
  late int? _estimatedDuration = widget.initialEstimatedDuration;
  late List<String> _breakdownSteps = List.of(widget.initialBreakdownSteps);
  late List<String> _breakdownStepIds = List.of(widget.initialBreakdownStepIds);
  late bool _hasBreakdown = widget.initialBreakdownSteps.isNotEmpty;
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
        _hasBreakdown = true;
        final oldSteps = _breakdownSteps;
        final oldIds = _breakdownStepIds;
        final used = <int>{};
        _breakdownSteps = [];
        _breakdownStepIds = [];
        for (final step in suggestion.steps) {
          final index = oldSteps.asMap().keys.firstWhere(
            (i) => !used.contains(i) && oldSteps[i].trim() == step.trim(),
            orElse: () => -1,
          );
          _breakdownSteps.add(step);
          _breakdownStepIds.add(
            index < 0 ? Task.newBreakdownStepId() : oldIds[index],
          );
          if (index >= 0) used.add(index);
        }
        // Regeneration must not silently discard steps that already have actions.
        for (var i = 0; i < oldSteps.length; i++) {
          if (widget.linkedStepIds.contains(oldIds[i]) && !used.contains(i)) {
            _breakdownSteps.add(oldSteps[i]);
            _breakdownStepIds.add(oldIds[i]);
          }
        }
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

  String _formatDate(DateTime? d, String emptyText) {
    if (d == null) return emptyText;
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
              onPressed: !isAiSupported || _isGeneratingSuggestion || _isSaving
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
            if (_estimatedDuration != null || _hasBreakdown) ...[
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
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  key: ValueKey(
                                    'breakdown-${_breakdownStepIds[i]}',
                                  ),
                                  initialValue: _breakdownSteps[i],
                                  enabled:
                                      !_isSaving && !_isGeneratingSuggestion,
                                  minLines: 1,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    labelText: 'Шаг ${i + 1}',
                                    helperText:
                                        widget.linkedStepIds.contains(
                                          _breakdownStepIds[i],
                                        )
                                        ? 'Действие уже создано'
                                        : null,
                                  ),
                                  onChanged: (text) =>
                                      _breakdownSteps[i] = text,
                                ),
                              ),
                              IconButton(
                                tooltip:
                                    widget.linkedStepIds.contains(
                                      _breakdownStepIds[i],
                                    )
                                    ? 'Сначала удалите связанное действие'
                                    : 'Удалить шаг ${i + 1}',
                                onPressed:
                                    _isSaving ||
                                        _isGeneratingSuggestion ||
                                        widget.linkedStepIds.contains(
                                          _breakdownStepIds[i],
                                        )
                                    ? null
                                    : () => setState(() {
                                        _breakdownSteps.removeAt(i);
                                        _breakdownStepIds.removeAt(i);
                                      }),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                    ],
                    TextButton.icon(
                      onPressed: _isSaving || _isGeneratingSuggestion
                          ? null
                          : () => setState(() {
                              _breakdownSteps.add('');
                              _breakdownStepIds.add(Task.newBreakdownStepId());
                            }),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Добавить шаг'),
                    ),
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
                    title: 'Запланировано на',
                    value: _formatDate(_date, 'Без даты'),
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

            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.event_busy_rounded,
              title: 'Дедлайн',
              value: _formatDate(_deadline, 'Не задан'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _deadline ?? _date ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) setState(() => _deadline = picked);
              },
            ),
            const SizedBox(height: 6),
            const Text(
              'Дата планирования — когда заняться задачей. '
              'Дедлайн — крайний срок; он определяет срочность в автоплане.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            if (_date != null || _deadline != null)
              Wrap(
                spacing: 12,
                children: [
                  if (_date != null)
                    TextButton.icon(
                      onPressed: () => setState(() => _date = null),
                      icon: const Icon(Icons.clear_rounded),
                      label: const Text('Убрать дату планирования'),
                    ),
                  if (_deadline != null)
                    TextButton.icon(
                      onPressed: () => setState(() => _deadline = null),
                      icon: const Icon(Icons.clear_rounded),
                      label: const Text('Убрать дедлайн'),
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
              child: Material(
                type: MaterialType.transparency,
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
              onPressed: _isSaving || _isGeneratingSuggestion
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

                      if (_breakdownSteps.any((step) => step.trim().isEmpty)) {
                        setState(
                          () =>
                              _saveError = 'Заполните или удалите пустые шаги.',
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
                          deadline: _deadline,
                          category: _category,
                          color: _color,
                          duration: _duration,
                          estimatedDuration: _estimatedDuration,
                          breakdownSteps: _breakdownSteps
                              .map((step) => step.trim())
                              .toList(),
                          breakdownStepIds: List.of(_breakdownStepIds),
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
