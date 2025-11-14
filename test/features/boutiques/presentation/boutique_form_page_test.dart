import 'package:collecte_revendeurs/features/auth/controllers/auth_controller.dart';
import 'package:collecte_revendeurs/core/network/connectivity_providers.dart';
import 'package:collecte_revendeurs/features/boutiques/data/boutique_repository.dart';
import 'package:collecte_revendeurs/features/boutiques/application/boutique_controller.dart';
import 'package:collecte_revendeurs/features/boutiques/data/firebase_boutique_repository.dart';
import 'package:collecte_revendeurs/features/boutiques/domain/boutique.dart';
import 'package:collecte_revendeurs/features/boutiques/presentation/pages/boutique_form_page.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils/fake_connectivity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'desactive la sauvegarde tant que le numero de telephone n\'est pas valide',
    (tester) async {
      final repository = _StubBoutiqueRepository();
      final connectivity = FakeConnectivityService(initiallyOnline: true);
      addTearDown(connectivity.dispose);
      final mockAuth = MockFirebaseAuth(
        mockUser: MockUser(
          uid: 'tester',
          email: 'tester@example.com',
        ),
        signedIn: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            boutiqueRepositoryProvider.overrideWithValue(repository),
            firebaseAuthProvider.overrideWithValue(mockAuth),
            authControllerProvider.overrideWith((ref) => AuthController(mockAuth)),
            connectivityServiceProvider.overrideWithValue(connectivity),
          ],
          child: const MaterialApp(home: BoutiqueFormPage()),
        ),
      );

      await tester.pumpAndSettle();

      final dropdownFinder =
          find.byType(DropdownButtonFormField<BoutiqueSpecialite>);
      await tester.ensureVisible(dropdownFinder);
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Telephone').last);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(BoutiqueFormPage));
      final container = ProviderScope.containerOf(context);
      final controller = container.read(
        boutiqueListControllerProvider.notifier,
      );
      controller.state = controller.state.copyWith(isLoading: false);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Telephone 1'),
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

  testWidgets('affiche un voile hors ligne lorsque la connexion manque', (
    tester,
  ) async {
    final repository = _StubBoutiqueRepository();
    final connectivity = FakeConnectivityService(initiallyOnline: false);
    addTearDown(connectivity.dispose);
    final mockAuth = MockFirebaseAuth(
      mockUser: MockUser(uid: 'tester', email: 'tester@example.com'),
      signedIn: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          boutiqueRepositoryProvider.overrideWithValue(repository),
          firebaseAuthProvider.overrideWithValue(mockAuth),
          authControllerProvider.overrideWith((ref) => AuthController(mockAuth)),
          connectivityServiceProvider.overrideWithValue(connectivity),
        ],
        child: const MaterialApp(home: BoutiqueFormPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Connexion perdue'), findsOneWidget);
    expect(
      find.textContaining('Reconnecte-toi a Internet'),
      findsOneWidget,
    );
  });
}

class _StubBoutiqueRepository implements BoutiqueRepository {
  bool telephoneAvailable = true;

  @override
  Future<List<Boutique>> loadBoutiques(
    String collectorId, {
    DateTime? forDate,
  }) async =>
      <Boutique>[];

  @override
  Future<Boutique> create(Boutique boutique) async => boutique;

  @override
  Future<Boutique> update(Boutique boutique) async => boutique;

  @override
  Future<bool> isTelephoneAvailable(
    String collectorId,
    String telephone, {
    String? excludeId,
  }) async => telephoneAvailable;
}
