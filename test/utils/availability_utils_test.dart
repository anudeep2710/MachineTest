// test/utils/availability_utils_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:tc/utils/availability_utils.dart';

void main() {
  group('findCommonAvailableSlots', () {
    test('Simple overlap between two users', () {
      final availabilities = {
        'user1': [
          {
            'start': DateTime(2023, 1, 1, 10, 0), // 10:00 AM
            'end': DateTime(2023, 1, 1, 12, 0),   // 12:00 PM
          },
        ],
        'user2': [
          {
            'start': DateTime(2023, 1, 1, 11, 0), // 11:00 AM
            'end': DateTime(2023, 1, 1, 13, 0),   // 1:00 PM
          },
        ],
      };

      final result = findCommonAvailableSlots(
        availabilities: availabilities,
        durationMinutes: 60,
      );

      expect(result.length, 1);
      expect(result[0]['start'], DateTime(2023, 1, 1, 11, 0));
      expect(result[0]['end'], DateTime(2023, 1, 1, 12, 0));
    });

    test('No overlap between users', () {
      final availabilities = {
        'user1': [
          {
            'start': DateTime(2023, 1, 1, 10, 0), // 10:00 AM
            'end': DateTime(2023, 1, 1, 11, 0),   // 11:00 AM
          },
        ],
        'user2': [
          {
            'start': DateTime(2023, 1, 1, 12, 0), // 12:00 PM
            'end': DateTime(2023, 1, 1, 13, 0),   // 1:00 PM
          },
        ],
      };

      final result = findCommonAvailableSlots(
        availabilities: availabilities,
        durationMinutes: 30,
      );

      expect(result.length, 0);
    });

    test('Three users with partial overlaps', () {
      final availabilities = {
        'user1': [
          {
            'start': DateTime(2023, 1, 1, 9, 0),  // 9:00 AM
            'end': DateTime(2023, 1, 1, 12, 0),   // 12:00 PM
          },
        ],
        'user2': [
          {
            'start': DateTime(2023, 1, 1, 10, 0), // 10:00 AM
            'end': DateTime(2023, 1, 1, 13, 0),   // 1:00 PM
          },
        ],
        'user3': [
          {
            'start': DateTime(2023, 1, 1, 11, 0), // 11:00 AM
            'end': DateTime(2023, 1, 1, 14, 0),   // 2:00 PM
          },
        ],
      };

      final result = findCommonAvailableSlots(
        availabilities: availabilities,
        durationMinutes: 30,
      );

      expect(result.length, 2);
      expect(result[0]['start'], DateTime(2023, 1, 1, 11, 0));
      expect(result[0]['end'], DateTime(2023, 1, 1, 11, 30));
      expect(result[1]['start'], DateTime(2023, 1, 1, 11, 30));
      expect(result[1]['end'], DateTime(2023, 1, 1, 12, 0));
    });

    test('Duration longer than overlap window', () {
      final availabilities = {
        'user1': [
          {
            'start': DateTime(2023, 1, 1, 10, 0), // 10:00 AM
            'end': DateTime(2023, 1, 1, 11, 30),  // 11:30 AM
          },
        ],
        'user2': [
          {
            'start': DateTime(2023, 1, 1, 11, 0), // 11:00 AM
            'end': DateTime(2023, 1, 1, 12, 0),   // 12:00 PM
          },
        ],
      };

      final result = findCommonAvailableSlots(
        availabilities: availabilities,
        durationMinutes: 45,
      );

      expect(result.length, 0);
    });

    test('Multiple separate common windows', () {
      final availabilities = {
        'user1': [
          {
            'start': DateTime(2023, 1, 1, 9, 0),   // 9:00 AM
            'end': DateTime(2023, 1, 1, 10, 0),    // 10:00 AM
          },
          {
            'start': DateTime(2023, 1, 1, 11, 0),  // 11:00 AM
            'end': DateTime(2023, 1, 1, 12, 0),    // 12:00 PM
          },
          {
            'start': DateTime(2023, 1, 1, 14, 0),  // 2:00 PM
            'end': DateTime(2023, 1, 1, 15, 0),    // 3:00 PM
          },
        ],
        'user2': [
          {
            'start': DateTime(2023, 1, 1, 9, 30),  // 9:30 AM
            'end': DateTime(2023, 1, 1, 10, 30),   // 10:30 AM
          },
          {
            'start': DateTime(2023, 1, 1, 11, 30), // 11:30 AM
            'end': DateTime(2023, 1, 1, 12, 30),   // 12:30 PM
          },
          {
            'start': DateTime(2023, 1, 1, 13, 30), // 1:30 PM
            'end': DateTime(2023, 1, 1, 15, 30),   // 3:30 PM
          },
        ],
      };

      final result = findCommonAvailableSlots(
        availabilities: availabilities,
        durationMinutes: 30,
      );

      expect(result.length, 3);
      expect(result[0]['start'], DateTime(2023, 1, 1, 9, 30));
      expect(result[0]['end'], DateTime(2023, 1, 1, 10, 0));
      expect(result[1]['start'], DateTime(2023, 1, 1, 11, 30));
      expect(result[1]['end'], DateTime(2023, 1, 1, 12, 0));
      expect(result[2]['start'], DateTime(2023, 1, 1, 14, 0));
      expect(result[2]['end'], DateTime(2023, 1, 1, 14, 30));
    });

    test('Empty input', () {
      final availabilities = <String, List<Map<String, DateTime>>>{};

      final result = findCommonAvailableSlots(
        availabilities: availabilities,
        durationMinutes: 30,
      );

      expect(result.length, 0);
    });

    test('Single user', () {
      final availabilities = {
        'user1': [
          {
            'start': DateTime(2023, 1, 1, 10, 0), // 10:00 AM
            'end': DateTime(2023, 1, 1, 12, 0),   // 12:00 PM
          },
        ],
      };

      final result = findCommonAvailableSlots(
        availabilities: availabilities,
        durationMinutes: 60,
      );

      expect(result.length, 2);
      expect(result[0]['start'], DateTime(2023, 1, 1, 10, 0));
      expect(result[0]['end'], DateTime(2023, 1, 1, 11, 0));
      expect(result[1]['start'], DateTime(2023, 1, 1, 11, 0));
      expect(result[1]['end'], DateTime(2023, 1, 1, 12, 0));
    });

    test('Timezone awareness', () {
      // Create DateTimes with explicit UTC timezone
      final utcStart1 = DateTime.utc(2023, 1, 1, 10, 0);
      final utcEnd1 = DateTime.utc(2023, 1, 1, 12, 0);
      final utcStart2 = DateTime.utc(2023, 1, 1, 11, 0);
      final utcEnd2 = DateTime.utc(2023, 1, 1, 13, 0);

      final availabilities = {
        'user1': [
          {
            'start': utcStart1,
            'end': utcEnd1,
          },
        ],
        'user2': [
          {
            'start': utcStart2,
            'end': utcEnd2,
          },
        ],
      };

      final result = findCommonAvailableSlots(
        availabilities: availabilities,
        durationMinutes: 60,
      );

      expect(result.length, 1);
      expect(result[0]['start'], utcStart2);
      expect(result[0]['end'], utcEnd1);
    });
  });
}