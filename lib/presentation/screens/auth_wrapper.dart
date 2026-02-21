import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zuburb_ride/bloc/auth/auth_status_cubit.dart';
import 'package:zuburb_ride/bloc/auth/auth_status_state.dart';
import 'package:zuburb_ride/presentation/screens/home_screen.dart';
import 'login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthStatusCubit, AuthStatusState>(
      builder: (context, state) {
        if (state is AuthStatusLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is AuthStatusAuthenticated) {
          return const HomeScreen();
        }

        if (state is AuthStatusFailure) {
          return Scaffold(
            body: Center(
              child: Text(state.message),
            ),
          );
        }

        return LoginScreen();
      },
    );
  }
}
