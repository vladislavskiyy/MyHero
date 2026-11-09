import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/day_plan_review.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class DayPlanEditor extends StatefulWidget {
  final DateTime day;
  final bool showAcceptedTasks;

  const DayPlanEditor({
    super.key,
    required this.day,
    this.showAcceptedTasks = true,
  });

  @override
  State<DayPlanEditor> createState() => _DayPlanEditorState();
}

class _DayPlanEditorState extends State<DayPlanEditor> {
  final _minutesController = TextEditingController(text: '120');
  DateTime? _boundDay;
  int? _boundBudget;
  String? _minutesError;
  String? _saveError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBudget();
  }

  @override
  void didUpdateWidget(covariant DayPlanEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBudget();
  }

  void _syncBudget() {
    final state = context.read<AppState>();
    final plan =
        state.planDraftForDay(widget.day) ??
        state.acceptedPlanForDay(widget.day);
    final budget = plan?['availableMinutes'] as int? ?? 120;
    if (!DateUtils.isSameDay(_boundDay, widget.day) ||
        (plan != null && _minutesError == null && budget != _boundBudget)) {
      _minutesController.text = '$budget';
      _boundDay = DateUtils.dateOnly(widget.day);
      _boundBudget = budget;
      _minutesError = null;
      _saveError = null;
    }
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  int? _readMinutes() {
    final minutes = int.tryParse(_minutesController.text.trim());
    if (minutes == null || minutes < 1 || minutes > AppState.maxPlanMinutes) {
      setState(
        () => _minutesError =
            'Введите целое число минут от 1 до ${AppState.maxPlanMinutes}.',
      );
      return null;
    }
    setState(() => _minutesError = null);
    return minutes;
  }

  void _generate() {
    final minutes = _readMinutes();
    if (minutes == null) return;
    _boundBudget = minutes;
    context.read<AppState>().generatePlanDraft(widget.day, minutes);
    FocusScope.of(context).unfocus();
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final day = DateUtils.dateOnly(widget.day);
    final draft = state.planDraftForDay(day);
    if (draft == null || _readMinutes() == null) return;
    final review = state.reviewPlan(draft);
    if (!review.canAccept) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Принять план?'),
        content: Text(
          '${day.day}.${day.month}.${day.year}: ${review.entries.length} задач, '
          '${review.usedMinutes} мин из ${review.availableMinutes}. '
          'Этот список станет рабочим планом выбранного дня.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Принять план'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await state.acceptPlanDraft(day);
      if (!mounted) return;
      setState(() => _saveError = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('План принят и сохранён')));
    } catch (error) {
      if (mounted) {
        setState(() => _saveError = 'Не удалось принять план: $error');
      }
    }
  }

  Future<void> _addTask() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Consumer<AppState>(
        builder: (context, state, _) {
          final draft = state.planDraftForDay(widget.day);
          final remaining = draft == null
              ? []
              : state.remainingTasksForPlan(draft);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.6,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Добавить задачу в план',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (remaining.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Других подходящих задач пока нет.'),
                    ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final task in remaining)
                          ListTile(
                            key: ValueKey('plan-add-${task.id}'),
                            title: Text(task.title),
                            subtitle: Text(
                              '${task.effectiveDurationMinutes} мин',
                            ),
                            trailing: const Icon(Icons.add_rounded),
                            enabled: !state.isSavingPlan(widget.day),
                            onTap: () {
                              state.addTaskToPlan(widget.day, task.id);
                              Navigator.pop(sheetContext);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _entry(
    PlanTaskEntry entry,
    int index,
    int count,
    bool editable,
    bool busy,
  ) {
    final state = context.read<AppState>();
    return Container(
      key: ValueKey('plan-entry-${entry.id}'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: entry.isAvailable
              ? AppColors.border
              : Theme.of(context).colorScheme.error,
        ),
      ),
      child: Row(
        children: [
          Text('${index + 1}. '),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  entry.task == null
                      ? 'Удалена из списка задач'
                      : '${entry.durationMinutes} мин${entry.task!.isDone ? ' · выполнена' : ''}',
                ),
              ],
            ),
          ),
          if (editable) ...[
            IconButton(
              tooltip: 'Поднять: ${entry.title}',
              onPressed: busy || index == 0
                  ? null
                  : () => state.movePlanTask(widget.day, index, index - 1),
              icon: const Icon(Icons.arrow_upward_rounded, size: 20),
            ),
            IconButton(
              tooltip: 'Опустить: ${entry.title}',
              onPressed: busy || index == count - 1
                  ? null
                  : () => state.movePlanTask(widget.day, index, index + 1),
              icon: const Icon(Icons.arrow_downward_rounded, size: 20),
            ),
            IconButton(
              tooltip: 'Убрать из плана: ${entry.title}',
              onPressed: busy
                  ? null
                  : () => state.removeTaskFromPlan(widget.day, entry.id),
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final draft = state.planDraftForDay(widget.day);
    final accepted = state.acceptedPlanForDay(widget.day);
    final plan = draft ?? accepted;
    final review = plan == null ? null : state.reviewPlan(plan);
    final busy = state.isSavingPlan(widget.day);
    return Container(
      key: const ValueKey('day-plan-editor'),
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'План на день',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('plan-minutes'),
            controller: _minutesController,
            enabled: !busy,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Доступно минут',
              prefixIcon: const Icon(Icons.timer_rounded),
              errorText: _minutesError,
              errorMaxLines: 3,
            ),
            onChanged: (_) {
              final minutes = _readMinutes();
              if (minutes == null) return;
              _boundBudget = minutes;
              if (plan != null && plan['availableMinutes'] != minutes) {
                state.setPlanBudget(widget.day, minutes);
              }
            },
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: busy ? null : _generate,
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('Сгенерировать план'),
          ),
          if (review != null) ...[
            const SizedBox(height: 14),
            Text(
              draft != null ? 'Предложение — ещё не принято' : 'Принятый план',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              key: const ValueKey('plan-totals'),
              'Задач: ${review.entries.length} · ${review.usedMinutes} мин из ${review.availableMinutes}',
            ),
            Text(
              key: const ValueKey('plan-remaining'),
              review.isOverBudget
                  ? 'Превышение: ${-review.remainingMinutes} мин'
                  : 'Осталось: ${review.remainingMinutes} мин',
              style: TextStyle(
                color: review.isOverBudget
                    ? Theme.of(context).colorScheme.error
                    : AppColors.textMuted,
              ),
            ),
            if (review.hasChanges)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Исходные задачи изменились. Длительность пересчитана; проверьте и подтвердите план заново.',
                ),
              ),
            for (final message in review.blockingMessages)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (draft != null || widget.showAcceptedTasks)
              for (var i = 0; i < review.entries.length; i++)
                _entry(
                  review.entries[i],
                  i,
                  review.entries.length,
                  draft != null,
                  busy,
                ),
            if (draft != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: busy ? null : _addTask,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Добавить задачу'),
              ),
              ElevatedButton.icon(
                onPressed: busy || !review.canAccept || _minutesError != null
                    ? null
                    : _save,
                icon: const Icon(Icons.save_rounded),
                label: Text(busy ? 'Сохраняю...' : 'Сохранить'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => state.discardPlanDraft(widget.day),
                child: const Text('Отменить изменения'),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => state.editAcceptedPlan(widget.day),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Изменить план'),
              ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Сгенерируйте предложение, отредактируйте и примите его.',
              ),
            ),
          if (_saveError != null)
            Text(
              _saveError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
