import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'user_state.dart';

class UserCubit extends Cubit<UserState> {
  UserCubit({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client,
        super(UserInitial()) {
    _init();
  }

  final SupabaseClient _client;
  static const _prefsUserIdKey = 'current_user_id';

  Future<void> _init() async {
    emit(UserRestoring());
    final row = await loadExistingUser();
    if (row != null) {
      emit(UserCreated(row));
    } else {
      emit(UserInitial());
    }
  }

  /// Attempt to restore existing user from local storage
  Future<Map<String, dynamic>?> loadExistingUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_prefsUserIdKey);
      if (userId == null || userId.isEmpty) return null;

      final row = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      return row;
    } catch (_) {
      // Ignore restore errors to allow onboarding
      return null;
    }
  }

  /// Creates a user row in `users` table and uploads profile image (optional).
  Future<void> createUser({required String name, XFile? image}) async {
    if (name.trim().isEmpty) {
      emit(UserError('Name cannot be empty'));
      return;
    }

    emit(UserLoading());

    try {
      String? publicUrl;

      if (image != null) {
        final id = const Uuid().v4();
        final ext = image.name.split('.').last;
        final path = 'user-profiles/$id.$ext';

        // Upload image
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          await _client.storage.from('profile').uploadBinary(
                path,
                bytes,
                fileOptions:
                    const FileOptions(cacheControl: '3600', upsert: false),
              );
        } else {
          final file = File(image.path);
          await _client.storage.from('profile').upload(
                path,
                file,
                fileOptions:
                    const FileOptions(cacheControl: '3600', upsert: false),
              );
        }

        // Get public URL
        publicUrl = _client.storage.from('profile').getPublicUrl(path);
      }

      // Insert user record
      final insertData = {
        'name': name.trim(),
        if (publicUrl != null) 'photo_url': publicUrl,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response =
          await _client.from('users').insert(insertData).select().single();

      // Persist user id locally for session restoration
      final id = response['id']?.toString();
      if (id != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsUserIdKey, id);
      }

      emit(UserCreated(response));
    } catch (e) {
      emit(UserError(e.toString()));
    }
  }

  /// Clears local session (does not delete server-side data)
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsUserIdKey);
    emit(UserInitial());
  }
}
