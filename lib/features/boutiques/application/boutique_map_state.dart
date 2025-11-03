import '../domain/boutique.dart';

class BoutiqueMapState {
  const BoutiqueMapState({
    this.boutiques = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.isOffline = false,
    this.errorMessage,
  });

  const BoutiqueMapState.initial()
    : boutiques = const [],
      isLoading = true,
      isSyncing = false,
      isOffline = false,
      errorMessage = null;

  final List<Boutique> boutiques;
  final bool isLoading;
  final bool isSyncing;
  final bool isOffline;
  final String? errorMessage;

  BoutiqueMapState copyWith({
    List<Boutique>? boutiques,
    bool? isLoading,
    bool? isSyncing,
    bool? isOffline,
    String? errorMessage,
    bool resetError = false,
  }) {
    return BoutiqueMapState(
      boutiques: boutiques ?? this.boutiques,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      isOffline: isOffline ?? this.isOffline,
      errorMessage: resetError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
