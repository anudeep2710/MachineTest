// lib/models/availability.dart

class Availability {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime createdAt;

  Availability({
    required this.id,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
  });

  factory Availability.fromJson(Map<String, dynamic> json) {
    // Depending on SDK, timestamptz fields may already be ISO strings
    final startRaw = json['start_time'];
    final endRaw = json['end_time'];
    final createdRaw = json['created_at'];

    DateTime parseTs(dynamic val) {
      if (val == null) return DateTime.now().toUtc();
      if (val is String) return DateTime.parse(val).toLocal();
      if (val is DateTime) return val.toLocal();
      // fallback
      return DateTime.parse(val.toString()).toLocal();
    }

    return Availability(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      startTime: parseTs(startRaw),
      endTime: parseTs(endRaw),
      createdAt: parseTs(createdRaw),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}
