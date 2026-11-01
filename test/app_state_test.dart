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
          date: nextWeek,
        ),
        Task(
          id: 'Y',
          title: 'Task Y',
          durationMinutes: 30,
          priority: 10,
          date: tomorrow,
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
          date: farFuture,
        ),
        Task(
          id: 'Q',
          title: 'Task Q',
          durationMinutes: 30,
          priority: 9,
          date: farFuture,
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
          date: yesterday,
        ),
        Task(
          id: 'M',
          title: 'Normal Task',
          durationMinutes: 30,
          priority: 10,
          date: now.add(const Duration(days: 2)),
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
