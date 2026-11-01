// lib/state/app_state.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/task.dart';
import '../models/task_list.dart';
import '../models/achievement.dart';
import '../models/habit.dart';
import '../models/journal_entry.dart';

class AppState extends ChangeNotifier {
  final Box _settingsBox = Hive.box('settings');
  final Box<Map> _dayPlansBox = Hive.box<Map>('day_plans');
  final Box<Map> _analyticsBox = Hive.box<Map>('analytics_events');
  final Box<TaskList> _listsBox = Hive.box<TaskList>('task_lists');
  final Box<Habit> _habitsBox = Hive.box<Habit>('habits');
  final Box<JournalEntry> _journalBox = Hive.box<JournalEntry>('journal_entries');
  final Box<Achievement> _achBox = Hive.box<Achievement>('achievements');

  // ===== XP и внутренняя валюта =====
  late int xpEarned;
  late int xpSpent;
  late int coins;

  late bool isDarkMode;
  late bool notificationsEnabled;

  final Set<String> purchasedItemIds = {};

  final List<TaskList> lists = [];
  int selectedListIndex = 0;

  final List<Habit> habits = [];
  final List<JournalEntry> journalEntries = [];
  final List<Achievement> achievements = [];

  String? currentUser;

  AppState({this.currentUser}) {
    xpEarned = _settingsBox.get('xpEarned', defaultValue: 0) as int;
    xpSpent = _settingsBox.get('xpSpent', defaultValue: 0) as int;
    coins = _settingsBox.get('coins', defaultValue: 0) as int;
    isDarkMode = _settingsBox.get('isDarkMode', defaultValue: false) as bool;
    notificationsEnabled = _settingsBox.get('notificationsEnabled', defaultValue: true) as bool;

    _loadSettings();
    _loadFromHive();
    applyDailyHabitPenalties();
  }

  // ================== Daily plan / analytics ==================

  List<Map<String, dynamic>> get savedPlans {
    final plans = _dayPlansBox.values
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    plans.sort((a, b) {
      final aDate = DateTime.tryParse((a['date'] as String? ?? '1970-01-01')) ?? DateTime(1970);
      final bDate = DateTime.tryParse((b['date'] as String? ?? '1970-01-01')) ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });
    return plans;
  }

  List<Map<String, dynamic>> get analyticsEvents {
    final events = _analyticsBox.values
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    events.sort((a, b) {
      final aTime = DateTime.tryParse((a['timestamp'] as String? ?? '1970-01-01T00:00:00.000')) ?? DateTime(1970);
      final bTime = DateTime.tryParse((b['timestamp'] as String? ?? '1970-01-01T00:00:00.000')) ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });
    return events;
  }

  void logAnalyticsEvent(String type, Map<String, dynamic> payload) {
    final event = <String, dynamic>{
      'id': '${DateTime.now().millisecondsSinceEpoch}',
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
      ...payload,
    };
    _analyticsBox.add(event);
    notifyListeners();
  }

  String exportAnalyticsJson() {
    final data = analyticsEvents;
    return jsonEncode(data);
  }

  Map<String, dynamic> generatePlanForDay(
    DateTime day,
    int availableMinutes, {
    List<Task>? tasks,
    String? notes,
  }) {
    final candidates = (tasks ?? lists.expand((list) => list.tasks).toList())
        .where((task) => !task.isDone && task.date != null)
        .where((task) => task.appearsOn(day) || (task.deadline != null && DateUtils.isSameDay(task.deadline!, day)))
        .toList();

    int urgencyScore(Task task) {
      final deadline = task.deadline ?? task.date;
      if (deadline == null) return 0;
      final diffDays = deadline.difference(DateTime(day.year, day.month, day.day)).inDays;
      if (diffDays <= 0) return 100;
      if (diffDays <= 1) return 80;
      if (diffDays <= 3) return 60;
      if (diffDays <= 7) return 30;
      return 0;
    }

    final sorted = [...candidates]
      ..sort((a, b) {
        final aScore = (a.priority ?? 0) + urgencyScore(a) + (a.effectiveDurationMinutes < 45 ? 10 : 0);
        final bScore = (b.priority ?? 0) + urgencyScore(b) + (b.effectiveDurationMinutes < 45 ? 10 : 0);
        final score = bScore.compareTo(aScore);
        if (score != 0) return score;
        return a.effectiveDurationMinutes.compareTo(b.effectiveDurationMinutes);
      });

    final selected = <Task>[];
    int used = 0;
    for (final task in sorted) {
      final taskMinutes = task.effectiveDurationMinutes;
      if (used + taskMinutes <= availableMinutes) {
        selected.add(task);
        used += taskMinutes;
      }
    }

    final selectedIds = selected.map((task) => task.id).toList();
    final dropped = sorted.where((task) => !selectedIds.contains(task.id)).toList();

    final plan = <String, dynamic>{
      'id': 'plan_${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}_${DateTime.now().millisecondsSinceEpoch}',
      'date': day.toIso8601String(),
      'availableMinutes': availableMinutes,
      'usedMinutes': used,
      'generatedAt': DateTime.now().toIso8601String(),
      'selectedTaskIds': selectedIds,
      'selectedTitles': selected.map((task) => task.title).toList(),
      'droppedTaskIds': dropped.map((task) => task.id).toList(),
      'droppedTitles': dropped.map((task) => task.title).toList(),
      'status': 'proposed',
      'notes': notes ?? 'Автоподбор задач по доступному времени',
      'algorithmVersion': 'knapsack-v1',
    };

    logAnalyticsEvent('plan_generated', {
      'date': day.toIso8601String(),
      'availableMinutes': availableMinutes,
      'selectedCount': selected.length,
      'droppedCount': dropped.length,
      'usedMinutes': used,
    });

    return plan;
  }

  Future<void> savePlan(Map<String, dynamic> plan) async {
    final normalized = Map<String, dynamic>.from(plan)
      ..['status'] = 'saved'
      ..['savedAt'] = DateTime.now().toIso8601String();
    final id = normalized['id'] as String? ?? 'plan_${DateTime.now().millisecondsSinceEpoch}';
    normalized['id'] = id;
    await _dayPlansBox.put(id, normalized);
    logAnalyticsEvent('plan_saved', {
      'date': normalized['date'] ?? '',
      'availableMinutes': normalized['availableMinutes'] ?? 0,
      'selectedCount': (normalized['selectedTaskIds'] as List? ?? []).length,
    });
    notifyListeners();
  }

  Future<void> savePlanForDay(
    DateTime day,
    int availableMinutes, {
    required List<Task> plannedTasks,
    List<Task> droppedTasks = const [],
    String? notes,
  }) async {
    final plan = generatePlanForDay(day, availableMinutes,
        tasks: [...plannedTasks, ...droppedTasks], notes: notes);
    final finalSelected = plannedTasks.map((task) => task.id).toList();
    final finalDropped = droppedTasks.map((task) => task.id).toList();

    final saved = Map<String, dynamic>.from(plan)
      ..['selectedTaskIds'] = finalSelected
      ..['selectedTitles'] = plannedTasks.map((task) => task.title).toList()
      ..['droppedTaskIds'] = finalDropped
      ..['droppedTitles'] = droppedTasks.map((task) => task.title).toList();

    await savePlan(saved);
  }

  List<Task> tasksForPlan(Map<String, dynamic> plan) {
    final ids = (plan['selectedTaskIds'] as List? ?? [])
        .whereType<String>()
        .toSet();
    final tasks = <Task>[];
    for (final list in lists) {
      for (final task in list.tasks) {
        if (ids.contains(task.id)) {
          tasks.add(task);
        }
      }
    }
    return tasks;
  }

  bool get isLoggedIn => currentUser != null;

  void setUser(String? login) {
    currentUser = login;
    _loadSettings();
    notifyListeners();
  }

  void addXp(int amount) {
    xpEarned += amount;
    _settingsBox.put('xpEarned', xpEarned);
    _checkAchievements();
    notifyListeners();
  }

  String _prefixed(String key) {
    final prefix = currentUser ?? 'guest';
    return '${prefix}_$key';
  }

  void _loadSettings() {
    xpEarned = _settingsBox.get(_prefixed('xpEarned'), defaultValue: 0) as int;
    xpSpent = _settingsBox.get(_prefixed('xpSpent'), defaultValue: 0) as int;
    coins = _settingsBox.get(_prefixed('coins'), defaultValue: 0) as int;
    isDarkMode = _settingsBox.get(_prefixed('isDarkMode'), defaultValue: false) as bool;
    notificationsEnabled = _settingsBox.get(_prefixed('notificationsEnabled'), defaultValue: true) as bool;
  }

  void _saveSettings() {
    _settingsBox.put(_prefixed('xpEarned'), xpEarned);
    _settingsBox.put(_prefixed('xpSpent'), xpSpent);
    _settingsBox.put(_prefixed('coins'), coins);
    _settingsBox.put(_prefixed('isDarkMode'), isDarkMode);
    _settingsBox.put(_prefixed('notificationsEnabled'), notificationsEnabled);
  }

  void toggleDarkMode(bool value) {
    isDarkMode = value;
    _settingsBox.put(_prefixed('isDarkMode'), value);
    notifyListeners();
  }

  void toggleNotifications(bool value) {
    notificationsEnabled = value;
    _settingsBox.put(_prefixed('notificationsEnabled'), value);
    notifyListeners();
  }

  // ================== Inbox helpers ==================
  static const String inboxId = 'inbox';

  TaskList get inboxList {
    for (final l in lists) {
      if (l.id == inboxId) return l;
    }
    // На всякий случай (если вызвали до _loadFromHive)
    final fallback = TaskList(id: inboxId, name: 'Inbox', color: Colors.deepPurple);
    return fallback;
  }

  void selectListById(String id) {
    for (int i = 0; i < lists.length; i++) {
      if (lists[i].id == id) {
        selectedListIndex = i;
        notifyListeners();
        return;
      }
    }
  }

  TaskList _listContainingTask(Task t) {
    // ищем по id (надежнее, чем по ссылке на объект)
    for (final l in lists) {
      if (l.tasks.any((x) => x.id == t.id)) return l;
    }
    return currentList;
  }


  void _loadFromHive() {
    lists
      ..clear()
      ..addAll(_listsBox.values);

    // 1) гарантируем Inbox
    final hasInbox = lists.any((l) => l.id == inboxId);
    if (!hasInbox) {
      final inbox = TaskList(id: inboxId, name: 'Inbox', color: Colors.deepPurple);
      _listsBox.put(inbox.id, inbox);
      lists.insert(0, inbox);
    }

    // 2) дефолтные списки (если только inbox есть или пусто)
    if (lists.length == 1 && lists.first.id == inboxId) {
      final defaults = [
        TaskList(id: 'my_day', name: 'Мой день', color: Colors.blue),
        TaskList(id: 'important', name: 'Важно', color: Colors.red),
        TaskList(id: 'home', name: 'Дом', color: Colors.green),
      ];
      for (var l in defaults) {
        _listsBox.put(l.id, l);
        lists.add(l);
      }
    }

    // selectedListIndex в безопасный диапазон
    if (selectedListIndex < 0 || selectedListIndex >= lists.length) {
      selectedListIndex = 0;
    }

    habits
      ..clear()
      ..addAll(_habitsBox.values);

    journalEntries
      ..clear()
      ..addAll(_journalBox.values);

    achievements
      ..clear()
      ..addAll(_achBox.values);

    if (achievements.isEmpty) {
      final defaults = [
        Achievement(
          id: 'first_task',
          title: 'Первая задача',
          description: 'Закройте вашу первую задачу',
          type: AchievementType.tasks,
          requiredCount: 1,
        ),
        Achievement(
          id: 'ten_tasks',
          title: 'Десятка',
          description: 'Закройте 10 задач',
          type: AchievementType.tasks,
          requiredCount: 10,
        ),
        Achievement(
          id: 'habit_3_days',
          title: 'Первые искры',
          description: 'Выдержи 3 дня подряд одну привычку',
          type: AchievementType.habitStreak,
          requiredHabitStreak: 3,
        ),
        Achievement(
          id: 'habit_7_days',
          title: 'Недельный мастер',
          description: 'Выдержи 7 дней подряд одну привычку',
          type: AchievementType.habitStreak,
          requiredHabitStreak: 7,
        ),
        Achievement(
          id: 'habit_30_days',
          title: 'Месячный стойкий',
          description: 'Выдержи 30 дней подряд одну привычку',
          type: AchievementType.habitStreak,
          requiredHabitStreak: 30,
        ),
        Achievement(
          id: 'reach_level_2',
          title: 'Подъём на 2-й',
          description: 'Достигните 2-го уровня',
          type: AchievementType.level,
          requiredLevel: 2,
        ),
        Achievement(
          id: 'reach_level_5',
          title: 'Пятизвёздочник',
          description: 'Достигните 5-го уровня',
          type: AchievementType.level,
          requiredLevel: 5,
        ),
        Achievement(
          id: 'reach_level_10',
          title: 'Десятка',
          description: 'Достигните 10-го уровня',
          type: AchievementType.level,
          requiredLevel: 10,
        ),
      ];
      for (var a in defaults) {
        _achBox.put(a.id, a);
        achievements.add(a);
      }
    }

    notifyListeners();
  }

  // ================== Задачи ==================

  TaskList get currentList => lists[selectedListIndex];

  void selectList(int i) {
    if (i >= 0 && i < lists.length) {
      selectedListIndex = i;
      notifyListeners();
    }
  }

  Future<void> addList(String name, Color color) async {
    final newList = TaskList(
      id: DateTime.now().toIso8601String(),
      name: name,
      color: color,
    );
    await _listsBox.put(newList.id, newList);
    lists.add(newList);
    selectedListIndex = lists.length - 1;
    notifyListeners();
  }

  Future<void> renameList(int i, String name, Color color) async {
    final list = lists[i];
    list.name = name;
    list.color = color;
    await _listsBox.put(list.id, list);
    notifyListeners();
  }

  Future<void> deleteList(int i) async {
    final list = lists.removeAt(i);
    await _listsBox.delete(list.id);
    if (selectedListIndex >= lists.length) selectedListIndex = max(0, lists.length - 1);
    notifyListeners();
  }

  Future<void> addTask(Task t, {String? listId}) async {
    TaskList target = currentList;
    if (listId != null) {
      for (final l in lists) {
        if (l.id == listId) {
          target = l;
          break;
        }
      }
    }
    target.tasks.insert(0, t);
    await _listsBox.put(target.id, target);
    notifyListeners();
  }

  Future<void> addTaskToInbox(Task t) => addTask(t, listId: inboxId);

  Future<void> updateTask(
    Task t, {
    required String title,
    DateTime? date,
    String? category,
    Color? color,
  }) async {
    t.title = title;
    t.date = date;
    t.category = category;
    t.color = color;

    final list = _listContainingTask(t);
    await _listsBox.put(list.id, list);
    notifyListeners();
  }

  Future<void> deleteTask(Task t) async {
    final list = _listContainingTask(t);
    list.tasks.removeWhere((x) => x.id == t.id);
    await _listsBox.put(list.id, list);
    notifyListeners();
  }

  Future<void> toggleDone(Task t, bool? done) async {
    final wasDone = t.isDone;
    final isDone = done ?? false;

    if (!wasDone && isDone) {
      xpEarned += 5;
    } else if (wasDone && !isDone) {
      xpEarned = max(xpEarned - 5, 0);
    }

    _saveSettings();
    t.isDone = isDone;
    _checkAchievements();

    final list = _listContainingTask(t);
    await _listsBox.put(list.id, list);
    notifyListeners();
  }

  List<Task> get pending => currentList.tasks.where((t) => !t.isDone).toList();
  List<Task> get completed => currentList.tasks.where((t) => t.isDone).toList();

  List<Task> tasksForDay(DateTime day) =>
      currentList.tasks.where((t) => t.date != null && isSameDay(t.date!, day)).toList();

  int get totalCompleted => lists.fold<int>(
        0,
        (sum, l) => sum + l.tasks.where((t) => t.isDone).length,
      );

  // ================== Достижения ==================

  void _checkAchievements() {
    for (var a in achievements) {
      if (a.isUnlocked) continue;
      switch (a.type) {
        case AchievementType.tasks:
          if (a.requiredCount != null && totalCompleted >= a.requiredCount!) {
            a.isUnlocked = true;
            _achBox.put(a.id, a);
          }
          break;
        case AchievementType.habitStreak:
          if (a.requiredHabitStreak != null &&
              habits.any((h) => _calculateStreak(h, DateTime.now()) >= a.requiredHabitStreak!)) {
            a.isUnlocked = true;
            _achBox.put(a.id, a);
          }
          break;
        case AchievementType.level:
          if (a.requiredLevel != null && level >= a.requiredLevel!) {
            a.isUnlocked = true;
            _achBox.put(a.id, a);
          }
          break;
      }
    }
  }

  // ================== XP и уровни ==================

  int get xpBalance => xpEarned - xpSpent;

  int get xpInLevel {
    int xp = xpEarned;
    if (xp < 25) return xp;
    xp -= 25;
    if (xp < 50) return xp;
    xp -= 50;
    if (xp < 75) return xp;
    xp -= 75;
    return xp % 100;
  }

  int get level {
    int xp = xpEarned;
    if (xp < 25) return 1;
    xp -= 25;
    if (xp < 50) return 2;
    xp -= 50;
    if (xp < 75) return 3;
    xp -= 75;
    return 4 + (xp ~/ 100);
  }

  int get xpRequiredForNextLevel {
    switch (level) {
      case 1:
        return 25;
      case 2:
        return 50;
      case 3:
        return 75;
      default:
        return 100;
    }
  }

  int get xpProgressInLevel {
    final int xpBefore;
    switch (level) {
      case 1:
        xpBefore = 0;
        break;
      case 2:
        xpBefore = 25;
        break;
      case 3:
        xpBefore = 25 + 50;
        break;
      case 4:
        xpBefore = 25 + 50 + 75;
        break;
      default:
        xpBefore = 25 + 50 + 75 + 100 * (level - 4);
    }
    return xpEarned - xpBefore;
  }

  int get xpToNextLevel {
    switch (level) {
      case 1:
        return 25 - xpInLevel;
      case 2:
        return 50 - xpInLevel;
      case 3:
        return 75 - xpInLevel;
      default:
        return 100 - xpInLevel;
    }
  }

  bool exchangeXpForCoins(int coinCount) {
    final cost = coinCount * 10;
    if (xpBalance < cost) return false;
    xpSpent += cost;
    coins += coinCount;
    _saveSettings();
    notifyListeners();
    return true;
  }

  bool purchaseItem(String id, int price) {
    if (coins < price || purchasedItemIds.contains(id)) return false;
    coins -= price;
    purchasedItemIds.add(id);
    _saveSettings();
    notifyListeners();
    return true;
  }

  bool isPurchased(String id) => purchasedItemIds.contains(id);

  // ================== Трекер привычек ==================

  Future<void> addHabit(Habit h) async {
    h.lives = 3;
    h.lastMissCheck = null;
    await _habitsBox.put(h.id, h);
    habits.add(h);
    notifyListeners();
  }

  Future<void> updateHabit(Habit h, {required String title, Color? color, IconData? icon}) async {
    h.title = title;
    if (color != null) h.color = color;
    if (icon != null) h.icon = icon;
    await _habitsBox.put(h.id, h);
    notifyListeners();
  }

  Future<void> deleteHabit(Habit h) async {
    habits.remove(h);
    await _habitsBox.delete(h.id);
    notifyListeners();
  }

  void applyDailyHabitPenalties() {
    final today = DateTime.now();
    final yesterday =
        DateTime(today.year, today.month, today.day).subtract(const Duration(days: 1));

    for (var h in habits) {
      if (h.lastMissCheck == null || !isSameDay(h.lastMissCheck!, today)) {
        if (!h.isDoneOn(yesterday)) {
          h.lives = max(h.lives - 1, 0);
          if (h.lives == 0) {
            xpEarned = 0;
            _settingsBox.put('xpEarned', xpEarned);
            h.lives = 3;
          }
        }
        h.lastMissCheck = today;
        _habitsBox.put(h.id, h);
      }
    }
    notifyListeners();
  }

  Future<void> toggleHabitDay(Habit h, DateTime day) async {
    final today = DateTime.now();
    final targetDay = DateTime(day.year, day.month, day.day);
    final wasDone = h.isDoneOn(targetDay);

    h.toggleDay(targetDay);

    if (isSameDay(targetDay, today)) {
      final nowDone = h.isDoneOn(targetDay);
      if (!wasDone && nowDone) {
        xpEarned += 2;
        _saveSettings();
        final streak = _calculateStreak(h, targetDay);
        if (streak > 0 && streak % 7 == 0) {
          coins += 1;
          _saveSettings();
        }
      } else if (wasDone && !nowDone) {
        xpEarned = max(xpEarned - 2, 0);
        _saveSettings();
      }
    }

    await _habitsBox.put(h.id, h);
    notifyListeners();
  }

  int _calculateStreak(Habit h, DateTime fromDay) {
    int count = 0;
    var d = DateTime(fromDay.year, fromDay.month, fromDay.day);
    while (h.isDoneOn(d)) {
      count++;
      d = d.subtract(const Duration(days: 1));
    }
    return count;
  }

  int habitCurrentStreak(Habit h) => _calculateStreak(h, DateTime.now());

  int habitCountThisMonth(Habit h) {
    final now = DateTime.now();
    return h.completedDates.where((d) => d.year == now.year && d.month == now.month).length;
  }

  // ================== Личный дневник ==================

  Future<void> addJournalEntry(JournalEntry entry) async {
    journalEntries.insert(0, entry);
    xpEarned += 3;
    _saveSettings();
    await _journalBox.put(entry.id, entry);
    notifyListeners();
  }

  Future<void> updateJournalEntry(JournalEntry entry,
      {required String title, required String content}) async {
    entry.title = title;
    entry.content = content;
    await _journalBox.put(entry.id, entry);
    notifyListeners();
  }

  Future<void> deleteJournalEntry(JournalEntry entry) async {
    journalEntries.remove(entry);
    await _journalBox.delete(entry.id);
    notifyListeners();
  }

  int completedCountOn(DateTime day) => lists
      .expand((l) => l.tasks)
      .where((t) => t.isDone && t.date != null && isSameDay(t.date!, day))
      .length;

  double averagePerDay() {
    final today = DateTime.now();
    final total = List.generate(7, (i) {
      final d = today.subtract(Duration(days: i));
      return completedCountOn(d);
    }).fold<int>(0, (sum, v) => sum + v);
    return total / 7.0;
  }

  int maxStreakThisWeek() {
    final today = DateTime.now();
    int streak = 0, maxStreak = 0;
    for (int i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      if (completedCountOn(d) > 0) {
        streak++;
        maxStreak = max(streak, maxStreak);
      } else {
        streak = 0;
      }
    }
    return maxStreak;
  }

  List<Task> optimizeSchedule(List<Task> tasks, int capacityMinutes) {
    final available = tasks
        .where((t) => !t.isDone && t.durationMinutes != null && t.durationMinutes! > 0)
        .toList();

    int calculateUrgency(DateTime? date) {
      if (date == null) return 0;
      final today = DateTime.now();
      final dDay = DateTime(date.year, date.month, date.day);
      final tDay = DateTime(today.year, today.month, today.day);
      final diffDays = dDay.difference(tDay).inDays;
      if (diffDays <= 0) return 7;
      if (diffDays > 7) return 0;
      return 7 - diffDays;
    }

    final n = available.length;
    final dp = List.generate(n + 1, (_) => List<int>.filled(capacityMinutes + 1, 0));

    for (var i = 1; i <= n; i++) {
      final task = available[i - 1];
      final d = task.durationMinutes!;
      final p = task.priority ?? 0;
      final u = calculateUrgency(task.date);
      final effectiveValue = p + u;

      for (var w = 0; w <= capacityMinutes; w++) {
        if (d <= w) {
          dp[i][w] = max(dp[i - 1][w], dp[i - 1][w - d] + effectiveValue);
        } else {
          dp[i][w] = dp[i - 1][w];
        }
      }
    }

    var w = capacityMinutes;
    final result = <Task>[];
    for (var i = n; i > 0; i--) {
      if (dp[i][w] != dp[i - 1][w]) {
        final t = available[i - 1];
        result.add(t);
        w -= t.durationMinutes!;
      }
    }

    return result.reversed.toList();
  }
}
