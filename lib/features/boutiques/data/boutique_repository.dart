import '../domain/boutique.dart';

abstract class BoutiqueRepository {
  Future<List<Boutique>> loadBoutiques();
  Future<Boutique> create(Boutique boutique);
  Future<Boutique> update(Boutique boutique);
  Future<bool> isTelephoneAvailable(String telephone, {String? excludeId});
}
