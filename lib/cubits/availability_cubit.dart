// lib/cubits/availability_cubit.dart

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/availability.dart';

part 'availability_state.dart';

class AvailabilityCubit extends Cubit<AvailabilityState> {
  AvailabilityCubit() : super(AvailabilityInitial());

  final _client = Supabase.instance.client;

  /// Fetch all availabilities for a given user (ordered by start_time).
  Future<void> fetchAvailabilities(String userId) async {
    emit(AvailabilityLoading());
    try {
      final resp = await _client
          .from('availability')
          .select()
          .eq('user_id', userId)
          .order('start_time', ascending: true);

      // resp is typically List<dynamic>
      if (resp == null) {
        emit(AvailabilityError('No data returned'));
        return;
      }

      final list = (resp as List)
          .map((e) => Availability.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      emit(AvailabilityLoaded(list));
    } catch (e) {
      emit(AvailabilityError(e.toString()));
    }
  }

  /// Add new availability. Validates that end > start.
  Future<void> addAvailability({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    if (!end.isAfter(start)) {
      emit(AvailabilityError('End time must be after start time'));
      return;
    }

    emit(AvailabilityOperationInProgress());
    try {
      final insertData = {
        'user_id': userId,
        'start_time': start.toUtc().toIso8601String(),
        'end_time': end.toUtc().toIso8601String(),
      };

      // Insert and return the created row
      final inserted = await _client.from('availability').insert(insertData).select().single();
      // Optionally convert to Availability object and update list
      if (inserted != null) {
        // Refresh list if currently loaded
        if (state is AvailabilityLoaded) {
          final current = (state as AvailabilityLoaded).items;
          final newItem = Availability.fromJson(Map<String, dynamic>.from(inserted));
          emit(AvailabilityLoaded([...current, newItem]..sort((a,b) => a.startTime.compareTo(b.startTime))));
        } else {
          // or just refetch later; here we emit success and leave UI to call fetch
          emit(AvailabilityOperationSuccess('Added'));
        }
      } else {
        emit(AvailabilityError('Insert returned no data'));
      }
    } catch (e) {
      emit(AvailabilityError(e.toString()));
    }
  }

  /// Update an availability row by id.
  Future<void> updateAvailability({
    required String id,
    required DateTime start,
    required DateTime end,
  }) async {
    if (!end.isAfter(start)) {
      emit(AvailabilityError('End time must be after start time'));
      return;
    }

    emit(AvailabilityOperationInProgress());
    try {
      final updateData = {
        'start_time': start.toUtc().toIso8601String(),
        'end_time': end.toUtc().toIso8601String(),
      };

      final updated = await _client
          .from('availability')
          .update(updateData)
          .eq('id', id)
          .select()
          .single();

      if (updated != null) {
        // If loaded, replace item in list
        if (state is AvailabilityLoaded) {
          final current = (state as AvailabilityLoaded).items;
          final updatedItem = Availability.fromJson(Map<String, dynamic>.from(updated));
          final newList = current.map((it) => it.id == updatedItem.id ? updatedItem : it).toList()
            ..sort((a,b) => a.startTime.compareTo(b.startTime));
          emit(AvailabilityLoaded(newList));
        } else {
          emit(AvailabilityOperationSuccess('Updated'));
        }
      } else {
        emit(AvailabilityError('Update returned no data'));
      }
    } catch (e) {
      emit(AvailabilityError(e.toString()));
    }
  }

  /// Delete availability by id.
  Future<void> deleteAvailability(String id) async {
    emit(AvailabilityOperationInProgress());
    try {
      final deleted = await _client.from('availability').delete().eq('id', id).select();
      // Supabase returns list of deleted rows typically
      if (deleted == null) {
        emit(AvailabilityError('Delete returned no data'));
        return;
      }

      if (state is AvailabilityLoaded) {
        final current = (state as AvailabilityLoaded).items;
        final newList = current.where((it) => it.id != id).toList();
        emit(AvailabilityLoaded(newList));
      } else {
        emit(AvailabilityOperationSuccess('Deleted'));
      }
    } catch (e) {
      emit(AvailabilityError(e.toString()));
    }
  }
}
