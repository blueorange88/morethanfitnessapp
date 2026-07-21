import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_page.dart';
import 'onboarding_page.dart';

class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkAndRoute();
  }

  Future<void> _checkAndRoute() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('trainer_profile')
          .doc('me')
          .get();

      final data = doc.data();
      final onboardingCompleted = data?['onboardingCompleted'] == true;
      final displayName = (data?['displayName'] ?? '').toString().trim();

      final shouldGoHome = doc.exists && onboardingCompleted && displayName.isNotEmpty;

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => shouldGoHome
              ? const HomePage()
              : const OnboardingPage(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const OnboardingPage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF3F4F6),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF4F46E5),
        ),
      ),
    );
  }
}