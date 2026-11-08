// lib/models/habit.dart

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'habit.g.dart';

@HiveType(typeId: 0)
class Habit extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  int colorValue;

  @HiveField(3)
  int iconCodePoint;

  @HiveField(4)
  String iconFontFamily;

  @HiveField(5)
  List<DateTime> completedDates;

  @HiveField(6)
  int lives;

  @HiveField(7)
  DateTime? lastMissCheck;

  Habit({
    required this.id,
    required this.title,
    required this.colorValue,
    required this.iconCodePoint,
    required this.iconFontFamily,
    List<DateTime>? completedDates,
    this.lives = 3,
    this.lastMissCheck,
  }) : completedDates = completedDates ?? [];

  Color get color => Color(colorValue);
  set color(Color c) => colorValue = c.toARGB32();

  IconData get icon => IconData(iconCodePoint, fontFamily: iconFontFamily);
  set icon(IconData i) {
    iconCodePoint = i.codePoint;
    iconFontFamily = i.fontFamily ?? '';
  }

  bool isDoneOn(DateTime day) => completedDates.any(
    (d) => d.year == day.year && d.month == day.month && d.day == day.day,
  );

  void toggleDay(DateTime day) {
    if (isDoneOn(day)) {
      completedDates.removeWhere(
        (d) => d.year == day.year && d.month == day.month && d.day == day.day,
      );
    } else {
      completedDates.add(day);
    }
  }
}
