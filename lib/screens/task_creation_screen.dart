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
  int _durationMinutes = 30; // Default duration
  List<Map<String, dynamic>> _availableSlots = [];
  Map<String, dynamic>? _selectedSlot;
  String? _userId;

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
      appBar: AppBar(
        title: const Text('Create Task'),
        centerTitle: true,
      ),
      body: BlocConsumer<TaskCubit, TaskState>(
        listener: (context, state) {
          if (state is TaskError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is TaskOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            Navigator.pop(context);
          } else if (state is AvailableSlotsLoaded) {
            setState(() {
              _availableSlots = state.slots;
              if (_availableSlots.isNotEmpty) {
                _currentStep = 3; // Move to slot selection step
              }
            });
          }
        },
        builder: (context, state) {
          if (state is TaskLoading || state is TaskOperationInProgress) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return Stepper(
            currentStep: _currentStep,
            onStepContinue: () {
              if (_currentStep == 0) {
                if (_titleController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a task title')),
                  );
                  return;
                }
                setState(() => _currentStep = 1);
              } else if (_currentStep == 1) {
                if (_selectedUserIds.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select at least one collaborator')),
                  );
                  return;
                }
                setState(() => _currentStep = 2);
              } else if (_currentStep == 2) {
                _findAvailableSlots();
              } else if (_currentStep == 3) {
                if (_selectedSlot == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a time slot')),
                  );
                  return;
                }
                _createTask();
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() => _currentStep--);
              } else {
                Navigator.pop(context);
              }
            },
            steps: [
              Step(
                title: const Text('Task Details'),
                content: _buildTaskDetailsStep(),
                isActive: _currentStep >= 0,
              ),
              Step(
                title: const Text('Choose Collaborators'),
                content: _buildCollaboratorsStep(),
                isActive: _currentStep >= 1,
              ),
              Step(
                title: const Text('Choose Duration'),
                content: _buildDurationStep(),
                isActive: _currentStep >= 2,
              ),
              Step(
                title: const Text('Choose Available Slot'),
                content: _buildSlotSelectionStep(),
                isActive: _currentStep >= 3,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTaskDetailsStep() {
    return Column(
      children: [
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          maxLines: 3,
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
                    : const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
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
    if (_availableSlots.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, size: 48, color: Colors.amber),
              SizedBox(height: 16),
              Text(
                'No available slots found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'The selected collaborators don\'t have common availability for the requested duration.',
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