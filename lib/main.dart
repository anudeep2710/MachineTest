import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tc/cubits/availability_cubit.dart';
import 'cubits/task_cubit.dart';
import 'cubits/user_cubit.dart';
import 'screens/onboarding_screen.dart';
import 'screens/task_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://kntrzuiotxxugvmkrbzm.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtudHJ6dWlvdHh4dWd2bWtyYnptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk4MTMwMzYsImV4cCI6MjA3NTM4OTAzNn0.nFZCTS5-_6GiS8sa-RhBnBwLOHuvLb8ROKJiZzX9AXc',
  );

  runApp(MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => UserCubit()),
      BlocProvider(create: (_) => AvailabilityCubit()),
      BlocProvider(create: (_) => TaskCubit()),
    ],
    child: const MyApp(),
  ),);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Team Scheduler',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
        ),
      ),
      home: BlocBuilder<UserCubit, UserState>(
        builder: (context, state) {
          if (state is UserCreated) {
            // User is authenticated, show task list
            return const TaskListScreen();
          } else {
            // User is not authenticated, show onboarding
            return const OnboardingScreen();
          }
        },
      ),
    );
  }
}