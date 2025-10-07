import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../cubits/user_cubit.dart';
import 'availability_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  XFile? _pickedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (file != null) setState(() => _pickedImage = file);
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name')),
      );
      return;
    }
    context.read<UserCubit>().createUser(name: name, image: _pickedImage);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;
    final double cardWidth = isWide ? size.width * 0.4 : size.width * 0.9;
    final double avatarSize = isWide ? 80 : 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Profile',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: cardWidth),
            child: BlocConsumer<UserCubit, UserState>(
              listener: (context, state) {
                if (state is UserCreated) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Profile created successfully')),
                  );

                  // Navigate to Availability page
                  Future.delayed(const Duration(milliseconds: 500), () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AvailabilityScreen()),
                    );
                  });
                } else if (state is UserError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${state.message}')),
                  );
                }
              },
              builder: (context, state) {
                final loading = state is UserLoading;
                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          'Welcome to Team Scheduler',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade800,
                              ),
                        ),
                        const SizedBox(height: 24),

                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              _pickedImage == null
                                  ? CircleAvatar(
                                      radius: avatarSize,
                                      backgroundColor: Colors.grey.shade200,
                                      child: Icon(
                                        Icons.person,
                                        size: avatarSize,
                                        color: Colors.grey.shade600,
                                      ),
                                    )
                                  : kIsWeb
                                      ? ClipOval(
                                          child: Image.network(
                                            _pickedImage!.path,
                                            width: avatarSize * 2,
                                            height: avatarSize * 2,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : CircleAvatar(
                                          radius: avatarSize,
                                          backgroundImage: FileImage(
                                              File(_pickedImage!.path)),
                                        ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: Colors.indigo,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo.shade600,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: loading ? null : _submit,
                            child: loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Create Account',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        if (state is UserCreated)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.green.shade200,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Profile created: ${state.userRow['name']}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (state is UserError)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Error: ${state.message}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
