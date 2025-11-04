class AuthState {
  const AuthState({
    required this.isAuthenticated,
    this.userId,
    this.displayName,
    this.isLoading = false,
    this.errorMessage,
  });

  const AuthState.initial()
    : isAuthenticated = false,
      userId = null,
      displayName = null,
      isLoading = false,
      errorMessage = null;

  final bool isAuthenticated;
  final String? userId;
  final String? displayName;
  final bool isLoading;
  final String? errorMessage;

  AuthState copyWith({
    bool? isAuthenticated,
    String? userId,
    String? displayName,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
