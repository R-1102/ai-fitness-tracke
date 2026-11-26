import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../models/workout_session.dart';
import 'auth_service.dart';
import 'user_repository.dart';

/// App-wide service instances. Top-level finals in Dart are created lazily,
/// so these are only built after `Firebase.initializeApp()` has run.
final authService = AuthService();
final userRepository = UserRepository();

/// Makes the signed-in user's profile available to every screen below it.
class ProfileScope extends InheritedWidget {
  const ProfileScope({super.key, required this.profile, required super.child});

  final UserProfile profile;

  static UserProfile of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ProfileScope>();
    assert(scope != null, 'No ProfileScope found in context');
    return scope!.profile;
  }

  @override
  bool updateShouldNotify(ProfileScope oldWidget) => oldWidget.profile != profile;
}

/// Pushed routes live outside the HomeShell, so they don't see its scopes.
/// This carries the current profile + history into the new route.
Route<T> scopedRoute<T>(BuildContext context, Widget child) {
  final profile = ProfileScope.of(context);
  final sessions = SessionsScope.of(context);
  return MaterialPageRoute<T>(
    builder: (_) => ProfileScope(profile: profile, child: SessionsScope(sessions: sessions, child: child)),
  );
}

/// Latest workout history of the signed-in user (newest first).
class SessionsScope extends InheritedWidget {
  const SessionsScope({super.key, required this.sessions, required super.child});

  final List<WorkoutSession> sessions;

  static List<WorkoutSession> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionsScope>()?.sessions ?? const [];

  @override
  bool updateShouldNotify(SessionsScope oldWidget) => oldWidget.sessions != sessions;
}
