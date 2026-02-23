import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:zuburb_ride/bloc/ride/ride_rating_cubit.dart';
import 'package:zuburb_ride/bloc/ride/ride_rating_state.dart';

class RateGuardScreen extends StatelessWidget {
  const RateGuardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RideRatingCubit, RideRatingState>(
      listener: (context, state) {
        if (state is RideRatingSubmitted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
            arguments: const {'skipAutoResumeRide': true},
          );
          return;
        }

        if (state is RideRatingFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        final isSubmitting = state is RideRatingSubmitting;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Rate Guard'),
            automaticallyImplyLeading: false,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                const Text(
                  'How was your ride?\nRate your guard',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                _StarsRow(
                  rating: state.rating,
                  enabled: !isSubmitting,
                  onSelect: (value) => context.read<RideRatingCubit>().setRating(value),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : () => context.read<RideRatingCubit>().submit(),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit Rating'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StarsRow extends StatelessWidget {
  final int rating;
  final bool enabled;
  final ValueChanged<int> onSelect;

  const _StarsRow({
    required this.rating,
    required this.enabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final value = index + 1;
        final selected = value <= rating;
        return IconButton(
          onPressed: enabled ? () => onSelect(value) : null,
          icon: Icon(
            selected ? Icons.star : Icons.star_border,
            size: 36,
          ),
        );
      }),
    );
  }
}
