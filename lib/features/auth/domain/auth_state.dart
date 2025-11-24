import 'user_role.dart';

class AuthState {
  const AuthState({
    required this.isAuthenticated,
    this.userId,
    this.displayName,
    this.isLoading = false,
    this.errorMessage,
    this.role = UserRole.collector,
  });

  const AuthState.initial()
    : isAuthenticated = false,
      userId = null,
      displayName = null,
      isLoading = false,
      errorMessage = null,
      role = UserRole.collector;

  final bool isAuthenticated;
  final String? userId;
  final String? displayName;
  final bool isLoading;
  final String? errorMessage;
  final UserRole role;

  bool get canManageAllCollectors => role.canManageAllCollectors;
  bool get isSuperAdmin => role.isSuperAdmin;

  AuthState copyWith({
    bool? isAuthenticated,
    String? userId,
    String? displayName,
    bool? isLoading,
    String? errorMessage,
    UserRole? role,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      role: role ?? this.role,
    );
  }
}
