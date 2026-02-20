import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';

class OtpScreen extends StatelessWidget {
  final String verificationId;

  OtpScreen({super.key, required this.verificationId});

  final TextEditingController otpController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Enter OTP")),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          // if (state is AuthSuccess) {
          //   Navigator.pushNamedAndRemoveUntil(context, "/home", (route) => false);
          // }
          if (state is AuthSuccess) {
            Navigator.pop(context);
          }

          if (state is AuthError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "OTP"),
                ),
                const SizedBox(height: 20),
                if (state is AuthLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: () {
                      context.read<AuthBloc>().add(
                        VerifyOtpEvent(
                          verificationId,
                          otpController.text.trim(),
                        ),
                      );
                    },
                    child: const Text("Verify OTP"),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
