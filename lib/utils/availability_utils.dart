// lib/utils/availability_utils.dart

/// Utility functions for handling availability calculations in the Team Scheduler app.

/// Finds common available time slots among multiple users.
///
/// This function calculates overlapping availability among multiple users based on their
/// individual availability slots and a required minimum duration. It uses an efficient
/// algorithm with O(n log n) time complexity where n is the total number of availability slots.
///
/// Parameters:
/// - `availabilities`: A map where keys are user IDs and values are lists of availability slots
///   Each slot is a map with "start" and "end" DateTime values
/// - `durationMinutes`: The minimum required duration for a common slot in minutes
///
/// Returns:
/// A list of maps representing common available time slots, each with "start" and "end" DateTime values
/// formatted in ISO 8601 format for consistency across timezones.
///
/// Example:
/// ```dart
/// final availabilities = {
///   'user1': [
///     {'start': DateTime(2023, 1, 1, 10, 0), 'end': DateTime(2023, 1, 1, 12, 0)},
///   ],
///   'user2': [
///     {'start': DateTime(2023, 1, 1, 11, 0), 'end': DateTime(2023, 1, 1, 13, 0)},
///   ],
/// };
/// final slots = findCommonAvailableSlots(
///   availabilities: availabilities,
///   durationMinutes: 60,
/// );
/// // Result: [{'start': DateTime(2023, 1, 1, 11, 0), 'end': DateTime(2023, 1, 1, 12, 0)}]
/// ```
List<Map<String, DateTime>> findCommonAvailableSlots({
  required Map<String, List<Map<String, DateTime>>> availabilities,
  required int durationMinutes,
}) {
  // Handle edge cases
  if (availabilities.isEmpty || durationMinutes <= 0) {
    return [];
  }
  
  // If there's only one user, return their slots that meet the duration requirement
  if (availabilities.length == 1) {
    final userId = availabilities.keys.first;
    final userSlots = availabilities[userId] ?? [];
    
    return _processSlots(userSlots, durationMinutes);
  }
  
  // Get list of all user IDs
  final userIds = availabilities.keys.toList();
  
  // Check if any user has no availability
  for (final userId in userIds) {
    if (availabilities[userId]?.isEmpty ?? true) {
      return []; // Early return if any user has no slots
    }
  }
  
  // Use sweep line algorithm for better performance
  // 1. Create events for all slot boundaries
  final events = <_Event>[];
  
  for (final userId in userIds) {
    final userSlots = availabilities[userId]!;
    
    for (final slot in userSlots) {
      events.add(_Event(slot['start']!, true, userId));
      events.add(_Event(slot['end']!, false, userId));
    }
  }
  
  // 2. Sort events by time
  events.sort();
  
  // 3. Sweep through events to find overlaps
  final activeUsers = <String>{};
  final result = <Map<String, DateTime>>[];
  DateTime? overlapStart;
  
  for (int i = 0; i < events.length; i++) {
    final event = events[i];
    
    if (event.isStart) {
      activeUsers.add(event.userId);
      
      // If all users are available, mark the start of an overlap
      if (activeUsers.length == userIds.length && overlapStart == null) {
        overlapStart = event.time;
      }
    } else {
      activeUsers.remove(event.userId);
      
      // If we had an overlap and now it's ending, add it to results
      if (overlapStart != null && activeUsers.length < userIds.length) {
        final overlapDuration = event.time.difference(overlapStart).inMinutes;
        
        if (overlapDuration >= durationMinutes) {
          // Break down into chunks of exactly durationMinutes
          var chunkStart = overlapStart;
          while (event.time.difference(chunkStart).inMinutes >= durationMinutes) {
            final chunkEnd = chunkStart.add(Duration(minutes: durationMinutes));
            result.add({
              'start': chunkStart,
              'end': chunkEnd,
            });
            chunkStart = chunkEnd;
          }
        }
        
        overlapStart = null;
      }
    }
  }
  
  return result;
}

/// Helper class for the sweep line algorithm
class _Event implements Comparable<_Event> {
  final DateTime time;
  final bool isStart;
  final String userId;
  
  _Event(this.time, this.isStart, this.userId);
  
  @override
  int compareTo(_Event other) {
    final timeComparison = time.compareTo(other.time);
    if (timeComparison != 0) return timeComparison;
    
    // For same time, process end events before start events
    // This handles adjacent slots correctly
    if (isStart != other.isStart) {
      return isStart ? 1 : -1;
    }
    
    return 0;
  }
}

/// Helper function to process slots for a single user
List<Map<String, DateTime>> _processSlots(
  List<Map<String, DateTime>> slots,
  int durationMinutes,
) {
  final result = <Map<String, DateTime>>[];
  
  for (final slot in slots) {
    final start = slot['start'];
    final end = slot['end'];
    
    if (start == null || end == null) continue;
    
    final duration = end.difference(start).inMinutes;
    if (duration < durationMinutes) continue;
    
    var slotStart = start;
    while (end.difference(slotStart).inMinutes >= durationMinutes) {
      final slotEnd = slotStart.add(Duration(minutes: durationMinutes));
      result.add({
        'start': slotStart,
        'end': slotEnd,
      });
      slotStart = slotEnd;
    }
  }
  
  return result;
}