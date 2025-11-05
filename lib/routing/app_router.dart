import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/controllers/auth_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/boutiques/presentation/pages/boutique_detail_page.dart';
import '../features/boutiques/presentation/pages/boutique_form_page.dart';
import '../features/boutiques/presentation/pages/boutique_list_page.dart';
import '../features/boutiques/presentation/pages/boutique_map_page.dart';
import '../features/itinerary/presentation/agent_itinerary_page.dart';
import 'app_route.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/auth',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: '/auth',
        name: AppRoute.auth.name,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/itineraire',
        name: AppRoute.agentItinerary.name,
        builder: (context, state) => const AgentItineraryPage(),
      ),
      GoRoute(
        path: '/boutiques',
        name: AppRoute.boutiques.name,
        builder: (context, state) => const BoutiqueListPage(),
        routes: [
          GoRoute(
            path: 'carte',
            name: AppRoute.boutiqueMap.name,
            builder: (context, state) => const BoutiqueMapPage(),
          ),
          GoRoute(
            path: 'nouvelle',
            name: AppRoute.boutiqueNew.name,
            pageBuilder: (context, state) =>
                _buildDialogPage(context, state, const BoutiqueFormPage()),
          ),
          GoRoute(
            path: ':id',
            name: AppRoute.boutiqueDetail.name,
            builder: (context, state) {
              final boutiqueId = state.pathParameters['id']!;
              return BoutiqueDetailPage(boutiqueId: boutiqueId);
            },
            routes: [
              GoRoute(
                path: 'edition',
                name: AppRoute.boutiqueEdit.name,
                pageBuilder: (context, state) {
                  final boutiqueId = state.pathParameters['id']!;
                  return _buildDialogPage(
                    context,
                    state,
                    BoutiqueFormPage(boutiqueId: boutiqueId),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isLoading = authState.isLoading;
      final isAuthRoute = state.matchedLocation == '/auth';
      final isItineraryRoute = state.matchedLocation == '/itineraire';

      if (isLoading) return null;

      if (!isAuthenticated && !isAuthRoute) {
        return '/auth';
      }

      if (isAuthenticated && isAuthRoute) {
        return '/boutiques';
      }

      if (!isAuthenticated && isItineraryRoute) {
        return '/auth';
      }

      if (isAuthenticated && state.matchedLocation == '/') {
        return '/boutiques';
      }

      return null;
    },
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authControllerProvider.notifier).stream,
    ),
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

CustomTransitionPage<void> _buildDialogPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      );
    },
  );
}
