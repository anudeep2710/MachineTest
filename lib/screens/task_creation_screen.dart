import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../cubits/task_cubit.dart';
import '../cubits/user_cubit.dart';

class TaskCreationScreen extends StatefulWidget {
  const TaskCreationScreen({Key? key}) : super(key: key);

  @override
  State<TaskCreationScreen> createState() => _TaskCreationScreenState();
}

class _TaskCreationScreenState extends State<TaskCreationScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<Map<String, dynamic>> _users = [];
  final List<String> _selectedUserIds = [];
  int _currentStep = 0;
  int _durationMinutes = 30;
  List<Map<String, dynamic>> _availableSlots = [];
  Map<String, dynamic>? _selectedSlot;
  String? _userId;
  bool _isLoadingSlots = false;

  final List<int> _availableDurations = [10, 15, 30, 60];

  @override
  void initState() {
    super.initState();
    _fetchUsers();

    final userState = context.read<UserCubit>().state;
    if (userState is UserCreated) {
      _userId = userState.userRow['id'];
      _selectedUserIds.add(_userId!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    try {
      final client = Supabase.instance.client;
      final response = await client.from('users').select();
      if (response != null) {
        setState(() {
          _users.clear();
          for (final user in response) {
            _users.add(Map<String, dynamic>.from(user));
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching users: $e')),
      );
    }
  }

  void _findAvailableSlots() {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one collaborator')),
      );
      return;
    }

    context.read<TaskCubit>().findAvailableSlots(
          collaboratorIds: _selectedUserIds,
          durationMinutes: _durationMinutes,
        );
  }

  void _createTask() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one collaborator')),
      );
      return;
    }

    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot')),
      );
      return;
    }

    context.read<TaskCubit>().createTask(
          title: _titleController.text,
          description: _descriptionController.text,
          createdBy: _userId!,
          collaboratorIds: _selectedUserIds,
          startTime: _selectedSlot!['start'],
          endTime: _selectedSlot!['end'],
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Create Task',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: BlocConsumer<TaskCubit, TaskState>(
        listener: (context, state) {
          if (state is TaskError) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is TaskOperationSuccess) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message)));
            Navigator.pop(context);
          } else if (state is AvailableSlotsLoaded) {
            setState(() {
              _isLoadingSlots = false;
              _availableSlots = state.slots;
              _currentStep = 3;
            });
          }
        },
        builder: (context, state) {
          if (state is TaskLoading || state is TaskOperationInProgress) {
            return const Center(child: CircularProgressIndicator());
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;

              return Center(
                child: Container(
                  width: isMobile ? double.infinity : 700,
                  margin: EdgeInsets.symmetric(
                    vertical: isMobile ? 16 : 24,
                    horizontal: isMobile ? 12 : 24,
                  ),
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        spreadRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stepper(
                    type: isMobile
                        ? StepperType.vertical
                        : StepperType.horizontal,
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    currentStep: _currentStep,
                    onStepContinue: _onContinue,
                    onStepCancel: _onCancel,
                    controlsBuilder: _controlsBuilder,
                    steps: [
                      Step(
                        title: const Text('Task Details'),
                        content: _buildTaskDetailsStep(),
                        isActive: _currentStep >= 0,
                      ),
                      Step(
                        title: const Text('Collaborators'),
                        content: _buildCollaboratorsStep(),
                        isActive: _currentStep >= 1,
                      ),
                      Step(
                        title: const Text('Duration'),
                        content: _buildDurationStep(),
                        isActive: _currentStep >= 2,
                      ),
                      Step(
                        title: const Text('Available Slot'),
                        content: _buildSlotSelectionStep(),
                        isActive: _currentStep >= 3,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --------------------------
  // Stepper Logic
  // --------------------------
  void _onContinue() {
    if (_currentStep == 0 && _titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    } else if (_currentStep == 1 && _selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one collaborator')),
      );
      return;
    } else if (_currentStep == 2) {
      setState(() => _isLoadingSlots = true);
      _findAvailableSlots();
      return;
    } else if (_currentStep == 3 && _selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot')),
      );
      return;
    }

    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _createTask();
    }
  }

  void _onCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  // --------------------------
  // Responsive Controls Builder
  // --------------------------
  Widget _controlsBuilder(BuildContext context, ControlsDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.start,
        children: [
          SizedBox(
            width: isMobile ? double.infinity : null,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: details.onStepContinue,
              child: Text(_currentStep == 3 ? 'Create Task' : 'Continue'),
            ),
          ),
          SizedBox(
            width: isMobile ? double.infinity : null,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.indigo,
                side: const BorderSide(color: Colors.indigo),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: details.onStepCancel,
              child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------
  // UI Builders
  // --------------------------
  Widget _buildTaskDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Title',
            labelStyle: const TextStyle(fontWeight: FontWeight.w500),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Description',
            labelStyle: const TextStyle(fontWeight: FontWeight.w500),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildCollaboratorsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select collaborators for this task:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        if (_users.isEmpty)
          const Center(child: CircularProgressIndicator())
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              final userId = user['id'].toString();
              final isSelected = _selectedUserIds.contains(userId);
              return CheckboxListTile(
                title: Text(user['name'] ?? 'Unknown User'),
                subtitle: Text('User ID: ${userId.substring(0, 8)}...'),
                value: isSelected,
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      if (!_selectedUserIds.contains(userId)) {
                        _selectedUserIds.add(userId);
                      }
                    } else {
                      _selectedUserIds.remove(userId);
                    }
                  });
                },
                secondary: user['photo_url'] != null
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(user['photo_url']),
                      )
                    : const CircleAvatar(child: Icon(Icons.person)),
              );
            },
          ),
      ],
    );
  }

  Widget _buildDurationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select task duration:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          value: _durationMinutes,
          decoration: InputDecoration(
            labelText: 'Duration (minutes)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: _availableDurations.map((duration) {
            return DropdownMenuItem<int>(
              value: duration,
              child: Text('$duration minutes'),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _durationMinutes = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildSlotSelectionStep() {
    if (_isLoadingSlots) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_availableSlots.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 48, color: Colors.amber),
              SizedBox(height: 16),
              Text(
                'No available slots found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'The selected collaborators don’t have common availability for the requested duration.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select an available time slot:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _availableSlots.length,
          itemBuilder: (context, index) {
            final slot = _availableSlots[index];
            final start = slot['start'] as DateTime;
            final end = slot['end'] as DateTime;
            final isSelected = _selectedSlot == slot;

            return RadioListTile<Map<String, dynamic>>(
              title: Text(
                '${DateFormat('EEE, MMM d').format(start)} • ${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text('Duration: $_durationMinutes minutes'),
              value: slot,
              groupValue: _selectedSlot,
              onChanged: (value) {
                setState(() {
                  _selectedSlot = value;
                });
              },
              activeColor: Colors.indigo,
              selected: isSelected,
            );
          },
        ),
      ],
    );
  }
}
