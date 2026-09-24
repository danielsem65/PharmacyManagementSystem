/// Authenticated app user derived from the server `login_context` RPC.
class AppUser {
  AppUser({
    required this.id,
    required this.fullName,
    required this.role,
    required this.branchId,
    required this.permissions,
    this.email,
    this.settings = const {},
  });

  factory AppUser.fromContext(Map<String, dynamic> json) {
    final profile = (json['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
    final permsRaw = (json['permissions'] as List?) ?? const [];
    final settings = (json['settings'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AppUser(
      id: (profile['id'] ?? '').toString(),
      fullName: (profile['full_name'] ?? '').toString(),
      role: (profile['role'] ?? 'staff').toString(),
      branchId: (profile['branch_id'] as String?) ?? '',
      email: (profile['email'] as String?) ?? '',
      permissions: permsRaw.map((e) => e.toString()).toSet(),
      settings: settings,
    );
  }

  final String id;
  final String fullName;
  final String role;
  final String branchId;
  final String? email;
  final Set<String> permissions;
  final Map<String, dynamic> settings;

  bool can(String permission) => permissions.contains(permission);

  bool get isOwner => role == 'owner';
  bool get isManager => role == 'manager' || isOwner;
}