import '../domain/boutique.dart';

abstract class BoutiqueRepository {
  Future<List<Boutique>> loadBoutiques(
    String collectorId, {
    DateTime? forDate,
  });
  Future<List<Boutique>> loadAllBoutiques({DateTime? forDate});
  Future<Boutique> create(Boutique boutique);
  Future<Boutique> update(Boutique boutique);
  Future<bool> isTelephoneAvailable(
    String collectorId,
    String telephone, {
    String? excludeId,
  });
}
