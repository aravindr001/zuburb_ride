import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zuburb_ride/bloc/ride/finding_driver_cubit.dart';
import 'package:zuburb_ride/bloc/ride/finding_driver_state.dart';

class FindingDriverScreen extends StatelessWidget {
  final String rideId;

  const FindingDriverScreen({
    super.key,
    required this.rideId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FindingDriverCubit, FindingDriverState>(
      listener: (context, state) {
        if (state is FindingDriverCancelled) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }

        if (state is FindingDriverFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Finding Driver'),
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, FindingDriverState state) {
    if (state is FindingDriverLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is FindingDriverNotFound) {
      return const Center(child: Text('Ride not found'));
    }

    if (state is FindingDriverAccepted) {
      return const Center(
        child: Text(
          'Driver Accepted! 🚗',
          style: TextStyle(fontSize: 22),
        ),
      );
    }

    if (state is FindingDriverCancelled) {
      return const Center(child: Text('Ride Cancelled'));
    }

    if (state is FindingDriverFailure) {
      return Center(child: Text(state.message));
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text('Looking for nearby drivers...'),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => context.read<FindingDriverCubit>().cancelRide(),
            child: const Text('Cancel Ride'),
          ),
        ],
      ),
    );
  }
}