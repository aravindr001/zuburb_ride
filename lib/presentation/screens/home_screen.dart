import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zuburb_ride/bloc/auth/auth_status_cubit.dart';
import 'package:zuburb_ride/bloc/location/select_location_cubit.dart';
import 'package:zuburb_ride/bloc/ride/ride_confirmation_cubit.dart';
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
        actions: [
          TextButton(
            onPressed: () => context.read<AuthStatusCubit>().signOut(),
            child: const Text("Logout"),
          )
        ],
      ),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
          ),
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider(
                  create: (_) => SelectLocationCubit()..init(),
                  child: const SelectLocationScreen(),
                ),
              ),
            );

            if (!context.mounted) return;

            if (result != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider(
                    create: (_) => RideConfirmationCubit(
                      pickup: result['pickup'],
                      drop: result['drop'],
                    )..init(),
                    child: RideConfirmationScreen(
                      pickup: result['pickup'],
                      drop: result['drop'],
                    ),
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
