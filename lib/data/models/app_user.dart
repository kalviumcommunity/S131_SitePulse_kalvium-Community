enum UserRole {
  supervisor,
  pm;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => UserRole.supervisor,
    );
  }
}

class AppUser {
  final String uid;
  final UserRole role;
  final String name;
  final String? siteId;
  final String? email;
  final bool hasPendingWrites;

  const AppUser({
    required this.uid,
    required this.role,
    required this.name,
    this.siteId,
    this.email,
    this.hasPendingWrites = false,
  });

  AppUser copyWith({
    String? uid,
    UserRole? role,
    String? name,
    String? siteId,
    String? email,
    bool? hasPendingWrites,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      name: name ?? this.name,
      siteId: siteId ?? this.siteId,
      email: email ?? this.email,
      hasPendingWrites: hasPendingWrites ?? this.hasPendingWrites,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'role': role.name,
      'name': name,
      if (siteId != null) 'siteId': siteId,
      'hasPendingWrites': hasPendingWrites,
    };
  }

  factory AppUser.fromMap(
    Map<String, dynamic> map, {
    bool hasPendingWrites = false,
  }) {
    return AppUser(
      uid: map['uid'] as String? ?? '',
      role: map['role'] is String
          ? UserRole.fromString(map['role'] as String)
          : (map['role'] as UserRole? ?? UserRole.supervisor),
      name: map['name'] as String? ?? '',
      siteId: map['siteId'] as String?,
      hasPendingWrites: (map['hasPendingWrites'] as bool?) ?? hasPendingWrites,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          role == other.role &&
          name == other.name &&
          siteId == other.siteId &&
          email == other.email &&
          hasPendingWrites == other.hasPendingWrites;

  @override
  int get hashCode =>
      Object.hash(uid, role, name, siteId, email, hasPendingWrites);

  @override
  String toString() =>
      'AppUser(uid: $uid, role: ${role.name}, name: $name, siteId: $siteId, email: $email, hasPendingWrites: $hasPendingWrites)';
}
