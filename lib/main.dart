import 'package:flutter/material.dart';
import 'package:metermate_frontend/widgets/auth_wrapper.dart';
import 'package:metermate_frontend/screens/login_screen.dart';
import 'package:metermate_frontend/screens/signup_screen.dart';
import 'package:metermate_frontend/screens/home_screen.dart';
import 'package:metermate_frontend/screens/jobs_screen.dart';
import 'package:metermate_frontend/screens/todays_jobs_screen.dart';
import 'package:metermate_frontend/services/config_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeterMate',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/jobs': (context) => const JobsScreen(),
        '/todays-jobs': (context) => const TodaysJobsScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
} 