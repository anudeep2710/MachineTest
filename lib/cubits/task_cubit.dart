// lib/cubits/task_cubit.dart

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import '../models/availability.dart';
import '../utils/availability_utils.dart';

part 'task_state.dart';

class TaskCubit extends Cubit<TaskState> {
  TaskCubit({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client,
        super(TaskInitial());

  final SupabaseClient _client;

  // Fetch all tasks
  Future<void> fetchTasks({String? filterBy, String? userId, int limit = 20, int offset = 0}) async {
    emit(TaskLoading());
    try {
      var query = _client
          .from('tasks')
          .select('*, task_collaborators(user_id)')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      // Apply filters if provided
      if (filterBy == 'created' && userId != null) {
        query = _client
          .from('tasks')
          .select('*, task_collaborators(user_id)')
          .eq('created_by', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      }

      final resp = await query;

      if (resp == null) {
        emit(const TaskError('No data returned'));
        return;
      }

      final tasks = await _processTasksResponse(resp);

      // Filter tasks where user is a collaborator
      if (filterBy == 'mine' && userId != null) {
        final filteredTasks = tasks
            .where((task) => task.collaboratorIds.contains(userId) || task.createdBy == userId)
            .toList();
        emit(TasksLoaded(filteredTasks));
      } else {
        emit(TasksLoaded(tasks));
      }
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  // Process tasks response and fetch collaborators
  Future<List<Task>> _processTasksResponse(List<dynamic> resp) async {
    final tasks = <Task>[];

    for (final item in resp) {
      final taskData = Map<String, dynamic>.from(item);
      final collaborators = <String>[];

      // Extract collaborator IDs
      if (taskData['task_collaborators'] != null) {
        for (final collab in taskData['task_collaborators']) {
          collaborators.add(collab['user_id'].toString());
        }
      }

      tasks.add(Task.fromJson(taskData, collaborators: collaborators));
    }

    return tasks;
  }

  // Create a new task
  Future<void> createTask({
    required String title,
    required String description,
    required String createdBy,
    required List<String> collaboratorIds,
    required DateTime? startTime,
    required DateTime? endTime,
  }) async {
    emit(TaskOperationInProgress());
    try {
      // Insert task
      final taskData = {
        'title': title,
        'description': description,
        'created_by': createdBy,
        'start_time': startTime?.toUtc().toIso8601String(),
        'end_time': endTime?.toUtc().toIso8601String(),
      };

      final taskResp = await _client.from('tasks').insert(taskData).select().single();

      if (taskResp == null) {
        emit(const TaskError('Failed to create task'));
        return;
      }

      final taskId = taskResp['id'].toString();

      // Add collaborators (bulk insert for efficiency)
      if (collaboratorIds.isNotEmpty) {
        final rows = collaboratorIds.map((u) => {
              'task_id': taskId,
              'user_id': u,
            });
        await _client.from('task_collaborators').insert(rows.toList());
      }

      emit(const TaskOperationSuccess('Task created successfully'));
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  // Find available time slots based on collaborators' availability
  Future<void> findAvailableSlots({
    required List<String> collaboratorIds,
    required int durationMinutes,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    emit(TaskLoading());
    try {
      // Default date range is today to 7 days from now if not specified
      final now = DateTime.now();
      final start = startDate ?? DateTime(now.year, now.month, now.day);
      // Make the search window inclusive through the end of the 7th day
      final inclusiveEndBase = endDate ?? start.add(const Duration(days: 7));
      final end = DateTime(
        inclusiveEndBase.year,
        inclusiveEndBase.month,
        inclusiveEndBase.day,
        23,
        59,
        59,
        999,
      );

      // Fetch all availabilities for the collaborators
      final availabilities = await _fetchCollaboratorsAvailability(collaboratorIds, start, end);

      if (availabilities.isEmpty) {
        emit(const AvailableSlotsLoaded([]));
        return;
      }

      // Build user -> slots map for utility function
      final Map<String, List<Map<String, DateTime>>> map = {};
      for (final a in availabilities) {
        map.putIfAbsent(a.userId, () => []);
        map[a.userId]!.add({'start': a.startTime, 'end': a.endTime});
      }

      final slots = findCommonAvailableSlots(
        availabilities: map,
        durationMinutes: durationMinutes,
      );

      // Convert to dynamic map for state
      final dynamicSlots = slots
          .map<Map<String, dynamic>>((s) => {'start': s['start']!, 'end': s['end']!})
          .toList();

      emit(AvailableSlotsLoaded(dynamicSlots));
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  // Fetch availabilities for all collaborators
  Future<List<Availability>> _fetchCollaboratorsAvailability(
    List<String> userIds,
    DateTime start,
    DateTime end,
  ) async {
    final availabilities = <Availability>[];

    for (final userId in userIds) {
      // Fetch any availability that OVERLAPS the requested window:
      // end_time >= start AND start_time <= end
      final resp = await _client
          .from('availability')
          .select()
          .eq('user_id', userId)
          .gte('end_time', start.toUtc().toIso8601String())
          .lte('start_time', end.toUtc().toIso8601String())
          .order('start_time');

      if (resp != null) {
        for (final item in resp) {
          availabilities.add(Availability.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return availabilities;
  }
}
