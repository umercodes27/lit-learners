enum ParentRole { parent, admin }

class ParentAccount {
  const ParentAccount({
    required this.id,
    required this.email,
    required this.createdAt,
    this.role = ParentRole.parent,
  });

  final String id;
  final String email;
  final DateTime createdAt;
  final ParentRole role;

  bool get canManageAdminContent => role == ParentRole.admin;

  ParentAccount copyWith({
    String? id,
    String? email,
    DateTime? createdAt,
    ParentRole? role,
  }) {
    return ParentAccount(
      id: id ?? this.id,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      role: role ?? this.role,
    );
  }
}
