part of 'user_cubit.dart';

abstract class UserState extends Equatable {
  @override
  List<Object?> get props => [];
}

class UserInitial extends UserState {}

/// Emitted while restoring a previously saved local session
class UserRestoring extends UserState {}

class UserLoading extends UserState {}

class UserCreated extends UserState {
  final Map<String, dynamic> userRow;
  UserCreated(this.userRow);
  @override
  List<Object?> get props => [userRow];
}

class UserError extends UserState {
  final String message;
  UserError(this.message);
  @override
  List<Object?> get props => [message];
}
