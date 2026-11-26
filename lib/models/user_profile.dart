import 'exercise.dart';

enum Gender { male, female }

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.age,
    this.weightKg,
    this.heightCm,
    this.gender,
    this.level,
    this.voiceCoaching = true,
  });

  final String uid;
  final String name;
  final String email;
  final int? age;
  final double? weightKg;
  final double? heightCm;
  final Gender? gender;
  final Level? level;

  /// Speak rep counts and form cues during workouts.
  final bool voiceCoaching;

  /// Sign-up is two steps; the second (gender + level) may still be missing.
  bool get isComplete => gender != null && level != null;

  Level get levelOrDefault => level ?? Level.beginner;


  double? get bmi {
    final w = weightKg, h = heightCm;
    if (w == null || h == null || h == 0) return null;
    return w / ((h / 100) * (h / 100));
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    T? enumByName<T extends Enum>(List<T> values, Object? name) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return null;
    }

    return UserProfile(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      age: (map['age'] as num?)?.toInt(),
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      gender: enumByName(Gender.values, map['gender']),
      level: enumByName(Level.values, map['level']),
      voiceCoaching: map['voiceCoaching'] as bool? ?? true,
    );
  }

  /// Note: no password here — Firebase Authentication stores credentials.
  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'age': age,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'gender': gender?.name,
        'level': level?.name,
        'voiceCoaching': voiceCoaching,
      };

  UserProfile copyWith({
    String? name,
    int? age,
    double? weightKg,
    double? heightCm,
    Gender? gender,
    Level? level,
    bool? voiceCoaching,
  }) =>
      UserProfile(
        uid: uid,
        email: email,
        name: name ?? this.name,
        age: age ?? this.age,
        weightKg: weightKg ?? this.weightKg,
        heightCm: heightCm ?? this.heightCm,
        gender: gender ?? this.gender,
        level: level ?? this.level,
        voiceCoaching: voiceCoaching ?? this.voiceCoaching,
      );
}
