// lib/models/task.dart

class Task {
  final String id;
  final String title;
  final String? description;
  final String createdBy;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime createdAt;
  final List<String> collaboratorIds;
  final int durationMinutes;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.createdBy,
    this.startTime,
    this.endTime,
    required this.createdAt,
    this.collaboratorIds = const [],
    this.durationMinutes = 0,
  });

  factory Task.fromJson(Map<String, dynamic> json, {List<String>? collaborators}) {
    DateTime? parseDateTime(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.parse(val).toLocal();
      if (val is DateTime) return val.toLocal();
      return null;
    }

    return Task(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      description: json['description'],
      createdBy: json['created_by'].toString(),
      startTime: parseDateTime(json['start_time']),
      endTime: parseDateTime(json['end_time']),
      createdAt: parseDateTime(json['created_at']) ?? DateTime.now(),
      collaboratorIds: collaborators ?? [],
      // Calculate duration in minutes if start and end times are available
      durationMinutes: parseDateTime(json['start_time']) != null && parseDateTime(json['end_time']) != null
          ? parseDateTime(json['end_time'])!.difference(parseDateTime(json['start_time'])!).inMinutes
          : 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'created_by': createdBy,
        'start_time': startTime?.toUtc().toIso8601String(),
        'end_time': endTime?.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? createdBy,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? createdAt,
    List<String>? collaboratorIds,
    int? durationMinutes,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdAt: createdAt ?? this.createdAt,
      collaboratorIds: collaboratorIds ?? this.collaboratorIds,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}

class TaskCollaborator {
  final String id;
  final String taskId;
  final String userId;

  TaskCollaborator({
    required this.id,
    required this.taskId,
    required this.userId,
  });

  factory TaskCollaborator.fromJson(Map<String, dynamic> json) {
    return TaskCollaborator(
      id: json['id'].toString(),
      taskId: json['task_id'].toString(),
      userId: json['user_id'].toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'task_id': taskId,
        'user_id': userId,
      };
}