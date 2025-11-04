import 'package:collecte_revendeurs/features/boutiques/data/boutique_repository.dart';
import 'package:collecte_revendeurs/features/boutiques/application/boutique_controller.dart';
import 'package:collecte_revendeurs/features/boutiques/data/firebase_boutique_repository.dart';
import 'package:collecte_revendeurs/features/boutiques/domain/boutique.dart';
import 'package:collecte_revendeurs/features/boutiques/presentation/pages/boutique_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'desactive la sauvegarde tant que le numero de telephone n\'est pas valide',
    (tester) async {
      final repository = _StubBoutiqueRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [boutiqueRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: BoutiqueFormPage()),
        ),
      );

      await tester.pumpAndSettle();

      final context = tester.element(find.byType(BoutiqueFormPage));
      final container = ProviderScope.containerOf(context);
      final controller = container.read(
        boutiqueListControllerProvider.notifier,
      );
      controller.state = controller.state.copyWith(isLoading: false);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Telephone'),
        '0700000000',
      );
      await tester.pump();

      final buttonFinder = find.byKey(const Key('boutique-form-submit-button'));
      expect(buttonFinder, findsOneWidget);

      final FilledButton disabledButtonBefore = tester.widget<FilledButton>(
        buttonFinder,
      );
      expect(disabledButtonBefore.onPressed, isNull);

      final verifierFinder = find.byTooltip('Verifier le numero');
      await tester.ensureVisible(verifierFinder);
      await tester.tap(verifierFinder);
      await tester.pumpAndSettle();

      final FilledButton enabledButtonAfter = tester.widget<FilledButton>(
        buttonFinder,
      );
      expect(enabledButtonAfter.onPressed, isNotNull);
    },
  );
}

class _StubBoutiqueRepository implements BoutiqueRepository {
  bool telephoneAvailable = true;

  @override
  Future<List<Boutique>> loadBoutiques() async => <Boutique>[];

  @override
  Future<Boutique> create(Boutique boutique) async => boutique;

  @override
  Future<Boutique> update(Boutique boutique) async => boutique;

  @override
  Future<bool> isTelephoneAvailable(
    String telephone, {
    String? excludeId,
  }) async => telephoneAvailable;
}
