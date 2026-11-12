import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../state/app_state.dart';
import 'task_dialog.dart';

Future<void> showStepActionDialog(
  BuildContext context, {
  required Task parent,
  required String stepId,
}) async {
  final state = context.read<AppState>();
  final existing = state.actionForStep(parent.id, stepId);
  if (existing != null) {
    await showTaskDialog(context, task: existing);
    return;
  }
  final action = await showDialog<Task>(
    context: context,
    builder: (_) => _StepActionDialog(parent: parent, stepId: stepId),
  );
  if (action != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Действие создано. В корректировке плана нажмите «Добавить задачу».',
        ),
      ),
    );
  }
}

class _StepActionDialog extends StatefulWidget {
  final Task parent;
  final String stepId;

  const _StepActionDialog({required this.parent, required this.stepId});

  @override
  State<_StepActionDialog> createState() => _StepActionDialogState();
}

class _StepActionDialogState extends State<_StepActionDialog> {
  final _minutes = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final minutes = int.tryParse(_minutes.text.trim());
    if (minutes == null || minutes < 1 || minutes > AppState.maxPlanMinutes) {
      setState(() => _error = 'Введите длительность от 1 до 1440 минут.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final action = await context.read<AppState>().createActionFromStep(
        widget.parent,
        stepId: widget.stepId,
        estimatedDurationMinutes: minutes,
      );
      if (mounted) Navigator.pop(context, action);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Не удалось создать действие: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.parent.breakdownStepIds.indexOf(widget.stepId);
    return AlertDialog(
      title: const Text('Действие из шага'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              index < 0 ? 'Шаг удалён' : widget.parent.breakdownSteps[index],
            ),
            const SizedBox(height: 8),
            Text('Исходное дело: ${widget.parent.title}'),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('action-minutes'),
              controller: _minutes,
              autofocus: true,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Оценка действия, мин',
                helperText: 'Время только на этот шаг',
                errorText: _error,
                errorMaxLines: 3,
              ),
              onSubmitted: (_) => _saving ? null : _create(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _create,
          child: Text(_saving ? 'Создаю...' : 'Создать действие'),
        ),
      ],
    );
  }
}
