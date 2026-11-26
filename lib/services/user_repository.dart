import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import '../models/workout_session.dart';

/// Firestore layout:
///   users/{uid}                     -> profile
///   users/{uid}/sessions/{id}       -> workout history
class UserRepository {
  UserRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) => _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _sessions(String uid) =>
      _userDoc(uid).collection('sessions');

  Stream<UserProfile?> watchProfile(String uid) => _userDoc(uid).snapshots().map(
        (snap) => snap.exists ? UserProfile.fromMap(uid, snap.data()!) : null,
      );

  Future<void> saveProfile(UserProfile profile) => _userDoc(profile.uid).set(
        {...profile.toMap(), 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

  Future<void> addSession(String uid, WorkoutSession session) =>
      _sessions(uid).add(session.toMap());

  Stream<List<WorkoutSession>> watchSessions(String uid, {int limit = 100}) => _sessions(uid)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((q) => q.docs.map(WorkoutSession.fromDoc).toList());

  /// Removes all user data (called before deleting the auth account).
  Future<void> deleteAllData(String uid) async {
    final sessions = await _sessions(uid).get();
    final batch = _db.batch();
    for (final doc in sessions.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_userDoc(uid));
    await batch.commit();
  }
}
