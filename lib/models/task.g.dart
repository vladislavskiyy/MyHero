// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 1;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
        id: fields[0] as String,
        title: fields[1] as String,
        date: fields[5] as DateTime?,
        category: fields[6] as String?,
        isDone: fields[2] as bool,
        durationMinutes: fields[3] as int?,
        priority: fields[4] as int?,
        listId: fields[8] as String?,
        deadline: fields[11] as DateTime?,
        estimatedDurationMinutes: fields[12] as int?,
        breakdownSteps: fields[13] == null
            ? []
            : (fields[13] as List?)?.cast<String>(),
        breakdownStepIds: (fields[14] as List?)?.cast<String>(),
        parentTaskId: fields[15] as String?,
        sourceStepId: fields[16] as String?,
        completedAt: fields[17] as DateTime?,
      )
      ..colorValue = fields[7] as int?
      ..recurrenceTypeValue = fields[9] == null ? 0 : fields[9] as int
      ..priorityLevelValue = fields[10] == null ? 1 : fields[10] as int;
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.isDone)
      ..writeByte(3)
      ..write(obj.durationMinutes)
      ..writeByte(4)
      ..write(obj.priority)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.colorValue)
      ..writeByte(8)
      ..write(obj.listId)
      ..writeByte(9)
      ..write(obj.recurrenceTypeValue)
      ..writeByte(10)
      ..write(obj.priorityLevelValue)
      ..writeByte(11)
      ..write(obj.deadline)
      ..writeByte(12)
      ..write(obj.estimatedDurationMinutes)
      ..writeByte(13)
      ..write(obj.breakdownSteps)
      ..writeByte(14)
      ..write(obj.breakdownStepIds)
      ..writeByte(15)
      ..write(obj.parentTaskId)
      ..writeByte(16)
      ..write(obj.sourceStepId)
      ..writeByte(17)
      ..write(obj.completedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
