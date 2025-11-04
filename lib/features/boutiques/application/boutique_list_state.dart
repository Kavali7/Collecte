import 'collector_dashboard_metrics.dart';
import '../domain/boutique.dart';

class BoutiqueListState {
  const BoutiqueListState({
    required this.boutiques,
    this.isLoading = false,
    this.searchTerm = '',
    this.isOfflineFallback = false,
  });

  const BoutiqueListState.initial()
    : boutiques = const [],
      isLoading = true,
      searchTerm = '',
      isOfflineFallback = false;

  final List<Boutique> boutiques;
  final bool isLoading;
  final String searchTerm;
  final bool isOfflineFallback;

  List<Boutique> get filteredBoutiques {
    final query = searchTerm.trim().toLowerCase();
    return boutiques.where((boutique) {
      if (query.isEmpty) return true;
      final matchesNom = boutique.nom.toLowerCase().contains(query);
      final matchesGerant = boutique.nomGerantComplet.toLowerCase()
          .contains(query);
      final matchesTelephone = boutique.telephones.any(
        (telephone) => telephone.toLowerCase().contains(query),
      );
      final matchesAddress =
          (boutique.adresse?.toLowerCase().contains(query) ?? false);
      return matchesNom || matchesGerant || matchesTelephone || matchesAddress;
    }).toList()..sort(
      (a, b) => (b.dateDeVisite ?? DateTime(1970)).compareTo(
        a.dateDeVisite ?? DateTime(1970),
      ),
    );
  }

  CollectorDashboardMetrics get dashboardMetrics =>
      CollectorDashboardMetrics.from(filteredBoutiques);

  BoutiqueListState copyWith({
    List<Boutique>? boutiques,
    bool? isLoading,
    String? searchTerm,
    bool? isOfflineFallback,
  }) {
    return BoutiqueListState(
      boutiques: boutiques ?? this.boutiques,
      isLoading: isLoading ?? this.isLoading,
      searchTerm: searchTerm ?? this.searchTerm,
      isOfflineFallback: isOfflineFallback ?? this.isOfflineFallback,
    );
  }
}
