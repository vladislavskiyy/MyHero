import 'package:hive/hive.dart';

part 'achievement.g.dart';

@HiveType(typeId: 4)
class Achievement extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  AchievementType type;

  @HiveField(4)
  int? requiredCount;

  @HiveField(5)
  int? requiredHabitStreak;

  @HiveField(6)
  int? requiredLevel;

  @HiveField(7)
  bool isUnlocked;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    this.type = AchievementType.tasks,
    this.requiredCount,
    this.requiredHabitStreak,
    this.requiredLevel,
    this.isUnlocked = false,
  });
}

@HiveType(typeId: 5)
enum AchievementType {
  @HiveField(0)
  tasks,

  @HiveField(1)
  habitStreak,

  @HiveField(2)
  level,
}
