// test/app_state_test.dart

import 'dart:io';
import 'package:flutter/material.dart';      // для Icons.*
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_application_1/models/task_list.dart';
import 'package:flutter_application_1/models/habit.dart';
import 'package:flutter_application_1/models/journal_entry.dart';
import 'package:flutter_application_1/models/achievement.dart';
import 'package:flutter_application_1/models/task.dart';
import 'package:flutter_application_1/state/app_state.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    // Инициализируем Hive в временной директории
    tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);

    // Регистрируем адаптеры
    Hive.registerAdapter(TaskListAdapter());
    Hive.registerAdapter(HabitAdapter());
    Hive.registerAdapter(JournalEntryAdapter());
    Hive.registerAdapter(AchievementAdapter());
    Hive.registerAdapter(AchievementTypeAdapter());
    Hive.registerAdapter(TaskAdapter());

    // Открываем боксы
    await Hive.openBox('settings');
    await Hive.openBox<Map>('day_plans');
    await Hive.openBox<Map>('analytics_events');
    await Hive.openBox<TaskList>('task_lists');
    await Hive.openBox<Habit>('habits');
    await Hive.openBox<JournalEntry>('journal_entries');
    await Hive.openBox<Achievement>('achievements');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('AppState.generatePlanForDay', () {
    final day = DateTime(2026, 11, 10);
    late AppState appState;

    setUp(() async {
      await Hive.box<TaskList>('task_lists').clear();
      await Hive.box<Map>('analytics_events').clear();
      appState = AppState();
    });

    tearDown(() => appState.dispose());

    test('considers undated tasks in Inbox and other lists', () async {
      final inboxTask = Task(id: 'inbox-task', title: 'Inbox task');
      final otherTask = Task(id: 'other-task', title: 'Other task');
      await appState.addTaskToInbox(inboxTask);
      await appState.addTask(otherTask, listId: 'home');
      appState.selectListById('important');

      final plan = appState.generatePlanForDay(day, 60);

      expect(
        plan['selectedTaskIds'],
        unorderedEquals([inboxTask.id, otherTask.id]),
      );
      expect(plan['usedMinutes'], 60);
      expect(inboxTask.date, isNull);
      expect(otherTask.date, isNull);
    });

    test('considers the selected day and unfinished earlier days', () {
      final plan = appState.generatePlanForDay(
        day,
        90,
        tasks: [
          Task(id: 'today', title: 'Today', date: DateTime(2026, 11, 10, 23)),
          Task(
            id: 'yesterday',
            title: 'Yesterday',
            date: DateTime(2026, 11, 9, 23),
          ),
          Task(
            id: 'last-month',
            title: 'Last month',
            date: DateTime(2026, 10, 1),
          ),
        ],
      );

      expect(
        plan['selectedTaskIds'],
        unorderedEquals(['today', 'yesterday', 'last-month']),
      );
    });

    test('excludes completed tasks from both selected and dropped tasks', () {
      final plan = appState.generatePlanForDay(
        day,
        30,
        tasks: [
          Task(id: 'done-undated', title: 'Done', isDone: true),
          Task(id: 'done-today', title: 'Done', date: day, isDone: true),
          Task(
            id: 'done-past',
            title: 'Done',
            date: DateTime(2026, 11, 9),
            isDone: true,
          ),
        ],
      );

      expect(plan['selectedTaskIds'], isEmpty);
      expect(plan['droppedTaskIds'], isEmpty);
      expect(plan['usedMinutes'], 0);
    });

    test(
      'does not pull future scheduled tasks forward, even with an urgent deadline',
      () {
        final futureDay = DateTime(2026, 11, 11);
        final futureTask = Task(id: 'future', title: 'Future', date: futureDay);
        final plan = appState.generatePlanForDay(
          day,
          120,
          tasks: [
            futureTask,
            Task(
              id: 'future-due-today',
              title: 'Future',
              date: futureDay,
              deadline: day,
            ),
            Task(
              id: 'future-overdue',
              title: 'Future',
              date: futureDay,
              deadline: DateTime(2026, 11, 9),
            ),
          ],
        );

        expect(plan['selectedTaskIds'], isEmpty);
        expect(plan['droppedTaskIds'], isEmpty);
        expect(futureTask.date, futureDay);
      },
    );

    for (final recurrence in [
      TaskRecurrenceType.daily,
      TaskRecurrenceType.weekly,
      TaskRecurrenceType.monthly,
    ]) {
      test('respects the ${recurrence.name} schedule and start day', () {
        final start = switch (recurrence) {
          TaskRecurrenceType.daily => DateTime(2026, 11, 9, 18),
          TaskRecurrenceType.weekly => DateTime(2026, 11, 3, 18),
          _ => DateTime(2026, 10, 10, 18),
        };
        final scheduled = Task(
          id: 'scheduled',
          title: 'Scheduled',
          date: start,
          recurrenceType: recurrence,
        );
        final startsToday = Task(
          id: 'starts-today',
          title: 'Starts today',
          date: DateTime(2026, 11, 10, 23),
          recurrenceType: recurrence,
        );
        final future = Task(
          id: 'future',
          title: 'Future',
          date: DateTime(2026, 11, 11),
          recurrenceType: recurrence,
          deadline: day,
        );
        final plan = appState.generatePlanForDay(
          day,
          120,
          tasks: [scheduled, startsToday, future],
        );

        expect(
          plan['selectedTaskIds'],
          unorderedEquals(['scheduled', 'starts-today']),
        );
      });
    }

    test('does not carry weekly or monthly tasks onto an unscheduled day', () {
      final plan = appState.generatePlanForDay(
        day,
        120,
        tasks: [
          Task(
            id: 'weekly',
            title: 'Weekly',
            date: DateTime(2026, 11, 9),
            recurrenceType: TaskRecurrenceType.weekly,
            deadline: day,
          ),
          Task(
            id: 'monthly',
            title: 'Monthly',
            date: DateTime(2026, 10, 9),
            recurrenceType: TaskRecurrenceType.monthly,
            deadline: day,
          ),
        ],
      );

      expect(plan['selectedTaskIds'], isEmpty);
      expect(plan['droppedTaskIds'], isEmpty);
    });

    test('a past planned date does not create deadline urgency', () {
      final plan = appState.generatePlanForDay(
        day,
        30,
        tasks: [
          Task(
            id: 'past',
            title: 'Past',
            date: DateTime(2026, 11, 1),
            priority: 1,
          ),
          Task(id: 'important', title: 'Important', priority: 5),
        ],
      );

      expect(plan['selectedTaskIds'], ['important']);
      expect(plan['droppedTaskIds'], ['past']);
    });

    test('uses the deadline for urgency, including an undated task', () {
      final plan = appState.generatePlanForDay(
        day,
        30,
        tasks: [
          Task(id: 'important', title: 'Important', priority: 5),
          Task(
            id: 'due',
            title: 'Due',
            priority: 1,
            deadline: DateTime(2026, 11, 10, 23),
          ),
        ],
      );

      expect(plan['selectedTaskIds'], ['due']);
    });

    test('compares deadline calendar days regardless of the plan time', () {
      final plan = appState.generatePlanForDay(
        DateTime(2026, 11, 10, 23),
        30,
        tasks: [
          Task(
            id: 'tomorrow',
            title: 'Tomorrow',
            priority: 5,
            deadline: DateTime(2026, 11, 11),
          ),
          Task(
            id: 'today',
            title: 'Today',
            priority: 1,
            deadline: DateTime(2026, 11, 10, 23),
          ),
        ],
      );

      expect(plan['selectedTaskIds'], ['today']);
    });

    test('an important 90-minute task beats two nonurgent 30-minute tasks', () {
      final plan = appState.generatePlanForDay(
        day,
        90,
        tasks: [
          Task(
            id: 'short-a',
            title: 'Short A',
            durationMinutes: 30,
            priority: 4,
          ),
          Task(
            id: 'short-b',
            title: 'Short B',
            durationMinutes: 30,
            priority: 4,
          ),
          Task(
            id: 'important',
            title: 'Important',
            durationMinutes: 90,
            priority: 5,
          ),
        ],
      );

      expect(plan['selectedTaskIds'], ['important']);
      expect(plan['droppedTaskIds'], unorderedEquals(['short-a', 'short-b']));
      expect(plan['usedMinutes'], 90);
    });

    test('shorter tasks break ties only after urgency and priority', () {
      final plan = appState.generatePlanForDay(
        day,
        60,
        tasks: [
          Task(id: 'long', title: 'Long', durationMinutes: 60, priority: 3),
          Task(id: 'short', title: 'Short', durationMinutes: 30, priority: 3),
        ],
      );

      expect(plan['selectedTaskIds'], ['short']);
      expect(plan['usedMinutes'], 30);
    });

    test(
      'respects the budget and continues after a task that does not fit',
      () {
        final tasks = [
          Task(
            id: 'too-long',
            title: 'Too long',
            durationMinutes: 120,
            priority: 5,
          ),
          Task(
            id: 'manual',
            title: 'Manual',
            durationMinutes: 45,
            estimatedDurationMinutes: 15,
            priority: 4,
          ),
          Task(
            id: 'estimated',
            title: 'Estimated',
            estimatedDurationMinutes: 30,
            priority: 3,
          ),
          Task(id: 'default', title: 'Default', priority: 2),
          Task(
            id: 'invalid-duration',
            title: 'Invalid duration',
            durationMinutes: -20,
            priority: 1,
          ),
        ];

        for (final budget in [0, 1, 15, 30, 60, 75, 90, 120]) {
          final plan = appState.generatePlanForDay(day, budget, tasks: tasks);
          final ids = (plan['selectedTaskIds'] as List).toSet();
          final used = tasks
              .where((task) => ids.contains(task.id))
              .fold<int>(
                0,
                (total, task) => total + task.effectiveDurationMinutes,
              );
          expect(plan['usedMinutes'], used, reason: 'Budget: $budget');
          expect(used, lessThanOrEqualTo(budget), reason: 'Budget: $budget');
        }

        final plan = appState.generatePlanForDay(day, 75, tasks: tasks);
        expect(plan['selectedTaskIds'], ['manual', 'estimated']);
        expect(plan['usedMinutes'], 75);
      },
    );

    test('rejects an invalid budget without logging a generated plan', () {
      for (final budget in [-1, AppState.maxPlanMinutes + 1]) {
        expect(
          () => appState.generatePlanForDay(day, budget),
          throwsRangeError,
        );
      }
      expect(appState.analyticsEvents, isEmpty);
    });
  });

  test(
    'persists the deadline separately from the planned date in Hive',
    () async {
      final plannedDate = DateTime(2026, 11, 10);
      final deadline = DateTime(2026, 11, 15);
      final task = Task(
        id: 'deadline-task',
        title: 'Deadline task',
        date: plannedDate,
        deadline: deadline,
      );
      final box = await Hive.openBox<Task>('deadline_tasks');
      await box.put(task.id, task);
      await box.close();

      final reopened = await Hive.openBox<Task>('deadline_tasks');
      final restored = reopened.get(task.id)!;
      expect(restored.date, plannedDate);
      expect(restored.deadline, deadline);
      final fromMap = Task.fromMap(restored.toMap());
      expect(fromMap.date, plannedDate);
      expect(fromMap.deadline, deadline);
      await reopened.close();
    },
  );

  group('AppState.optimizeSchedule', () {
    test('выбирает задачи с максимальной суммой приоритетов при отсутствии дедлайнов', () {
      final appState = AppState();
      final tasks = [
        Task(
          id: 'A',
          title: 'Task A',
          durationMinutes: 60,
          priority: 10,
          date: null,
        ),
        Task(
          id: 'B',
          title: 'Task B',
          durationMinutes: 30,
          priority: 6,
          date: null,
        ),
        Task(
          id: 'C',
          title: 'Task C',
          durationMinutes: 30,
          priority: 5,
          date: null,
        ),
      ];

      final result = appState.optimizeSchedule(tasks, 90);

      expect(result.length, 2);
      expect(result.map((t) => t.id).toSet(), {'A', 'B'});
    });

    test('учёт срочности: выбирает задачу с ближним дедлайном при равных приоритете и длительности', () {
      final appState = AppState();
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final nextWeek = now.add(const Duration(days: 7));

      final tasks = [
        Task(
          id: 'X',
          title: 'Task X',
          durationMinutes: 30,
          priority: 10,
          deadline: nextWeek,
        ),
        Task(
          id: 'Y',
          title: 'Task Y',
          durationMinutes: 30,
          priority: 10,
          deadline: tomorrow,
        ),
      ];

      final result = appState.optimizeSchedule(tasks, 30);

      expect(result.length, 1);
      expect(result.first.id, 'Y');
    });

    test('если дедлайны дальше 7 дней, срочность = 0 и выбирает по приоритету', () {
      final appState = AppState();
      final now = DateTime.now();
      final farFuture = now.add(const Duration(days: 30));

      final tasks = [
        Task(
          id: 'P',
          title: 'Task P',
          durationMinutes: 30,
          priority: 7,
          deadline: farFuture,
        ),
        Task(
          id: 'Q',
          title: 'Task Q',
          durationMinutes: 30,
          priority: 9,
          deadline: farFuture,
        ),
      ];

      final result = appState.optimizeSchedule(tasks, 30);
      expect(result.length, 1);
      expect(result.first.id, 'Q');
    });

    test('если дедлайн уже прошёл, срочность = 7 (максимум)', () {
      final appState = AppState();
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final tasks = [
        Task(
          id: 'L',
          title: 'Late Task',
          durationMinutes: 30,
          priority: 5,
          deadline: yesterday,
        ),
        Task(
          id: 'M',
          title: 'Normal Task',
          durationMinutes: 30,
          priority: 10,
          deadline: now.add(const Duration(days: 2)),
        ),
      ];

      final result = appState.optimizeSchedule(tasks, 30);
      expect(result.length, 1);
      expect(result.first.id, 'M');
    });
  });

  group('AppState.habitCurrentStreak', () {
    test('стрик из двух дней (сегодня и вчера)', () {
      final appState = AppState();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      final habit = Habit(
        id: 'h1',
        title: 'Test Habit',
        colorValue: 0xFF0000FF,
        iconCodePoint: Icons.check.codePoint,
        iconFontFamily: Icons.check.fontFamily ?? '',
      );
      habit.completedDates = [today, yesterday];

      final streak = appState.habitCurrentStreak(habit);
      expect(streak, 2);
    });

    test('пропуск вчера обрывает стрик (сегодня только 1)', () {
      final appState = AppState();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      final habit = Habit(
        id: 'h2',
        title: 'Test Habit 2',
        colorValue: 0xFF00FF00,
        iconCodePoint: Icons.star.codePoint,
        iconFontFamily: Icons.star.fontFamily ?? '',
      );
      habit.completedDates = [today, twoDaysAgo];

      final streak = appState.habitCurrentStreak(habit);
      expect(streak, 1);
    });

    test('никаких выполнений → стрик = 0', () {
      final appState = AppState();
      final habit = Habit(
        id: 'h3',
        title: 'Empty Habit',
        colorValue: 0xFFFF0000,
        iconCodePoint: Icons.close.codePoint,
        iconFontFamily: Icons.close.fontFamily ?? '',
      );
      habit.completedDates = [];

      final streak = appState.habitCurrentStreak(habit);
      expect(streak, 0);
    });
  });

  group('AppState.level и XP-логика', () {
    test('уровни растут согласно заданным порогам', () {
      final appState = AppState();

      appState.xpEarned = 0;
      expect(appState.level, 1);
      expect(appState.xpProgressInLevel, 0);
      expect(appState.xpToNextLevel, 25);

      appState.xpEarned = 10;
      expect(appState.level, 1);
      expect(appState.xpProgressInLevel, 10);
      expect(appState.xpToNextLevel, 15);

      appState.xpEarned = 25;
      expect(appState.level, 2);
      expect(appState.xpProgressInLevel, 0);
      expect(appState.xpToNextLevel, 50);

      appState.xpEarned = 25 + 50;
      expect(appState.level, 3);
      expect(appState.xpProgressInLevel, 0);
      expect(appState.xpToNextLevel, 75);

      appState.xpEarned = 25 + 50 + 75;
      expect(appState.level, 4);
      expect(appState.xpProgressInLevel, 0);
      expect(appState.xpToNextLevel, 100);

      appState.xpEarned = 25 + 50 + 75 + 100 * 2 + 40;
      expect(appState.level, 6);
      expect(appState.xpProgressInLevel, 40);
      expect(appState.xpToNextLevel, 60);
    });
  });
}
