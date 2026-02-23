class Profile {
  final String id;
  final String displayName;
  final String? householdId;
  final String? role; // 'owner' | 'member' | null until household assigned
  final String authType; // 'full' | 'anonymous'
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    required this.displayName,
    this.householdId,
    this.role,
    required this.authType,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasHousehold => householdId != null;
  bool get isAnonymous => authType == 'anonymous';
  bool get isOwner => role == 'owner';

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    displayName: json['display_name'] as String,
    householdId: json['household_id'] as String?,
    role: json['role'] as String?,
    authType: json['auth_type'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Profile copyWith({
    String? displayName,
    String? householdId,
    String? role,
    String? authType,
  }) => Profile(
    id: id,
    displayName: displayName ?? this.displayName,
    householdId: householdId ?? this.householdId,
    role: role ?? this.role,
    authType: authType ?? this.authType,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
