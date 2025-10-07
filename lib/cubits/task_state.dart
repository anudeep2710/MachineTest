// lib/cubits/task_state.dart

part of 'task_cubit.dart';

abstract class TaskState extends Equatable {
  const TaskState();

  @override
  List<Object?> get props => [];
}

class TaskInitial extends TaskState {}

class TaskLoading extends TaskState {}

class TasksLoaded extends TaskState {
  final List<Task> tasks;

  const TasksLoaded(this.tasks);

  @override
  List<Object?> get props => [tasks];
}

class TaskOperationInProgress extends TaskState {}

class TaskOperationSuccess extends TaskState {
  final String message;

  const TaskOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class TaskError extends TaskState {
  final String message;

  const TaskError(this.message);

  @override
  List<Object?> get props => [message];
}

class AvailableSlotsLoaded extends TaskState {
  final List<Map<String, dynamic>> slots;
  
  const AvailableSlotsLoaded(this.slots);
  
  @override
  List<Object?> get props => [slots];
}