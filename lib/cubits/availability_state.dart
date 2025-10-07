// lib/cubits/availability_state.dart
part of 'availability_cubit.dart';

abstract class AvailabilityState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AvailabilityInitial extends AvailabilityState {}

class AvailabilityLoading extends AvailabilityState {}

class AvailabilityLoaded extends AvailabilityState {
  final List<Availability> items;
  AvailabilityLoaded(this.items);

  @override
  List<Object?> get props => [items];
}

class AvailabilityOperationInProgress extends AvailabilityState {}

class AvailabilityOperationSuccess extends AvailabilityState {
  final String message;
  AvailabilityOperationSuccess([this.message = 'Success']);

  @override
  List<Object?> get props => [message];
}

class AvailabilityError extends AvailabilityState {
  final String message;
  AvailabilityError(this.message);

  @override
  List<Object?> get props => [message];
}
