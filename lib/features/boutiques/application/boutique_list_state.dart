import '../domain/boutique.dart';

class BoutiqueListState {
  const BoutiqueListState({
    required this.boutiques,
    this.isLoading = false,
    this.searchTerm = '',
  });

  const BoutiqueListState.initial()
    : boutiques = const [],
      isLoading = true,
      searchTerm = '';

  final List<Boutique> boutiques;
  final bool isLoading;
  final String searchTerm;

  List<Boutique> get filteredBoutiques {
    final query = searchTerm.trim().toLowerCase();
    return boutiques.where((boutique) {
      if (query.isEmpty) return true;
      return boutique.nom.toLowerCase().contains(query) ||
          boutique.nomGerantComplet.toLowerCase().contains(query) ||
          boutique.telephone.toLowerCase().contains(query);
    }).toList()..sort(
      (a, b) => (b.dateDeVisite ?? DateTime(1970)).compareTo(
        a.dateDeVisite ?? DateTime(1970),
      ),
    );
  }

  BoutiqueListState copyWith({
    List<Boutique>? boutiques,
    bool? isLoading,
    String? searchTerm,
  }) {
    return BoutiqueListState(
      boutiques: boutiques ?? this.boutiques,
      isLoading: isLoading ?? this.isLoading,
      searchTerm: searchTerm ?? this.searchTerm,
    );
  }
}
