class AuthState {
  const AuthState({
    required this.isAuthenticated,
    this.displayName,
    this.isLoading = false,
    this.errorMessage,
  });

  const AuthState.initial()
    : isAuthenticated = false,
      displayName = null,
      isLoading = false,
      errorMessage = null;

  final bool isAuthenticated;
  final String? displayName;
  final bool isLoading;
  final String? errorMessage;

  AuthState copyWith({
    bool? isAuthenticated,
    String? displayName,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      displayName: displayName ?? this.displayName,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
