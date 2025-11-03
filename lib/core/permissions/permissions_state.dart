class PermissionsState {
  const PermissionsState({
    required this.isGranted,
    this.isLoading = false,
    this.permanentlyDenied = false,
    this.message,
  });

  const PermissionsState.initial()
    : isGranted = false,
      isLoading = true,
      permanentlyDenied = false,
      message = null;

  final bool isGranted;
  final bool isLoading;
  final bool permanentlyDenied;
  final String? message;

  PermissionsState copyWith({
    bool? isGranted,
    bool? isLoading,
    bool? permanentlyDenied,
    String? message,
  }) {
    return PermissionsState(
      isGranted: isGranted ?? this.isGranted,
      isLoading: isLoading ?? this.isLoading,
      permanentlyDenied: permanentlyDenied ?? this.permanentlyDenied,
      message: message ?? this.message,
    );
  }
}
