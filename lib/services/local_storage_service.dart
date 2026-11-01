import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/task.dart';
import '../models/task_list.dart';
import '../models/habit.dart';
import '../models/journal_entry.dart';
import '../models/achievement.dart';

class HiveService {
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(dir.path);

    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(TaskListAdapter());
    Hive.registerAdapter(HabitAdapter());
    Hive.registerAdapter(JournalEntryAdapter());
    Hive.registerAdapter(AchievementAdapter());

    await Hive.openBox<Task>('tasks');
    await Hive.openBox<TaskList>('lists');
    await Hive.openBox<Habit>('habits');
    await Hive.openBox<JournalEntry>('journal');
    await Hive.openBox<Achievement>('achievements');
  }
}
