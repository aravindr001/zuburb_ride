import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController nameController = TextEditingController();
  bool isLoading = false;

  Future<void> saveProfile() async {
    final name = nameController.text.trim();

    if (name.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await FirebaseFirestore.instance.collection("customers").doc(user.uid)
      .set({
        "name": name,
        "phone": user.phoneNumber,
        "totalRides": 0,
        "currentRideId": null,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });

    if (!mounted) return;

    Navigator.pop(context);
    // AuthWrapper will now detect user exists and show Home
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Complete Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Enter your name"),
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: saveProfile,
                    child: const Text("Save"),
                  ),
          ],
        ),
      ),
    );
  }
}
