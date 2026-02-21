import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'select_location_screen.dart';
import 'ride_confirmation_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("ZUBURB RIDE", style: TextStyle(letterSpacing: 6)),
        actions: [TextButton(onPressed: () async{
          await FirebaseAuth.instance.signOut();
        }, child: Text("Logout"))],
      ),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
          ),
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SelectLocationScreen()),
            );

            if (result != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RideConfirmationScreen(
                    pickup: result['pickup'],
                    drop: result['drop'],
                  ),
                ),
              );
            }
          },
          child: const Text("Where to?", style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}
