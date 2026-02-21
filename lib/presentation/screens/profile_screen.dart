import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zuburb_ride/bloc/profile/profile_cubit.dart';
import 'package:zuburb_ride/bloc/profile/profile_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController nameController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state is ProfileSaved) {
          Navigator.pop(context);
        }

        if (state is ProfileFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        final isSaving = state is ProfileSaving;

        return Scaffold(
          appBar: AppBar(title: const Text('Complete Profile')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Enter your name'),
                ),
                const SizedBox(height: 20),
                isSaving
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: () => context
                            .read<ProfileCubit>()
                            .saveProfile(name: nameController.text),
                        child: const Text('Save'),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}
