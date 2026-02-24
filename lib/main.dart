import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zuburb_ride/bloc/auth/auth_bloc.dart';
import 'package:zuburb_ride/bloc/auth/auth_status_cubit.dart';
import 'package:zuburb_ride/presentation/screens/auth_wrapper.dart';
import 'package:zuburb_ride/presentation/screens/home_screen.dart';
import 'package:zuburb_ride/presentation/screens/profile_screen.dart';
import 'package:zuburb_ride/bloc/profile/profile_cubit.dart';
import 'package:zuburb_ride/repository/auth_repository.dart';
import 'package:zuburb_ride/repository/ride_repository.dart';
import 'package:zuburb_ride/services/local_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await LocalNotificationService.initialize();
  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => AuthRepository()),
        RepositoryProvider(create: (_) => RideRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(context.read<AuthRepository>()),
          ),
          BlocProvider(
            create: (context) => AuthStatusCubit(context.read<AuthRepository>()),
          ),
        ],
        child: const MyApp(),
      ),
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AuthWrapper(),
      routes: {
        "/home": (context) => const HomeScreen(),
        "/profile": (context) => BlocProvider(
              create: (_) => ProfileCubit(),
              child: const ProfileScreen(),
            ),
      },
      debugShowCheckedModeBanner: false,
    );
  }

}
