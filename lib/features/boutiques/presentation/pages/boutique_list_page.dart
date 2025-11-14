import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../routing/app_route.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../../../auth/domain/auth_state.dart';
import '../../application/boutique_controller.dart';
import '../widgets/boutique_card.dart';
import '../widgets/boutique_dashboard.dart';

class BoutiqueListPage extends ConsumerWidget {
  const BoutiqueListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(boutiqueListControllerProvider);
    final controller = ref.read(boutiqueListControllerProvider.notifier);

    final isOffline = state.isOffline;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mes boutiques'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list_alt_outlined), text: 'Liste'),
              Tab(icon: Icon(Icons.insights_outlined), text: 'Tableau de bord'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Itineraire du collecteur',
              onPressed: () => context.pushNamed(AppRoute.agentItinerary.name),
              icon: const Icon(Icons.route_outlined),
            ),
            IconButton(
              tooltip: 'Voir la carte',
              onPressed: () => context.pushNamed(AppRoute.boutiqueMap.name),
              icon: const Icon(Icons.map_outlined),
            ),
            IconButton(
              tooltip: 'Se deconnecter',
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: isOffline
              ? null
              : () => context.pushNamed(AppRoute.boutiqueNew.name),
          label: const Text('Nouvelle boutique'),
          icon: const Icon(Icons.add),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: controller.initialize,
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (isOffline)
                    const _OfflineNotice(),
                  if (isOffline) const SizedBox(height: 12),
                  _WelcomeHeader(authState: ref.watch(authControllerProvider)),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: controller.search,
                    decoration: const InputDecoration(
                      labelText: 'Rechercher une boutique ou un gerant',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (state.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.filteredBoutiques.isEmpty)
                    _EmptyState(
                      onCreate: isOffline
                          ? null
                          : () => context.pushNamed(
                                AppRoute.boutiqueNew.name,
                              ),
                    )
                  else
                    ...state.filteredBoutiques.map(
                      (boutique) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: BoutiqueCard(
                          boutique: boutique,
                          onTap: () => context.pushNamed(
                            AppRoute.boutiqueDetail.name,
                            pathParameters: {'id': boutique.id},
                          ),
                          onEdit: () => context.pushNamed(
                            AppRoute.boutiqueEdit.name,
                            pathParameters: {'id': boutique.id},
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            BoutiqueDashboard(
              state: state,
              onRefresh: controller.initialize,
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.authState});

  final AuthState authState;

  @override
  Widget build(BuildContext context) {
    final name = authState.displayName ?? 'collecteur';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bonjour $name,',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Voici les boutiques recensees. Continue a enrichir ta base pour preparer la synchronisation.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.storefront, size: 48, color: Color(0xFF1D4ED8)),
          const SizedBox(height: 12),
          Text(
            'Aucune boutique enregistree',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoute ta premiere boutique pour commencer la collecte des donnees terrain.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une boutique'),
          ),
        ],
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_off, color: Color(0xFFFB8C00)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode hors connexion',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFBF360C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'La creation de nouvelles boutiques est temporairement desactivee. '
                  'Reconnecte-toi pour poursuivre la collecte.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFBF360C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
