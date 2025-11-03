// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collecte_revendeurs/app.dart';
import 'package:collecte_revendeurs/core/permissions/permissions_controller.dart';
import 'package:collecte_revendeurs/core/permissions/permissions_state.dart';

void main() {
  testWidgets('affiche la page de connexion', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          permissionsControllerProvider.overrideWith(
            (ref) => _AlwaysGrantedPermissionsController(),
          ),
        ],
        child: const CollecteApp(),
      ),
    );

    expect(find.textContaining('Collecte des revendeurs'), findsOneWidget);
    expect(find.text('Connexion email'), findsOneWidget);
  });
}

class _AlwaysGrantedPermissionsController extends PermissionsController {
  _AlwaysGrantedPermissionsController() {
    state = const PermissionsState(isGranted: true, isLoading: false);
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> openSettings() async {}
}
