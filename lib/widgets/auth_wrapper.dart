import 'package:flutter/material.dart';
import 'package:metermate_frontend/screens/home_screen.dart';
import 'package:metermate_frontend/screens/login_screen.dart';
import 'package:metermate_frontend/services/auth_service.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authService.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a loading indicator while checking auth state
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else {
          if (snapshot.hasData && snapshot.data == true) {
            // User is logged in, show HomeScreen
            return const HomeScreen();
          } else {
            // User is not logged in, show LoginScreen
            return const LoginScreen();
          }
        }
      },
    );
  }
} 