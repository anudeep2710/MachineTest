import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../cubits/task_cubit.dart';
import '../cubits/user_cubit.dart';
import '../models/task.dart';
import 'availability_screen.dart';
import 'task_creation_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  String _filter = 'all';
  String? _userId;

  @override
  void initState() {
    super.initState();
    
    Future.delayed(const Duration(milliseconds: 300), () {
      final userState = context.read<UserCubit>().state;
      if (userState is UserCreated) {
        _userId = userState.userRow['id'];
        context.read<TaskCubit>().fetchTasks();
      }
    });
  }

  void _applyFilter(String filter) {
    setState(() {
      _filter = filter;
    });
    
    if (_userId != null) {
      switch (filter) {
        case 'all':
          context.read<TaskCubit>().fetchTasks();
          break;
        case 'created':
          context.read<TaskCubit>().fetchTasks(filterBy: 'created', userId: _userId);
          break;
        case 'mine':
          context.read<TaskCubit>().fetchTasks(filterBy: 'mine', userId: _userId);
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task List'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AvailabilityScreen()),
              );
            },
            tooltip: 'Manage Availability',
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: BlocConsumer<TaskCubit, TaskState>(
              listener: (context, state) {
                if (state is TaskError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.message)),
                  );
                }
              },
              builder: (context, state) {
                if (state is TaskLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is TasksLoaded) {
                  final tasks = state.tasks;
                  if (tasks.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildTaskList(tasks);
                }
                return const Center(child: Text('No tasks available.'));
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TaskCreationScreen()),
          ).then((_) {
            // Refresh tasks when returning from task creation
            _applyFilter(_filter);
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          const Text('Filters:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          _filterChip('All', _filter == 'all', () => _applyFilter('all')),
          const SizedBox(width: 8),
          _filterChip('Created', _filter == 'created', () => _applyFilter('created')),
          const SizedBox(width: 8),
          _filterChip('Mine', _filter == 'mine', () => _applyFilter('mine')),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.indigo : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, color: Colors.indigo.shade300, size: 70),
          const SizedBox(height: 16),
          Text(
            'No tasks found',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Click "Add Task" to create your first task.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (task.description != null && task.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      task.description!,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.indigo),
                    const SizedBox(width: 4),
                    Text(
                      'Duration: ${task.durationMinutes} min',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (task.startTime != null && task.endTime != null)
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.indigo),
                      const SizedBox(width: 4),
                      Text(
                        'Slot: ${DateFormat('MMM d, HH:mm').format(task.startTime!)} - ${DateFormat('HH:mm').format(task.endTime!)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.people, size: 16, color: Colors.indigo),
                    const SizedBox(width: 4),
                    Text(
                      'Collaborators: ${task.collaboratorIds.length}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}