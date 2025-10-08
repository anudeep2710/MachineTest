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
  bool _fetchedOnce = false;
  final int _pageSize = 20;
  int _offset = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<Task> _tasks = [];

  @override
  void initState() {
    super.initState();
    // Immediately read current user state to avoid missing initial emission
    final current = context.read<UserCubit>().state;
    if (current is UserCreated) {
      _userId = current.userRow['id'];
      _fetchedOnce = true;
      _fetchTasks(reset: true);
    }
  }

  void _applyFilter(String filter) {
    setState(() => _filter = filter);
    _fetchTasks(reset: true);
  }

  void _fetchTasks({bool reset = false}) {
    if (_userId == null) return;
    if (reset) {
      setState(() {
        _offset = 0;
        _hasMore = true;
        _tasks = [];
      });
    }
    context.read<TaskCubit>().fetchTasks(
          filterBy: _filter == 'all' ? null : _filter,
          userId: _userId,
          limit: _pageSize,
          offset: _offset,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserCubit, UserState>(
      listener: (context, state) {
        if (state is UserCreated) {
          _userId = state.userRow['id'];
          if (!_fetchedOnce) {
            _fetchedOnce = true;
            context.read<TaskCubit>().fetchTasks(filterBy: _filter, userId: _userId);
          }
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Task List',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: const Text('Manage Slots'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AvailabilityScreen()),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.indigo,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<UserCubit>().signOut();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out')),
                );
              }
            },
          ),
        ],
      ),
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
                  setState(() {
                    _isLoadingMore = false;
                  });
                } else if (state is TasksLoaded) {
                  setState(() {
                    if (_offset == 0) {
                      _tasks = state.tasks;
                    } else {
                      // Append and deduplicate by id
                      final existingIds = _tasks.map((t) => t.id).toSet();
                      final newOnes = state.tasks.where((t) => !existingIds.contains(t.id));
                      _tasks.addAll(newOnes);
                    }
                    _hasMore = state.tasks.length >= _pageSize;
                    _isLoadingMore = false;
                  });
                }
              },
              builder: (context, state) {
                if (state is TaskLoading && _tasks.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_tasks.isEmpty) return _buildEmptyState();
                return _buildTaskList(_tasks);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add,color: Colors.white,),
        label: const Text('Add Task',style: TextStyle(color: Colors.white,fontWeight: FontWeight.w600),), 
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TaskCreationScreen()),
          ).then((_) => _applyFilter(_filter));
        },
      ),
    ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const Text(
            'Filters:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.indigo : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_outlined, color: Colors.indigo.shade300, size: 80),
            const SizedBox(height: 20),
            Text(
              'No tasks found',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Click "Add Task" to create your first one.',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: tasks.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (_hasMore && index == tasks.length) {
              // Load more row
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Center(
                  child: _isLoadingMore
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(),
                        )
                      : OutlinedButton.icon(
                          icon: const Icon(Icons.expand_more),
                          label: const Text('Load more'),
                          onPressed: () {
                            setState(() {
                              _isLoadingMore = true;
                              _offset += _pageSize;
                            });
                            _fetchTasks();
                          },
                        ),
                ),
              );
            }

            final task = tasks[index];
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo.shade50,
                  radius: 24,
                  child: Icon(Icons.assignment_outlined,
                      color: Colors.indigo.shade700),
                ),
                title: Text(
                  task.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (task.description != null &&
                          task.description!.isNotEmpty)
                        Text(
                          task.description!,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 15, color: Colors.indigo),
                          const SizedBox(width: 4),
                          Text(
                            'Duration: ${task.durationMinutes} min',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      if (task.startTime != null && task.endTime != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 15, color: Colors.indigo),
                              const SizedBox(width: 4),
                              Text(
                                'Slot: ${DateFormat('MMM d, HH:mm').format(task.startTime!)} - ${DateFormat('HH:mm').format(task.endTime!)}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.people,
                                size: 15, color: Colors.indigo),
                            const SizedBox(width: 4),
                            Text(
                              'Collaborators: ${task.collaboratorIds.length}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
