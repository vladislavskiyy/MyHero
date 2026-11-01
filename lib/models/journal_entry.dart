// lib/models/journal_entry.dart

import 'package:hive/hive.dart';

part 'journal_entry.g.dart';

@HiveType(typeId: 3)  
class JournalEntry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String content;

  @HiveField(3)
  List<String> imagePaths;

  @HiveField(4)
  DateTime date;

  JournalEntry({
    required this.id,
    required this.title,
    required this.content,
    List<String>? imagePaths,
    DateTime? date,
  })  : imagePaths = imagePaths ?? [],
        date = date ?? DateTime.now();

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      imagePaths:
          List<String>.from(map['imagePaths'] as List<dynamic>? ?? []),
      date: map['date'] != null
          ? DateTime.parse(map['date'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'imagePaths': imagePaths,
      'date': date.toIso8601String(),
    };
  }
}
