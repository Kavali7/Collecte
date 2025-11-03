import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../application/boutique_map_controller.dart';
import '../../domain/boutique.dart';

const _tileStoreName = 'collecteCache';
final FMTCStore _tileStore = FMTCStore(_tileStoreName);

class BoutiqueMapPage extends ConsumerStatefulWidget {
  const BoutiqueMapPage({super.key});

  @override
  ConsumerState<BoutiqueMapPage> createState() => _BoutiqueMapPageState();
}

class _BoutiqueMapPageState extends ConsumerState<BoutiqueMapPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(boutiqueMapControllerProvider.notifier).initialize(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(boutiqueMapControllerProvider);
    final controller = ref.read(boutiqueMapControllerProvider.notifier);

    final markers = _buildMarkers(state.boutiques);
    final hasMarkers = markers.isNotEmpty;
    final initialCenter = hasMarkers
        ? markers.first.point
        : const LatLng(5.3476, -4.0264); // Abidjan default

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte des collectes'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: _StatusChip(isOffline: state.isOffline),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!hasMarkers && state.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (!hasMarkers)
            _EmptyMapState(isOffline: state.isOffline)
          else
            FlutterMap(
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 12,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.collecte.revendeurs',
                  tileProvider: _tileStore.getTileProvider(),
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          if (state.isLoading && hasMarkers)
            const Positioned(top: 24, right: 24, child: _LoadingBanner()),
          if (state.errorMessage != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: _ErrorBanner(message: state.errorMessage!),
            ),
          if (state.isOffline)
            const Positioned(
              top: 24,
              left: 16,
              right: 16,
              child: _OfflineBanner(),
            ),
        ],
      ),
      floatingActionButton: state.isOffline
          ? null
          : FloatingActionButton.extended(
              onPressed: state.isSyncing ? null : controller.sync,
              icon: state.isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(
                state.isSyncing ? 'Synchronisation...' : 'Synchroniser',
              ),
            ),
    );
  }

  List<Marker> _buildMarkers(List<Boutique> boutiques) {
    return boutiques
        .where(
          (boutique) => boutique.latitude != null && boutique.longitude != null,
        )
        .map(
          (boutique) => Marker(
            point: LatLng(boutique.latitude!, boutique.longitude!),
            width: 44,
            height: 44,
            child: Tooltip(
              message: '${boutique.nom}\n${boutique.coordonneesLabel}',
              child: Icon(
                boutique.syncStatus == SyncStatus.synced
                    ? Icons.location_on
                    : Icons.location_searching_outlined,
                color: boutique.syncStatus == SyncStatus.synced
                    ? const Color(0xFFE11D48)
                    : const Color(0xFF1D4ED8),
                size: 32,
              ),
            ),
          ),
        )
        .toList(growable: false);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isOffline});

  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isOffline
            ? colorScheme.errorContainer
            : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOffline ? Icons.cloud_off : Icons.cloud_done,
              size: 18,
              color: isOffline
                  ? colorScheme.onErrorContainer
                  : colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 6),
            Text(
              isOffline ? 'Mode hors ligne' : 'Connecté',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isOffline
                    ? colorScheme.onErrorContainer
                    : colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMapState extends StatelessWidget {
  const _EmptyMapState({required this.isOffline});

  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.public, size: 56, color: Color(0xFF1D4ED8)),
          const SizedBox(height: 12),
          Text(
            'Aucune coordonnée disponible',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            isOffline
                ? 'Connecte-toi pour récupérer les dernières collectes.'
                : 'Ajoute des boutiques avec coordonnées GPS pour les visualiser ici.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xFFFDE68A),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: Color(0xFF92400E)),
            const SizedBox(width: 8),
            Text(
              'Carte en mode hors ligne (affichage des données en cache)',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF92400E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingBanner extends StatelessWidget {
  const _LoadingBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Mise à jour de la carte...'),
          ],
        ),
      ),
    );
  }
}
