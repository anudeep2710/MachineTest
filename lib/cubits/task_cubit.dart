// lib/cubits/task_cubit.dart

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import '../models/availability.dart';

part 'task_state.dart';

class TaskCubit extends Cubit<TaskState> {
  TaskCubit() : super(TaskInitial());

  final _client = Supabase.instance.client;

  // Fetch all tasks
  Future<void> fetchTasks({String? filterBy, String? userId}) async {
    emit(TaskLoading());
    try {
      var query = _client.from('tasks').select('*, task_collaborators(user_id)');
      
      // Apply filters if provided
      if (filterBy == 'created' && userId != null) {
        query = query.eq('created_by', userId);
      }
      
      final resp = await query.order('created_at', ascending: false);
      
      if (resp == null) {
        emit(const TaskError('No data returned'));
        return;
      }

      final tasks = await _processTasksResponse(resp);
      
      // Filter tasks where user is a collaborator
      if (filterBy == 'mine' && userId != null) {
        final filteredTasks = tasks.where((task) => 
          task.collaboratorIds.contains(userId) || task.createdBy == userId
        ).toList();
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
      
      // Add collaborators
      for (final userId in collaboratorIds) {
        await _client.from('task_collaborators').insert({
          'task_id': taskId,
          'user_id': userId,
        });
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
      final end = endDate ?? start.add(const Duration(days: 7));
      
      // Fetch all availabilities for the collaborators
      final availabilities = await _fetchCollaboratorsAvailability(collaboratorIds, start, end);
      
      if (availabilities.isEmpty) {
        emit(const AvailableSlotsLoaded([]));
        return;
      }
      
      // Find common available slots
      final slots = _findCommonSlots(availabilities, durationMinutes);
      emit(AvailableSlotsLoaded(slots));
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
      final resp = await _client
          .from('availability')
          .select()
          .eq('user_id', userId)
          .gte('start_time', start.toUtc().toIso8601String())
          .lte('end_time', end.toUtc().toIso8601String());
      
      if (resp != null) {
        for (final item in resp) {
          availabilities.add(
            Availability.fromJson(Map<String, dynamic>.from(item))
          );
        }
      }
    }
    
    return availabilities;
  }

  // Find common available time slots
  List<Map<String, dynamic>> _findCommonSlots(
    List<Availability> availabilities,
    int durationMinutes,
  ) {
    if (availabilities.isEmpty) {
      return [];
    }

    // Group availabilities by user
    final userAvailabilities = <String, List<Availability>>{};
    for (final avail in availabilities) {
      if (!userAvailabilities.containsKey(avail.userId)) {
        userAvailabilities[avail.userId] = [];
      }
      userAvailabilities[avail.userId]!.add(avail);
    }
    
    // If any user has no availability, return empty list
    if (userAvailabilities.values.any((list) => list.isEmpty)) {
      return [];
    }
    
    // Find overlapping time slots
    final slots = <Map<String, dynamic>>[];
    final userIds = userAvailabilities.keys.toList();
    
    // Start with the first user's availability
    final firstUserSlots = userAvailabilities[userIds.first]!;
    
    for (final slot in firstUserSlots) {
      var start = slot.startTime;
      var end = slot.endTime;
      
      // Check if this slot overlaps with all other users' availability
      var isCommonSlot = true;
      
      for (int i = 1; i < userIds.length; i++) {
        final userId = userIds[i];
        final userSlots = userAvailabilities[userId]!;
        
        // Check if any of this user's slots overlap with our current slot
        var hasOverlap = false;
        DateTime? overlapStart;
        DateTime? overlapEnd;
        
        for (final userSlot in userSlots) {
          // Find overlap
          if (userSlot.endTime.isAfter(start) && userSlot.startTime.isBefore(end)) {
            overlapStart = userSlot.startTime.isAfter(start) ? userSlot.startTime : start;
            overlapEnd = userSlot.endTime.isBefore(end) ? userSlot.endTime : end;
            
            // Check if overlap is long enough
            if (overlapEnd.difference(overlapStart).inMinutes >= durationMinutes) {
              hasOverlap = true;
              start = overlapStart;
              end = overlapEnd;
              break;
            }
          }
        }
        
        if (!hasOverlap) {
          isCommonSlot = false;
          break;
        }
      }
      
      // If we found a common slot, add it to results
      if (isCommonSlot) {
        // Break down the slot into chunks of the requested duration
        var slotStart = start;
        while (end.difference(slotStart).inMinutes >= durationMinutes) {
          final slotEnd = slotStart.add(Duration(minutes: durationMinutes));
          slots.add({
            'start': slotStart,
            'end': slotEnd,
          });
          slotStart = slotEnd;
        }
      }
    }
    
    return slots;
  }
}