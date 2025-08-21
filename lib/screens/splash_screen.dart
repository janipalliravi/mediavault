import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../env.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Small splash delay (skip in tests)
      if (!AppEnv.testMode) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
      if (!mounted) return;
      // Try auth, but never block navigation
      try {
        if (!AppEnv.testMode) {
          await _authenticate().timeout(const Duration(seconds: 3));
        }
      } catch (_) {}
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/');
    });
  }

  Future<bool> _authenticate() async {
    // Use AuthService for local auth
    return AuthService().authenticateWithBiometricsOrPin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/mediavault_logo.png',
                height: 150,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.lock, size: 120, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}


