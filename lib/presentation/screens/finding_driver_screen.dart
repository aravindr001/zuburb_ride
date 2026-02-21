import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FindingDriverScreen extends StatefulWidget {
  final String rideId;

  const FindingDriverScreen({
    super.key,
    required this.rideId,
  });

  @override
  State<FindingDriverScreen> createState() =>
      _FindingDriverScreenState();
}

class _FindingDriverScreenState
    extends State<FindingDriverScreen> {

  late final Stream<DocumentSnapshot> _rideStream;

  @override
  void initState() {
    super.initState();
    _rideStream = FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .snapshots();
  }

  void _cancelRide() async {
    await FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .update({
      "status": "cancelled",
    });

    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Finding Driver"),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _rideStream,
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data =
              snapshot.data!.data() as Map<String, dynamic>?;

          if (data == null) {
            return const Center(
              child: Text("Ride not found"),
            );
          }

          final status = data['status'];

          if (status == "accepted") {
            return const Center(
              child: Text(
                "Driver Accepted! 🚗",
                style: TextStyle(fontSize: 22),
              ),
            );
          }

          if (status == "cancelled") {
            return const Center(
              child: Text("Ride Cancelled"),
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text(
                  "Looking for nearby drivers...",
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _cancelRide,
                  child: const Text("Cancel Ride"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}