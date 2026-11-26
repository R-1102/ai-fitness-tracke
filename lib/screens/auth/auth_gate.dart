import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/services.dart';
import '../home/home_shell.dart';
import 'profile_setup_screen.dart';
import 'welcome_screen.dart';

/// Decides what to show based on auth + profile state:
/// signed out -> Welcome, profile incomplete -> Setup, otherwise -> Home.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) return const _Loading();
        final user = authSnap.data;
        if (user == null) return const WelcomeScreen();

        return StreamBuilder<UserProfile?>(
          key: ValueKey(user.uid),
          stream: userRepository.watchProfile(user.uid),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) return const _Loading();
            final profile = profileSnap.data;
            if (profile == null || !profile.isComplete) {
              return ProfileSetupScreen(
                profile: profile ?? UserProfile(uid: user.uid, name: '', email: user.email ?? ''),
              );
            }
            return ProfileScope(profile: profile, child: const HomeShell());
          },
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
