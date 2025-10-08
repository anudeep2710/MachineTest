import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../cubits/availability_cubit.dart';
import '../cubits/user_cubit.dart';
import '../models/availability.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  String? userId;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 300), () {
      final userState = context.read<UserCubit>().state;
      if (userState is UserCreated) {
        userId = userState.userRow['id'];
        context.read<AvailabilityCubit>().fetchAvailabilities(userId!);
      }
    });
  }

  void _showAddEditDialog({Availability? existing}) {
    DateTime? startTime = existing?.startTime;
    DateTime? endTime = existing?.endTime;

    final startController = TextEditingController(
      text: startTime != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(startTime)
          : '',
    );
    final endController = TextEditingController(
      text: endTime != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(endTime)
          : '',
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add Availability' : 'Edit Availability'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dateTimePickerField(
              label: 'Start Time',
              controller: startController,
              onPicked: (picked) => startTime = picked,
            ),
            const SizedBox(height: 16),
            _dateTimePickerField(
              label: 'End Time',
              controller: endController,
              onPicked: (picked) => endTime = picked,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (startTime == null || endTime == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please select start and end times')),
                );
                return;
              }

              if (!endTime!.isAfter(startTime!)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('End time must be after start time')),
                );
                return;
              }

              if (existing == null) {
                context.read<AvailabilityCubit>().addAvailability(
                      userId: userId!,
                      start: startTime!,
                      end: endTime!,
                    );
              } else {
                context.read<AvailabilityCubit>().updateAvailability(
                      id: existing.id,
                      start: startTime!,
                      end: endTime!,
                    );
              }

              Navigator.pop(context);
            },
            child: Text(existing == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  Widget _dateTimePickerField({
    required String label,
    required TextEditingController controller,
    required Function(DateTime) onPicked,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () async {
        final now = DateTime.now();
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: now,
          firstDate: now.subtract(const Duration(days: 1)),
          lastDate: now.add(const Duration(days: 365)),
        );
        if (pickedDate != null) {
          final pickedTime =
              await showTimePicker(context: context, initialTime: TimeOfDay.now());
          if (pickedTime != null) {
            final fullDateTime = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            );
            controller.text =
                DateFormat('yyyy-MM-dd HH:mm').format(fullDateTime);
            onPicked(fullDateTime);
          }
        }
      },
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: const Icon(Icons.calendar_today, color: Colors.indigo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Availability'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: BlocConsumer<AvailabilityCubit, AvailabilityState>(
        listener: (context, state) {
          if (state is AvailabilityError) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          if (state is AvailabilityLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is AvailabilityLoaded) {
            final items = state.items;
            if (items.isEmpty) {
              return _emptyState();
            }
            return _buildList(items);
          }
          return const Center(child: Text('No data available.'));
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.white,
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Slot'),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month, color: Colors.indigo.shade300, size: 70),
            const SizedBox(height: 16),
            Text('No availability slots yet',
                style:
                    TextStyle(color: Colors.grey.shade600, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Click "Add Slot" to create your first availability.',
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );

  Widget _buildList(List<Availability> items) {
  final dateFormat = DateFormat('EEE, MMM d • HH:mm');
  return ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: items.length,
    itemBuilder: (context, index) {
      final slot = items[index];
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          leading: const Icon(Icons.access_time, color: Colors.indigo),
          title: Text(
            '${dateFormat.format(slot.startTime)} → ${dateFormat.format(slot.endTime)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Created: ${DateFormat('MMM d, yyyy').format(slot.createdAt)}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              if (slot.userId.isNotEmpty)
                Text(
                  'User ID: ${slot.userId}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
      );
    },
  );
}

  }