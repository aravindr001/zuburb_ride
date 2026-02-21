import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zuburb_ride/bloc/auth/auth_bloc.dart';
import 'package:zuburb_ride/presentation/screens/auth_wrapper.dart';
import 'package:zuburb_ride/presentation/screens/home_screen.dart';
import 'package:zuburb_ride/presentation/screens/profile_screen.dart';
import 'package:zuburb_ride/repository/auth_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    MultiBlocProvider(
      providers: [BlocProvider(create: (_) => AuthBloc(AuthRepository()))],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const AuthWrapper(),
      routes: {
        "/home": (context) => const HomeScreen(),
        "/profile": (context) => const ProfileScreen(),
      },
    );
  }
}
