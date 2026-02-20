import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    

    var appBar = AppBar(title: const Text("Customer Home"),
      actions: [TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              child: const Text("Logout"),
            )]);

            
    return Scaffold(
      appBar: appBar,
      body: Center(
        child: Column(
          children: [
            Text(
              "Customer Logged In Successfully",
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
