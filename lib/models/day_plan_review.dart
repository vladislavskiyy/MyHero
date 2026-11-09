import 'task.dart';

class PlanTaskEntry {
  final String id;
  final Task? task;
  final String title;
  final int durationMinutes;
  final bool hasChanged;
  final bool isAvailable;

  const PlanTaskEntry({
    required this.id,
    required this.task,
    required this.title,
    required this.durationMinutes,
    required this.hasChanged,
    required this.isAvailable,
  });
}

class DayPlanReview {
  final List<PlanTaskEntry> entries;
  final int availableMinutes;
  final int? savedUsedMinutes;

  const DayPlanReview({
    required this.entries,
    required this.availableMinutes,
    this.savedUsedMinutes,
  });

  int get usedMinutes =>
      entries.fold(0, (sum, entry) => sum + entry.durationMinutes);
  int get remainingMinutes => availableMinutes - usedMinutes;
  bool get isOverBudget => remainingMinutes < 0;
  bool get hasChanges =>
      entries.any((entry) => entry.hasChanged) ||
      (savedUsedMinutes != null && savedUsedMinutes != usedMinutes);

  List<String> get blockingMessages => [
    if (isOverBudget)
      'Превышение бюджета на ${-remainingMinutes} мин. Уберите задачу или увеличьте доступное время.',
    for (final entry in entries)
      if (entry.task == null)
        'Задача «${entry.title}» удалена. Уберите её из плана.'
      else if (!entry.isAvailable)
        'Задача «${entry.title}» больше не подходит этому дню. Уберите её из плана.',
  ];

  bool get canAccept => blockingMessages.isEmpty;
}
