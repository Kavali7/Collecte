enum UserRole {
  collector,
  admin,
  superAdmin,
}

extension UserRoleX on UserRole {
  bool get canManageAllCollectors =>
      this == UserRole.admin || this == UserRole.superAdmin;

  bool get isSuperAdmin => this == UserRole.superAdmin;
}

UserRole userRoleFromClaim(Object? rawClaim) {
  if (rawClaim == null) return UserRole.collector;
  final value = rawClaim.toString();
  switch (value) {
    case 'admin':
      return UserRole.admin;
    case 'super_admin':
      return UserRole.superAdmin;
    default:
      return UserRole.collector;
  }
}
