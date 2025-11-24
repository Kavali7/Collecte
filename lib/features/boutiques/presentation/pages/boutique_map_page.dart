import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../application/boutique_map_controller.dart';
import '../../application/boutique_map_state.dart';
import '../../domain/boutique.dart';
import '../../../../routing/app_route.dart';

const _tileStoreName = 'collecteCache';
final FMTCStore _tileStore = FMTCStore(_tileStoreName);

class BoutiqueMapPage extends ConsumerStatefulWidget {
  const BoutiqueMapPage({super.key});

  @override
  ConsumerState<BoutiqueMapPage> createState() => _BoutiqueMapPageState();
}

class _BoutiqueMapPageState extends ConsumerState<BoutiqueMapPage> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    Future.microtask(
      () => ref.read(boutiqueMapControllerProvider.notifier).initialize(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(boutiqueMapControllerProvider);
    final controller = ref.read(boutiqueMapControllerProvider.notifier);

    final markers = _buildMarkers(state.boutiques);
    final hasBoutiqueMarkers = markers.isNotEmpty;
    final userLocation = state.userLocation;
    final userLatLng = userLocation != null
        ? LatLng(userLocation.latitude, userLocation.longitude)
        : null;
    final userMarker = _buildUserMarker(userLatLng);
    final allMarkers = [...markers, if (userMarker != null) userMarker];
    final shouldShowMap = allMarkers.isNotEmpty;
    final initialCenter = hasBoutiqueMarkers
        ? markers.first.point
        : (userLatLng ?? const LatLng(5.3476, -4.0264)); // Abidjan default

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            } else {
              context.goNamed(AppRoute.boutiques.name);
            }
          },
        ),
        title: const Text('Carte des collectes'),
        actions: [
          if (state.canChangeDateScope)
            _DateFilterMenu(
              state: state,
              onSelectToday: controller.setFilterToToday,
              onSelectAll: controller.setFilterToAllTime,
              onSelectDate: controller.setFilterToDate,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: _StatusChip(isOffline: state.isOffline),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!shouldShowMap && state.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (!shouldShowMap)
            _EmptyMapState(isOffline: state.isOffline)
          else
            FlutterMap(
              mapController: _mapController,
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
                MarkerLayer(markers: allMarkers),
              ],
            ),
          if (state.isLoading && hasBoutiqueMarkers)
            const Positioned(top: 24, right: 24, child: _LoadingBanner()),
          if (state.locationErrorMessage != null)
            Positioned(
              bottom: state.errorMessage != null ? 96 : 24,
              left: 16,
              right: 16,
              child: _LocationMessageBanner(
                message: state.locationErrorMessage!,
              ),
            ),
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
      floatingActionButton: _buildFloatingButtons(state, controller),
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

  Marker? _buildUserMarker(LatLng? latLng) {
    if (latLng == null) return null;
    return Marker(
      point: latLng,
      width: 48,
      height: 48,
      alignment: Alignment.center,
      child: Tooltip(
        message: 'Ta position actuelle',
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0x5960A5FA),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFloatingButtons(
    BoutiqueMapState state,
    BoutiqueMapController controller,
  ) {
    final buttons = <Widget>[];
    final hasUserLocation = state.userLocation != null;
    final isRequestingLocation = state.isLocatingUser && !hasUserLocation;

    buttons.add(
      FloatingActionButton.extended(
        heroTag: 'my-position',
        onPressed: isRequestingLocation
            ? null
            : () => _handleMyPositionPressed(state, controller),
        icon: isRequestingLocation
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location),
        label: const Text('Ma position'),
      ),
    );

    if (!state.isOffline) {
      buttons.add(const SizedBox(height: 12));
      buttons.add(
        FloatingActionButton.extended(
          heroTag: 'sync-boutiques',
          onPressed: state.isSyncing ? null : controller.sync,
          icon: state.isSyncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          label: Text(state.isSyncing ? 'Synchronisation...' : 'Synchroniser'),
        ),
      );
    }

    if (buttons.isEmpty) {
      return null;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: buttons,
    );
  }

  void _handleMyPositionPressed(
    BoutiqueMapState state,
    BoutiqueMapController controller,
  ) {
    final location = state.userLocation;
    if (location != null) {
      _mapController.move(LatLng(location.latitude, location.longitude), 16);
    } else {
      controller.refreshUserLocation();
    }
  }
}

enum _DateFilterAction { today, pickDate, allTime }

class _DateFilterMenu extends StatelessWidget {
  const _DateFilterMenu({
    required this.state,
    required this.onSelectToday,
    required this.onSelectAll,
    required this.onSelectDate,
  });

  final BoutiqueMapState state;
  final Future<void> Function() onSelectToday;
  final Future<void> Function() onSelectAll;
  final Future<void> Function(DateTime date) onSelectDate;

  @override
  Widget build(BuildContext context) {
    final label = _formatLabel(state);
    return PopupMenuButton<_DateFilterAction>(
      tooltip: 'Filtrer les collectes',
      onSelected: (action) async {
        switch (action) {
          case _DateFilterAction.today:
            await onSelectToday();
            break;
          case _DateFilterAction.pickDate:
            final initial = state.selectedDate ?? DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(2020, 1, 1),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              await onSelectDate(picked);
            }
            break;
          case _DateFilterAction.allTime:
            await onSelectAll();
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _DateFilterAction.today,
          child: Text("Aujourd'hui"),
        ),
        PopupMenuItem(
          value: _DateFilterAction.pickDate,
          child: Text('Choisir une date'),
        ),
        PopupMenuItem(
          value: _DateFilterAction.allTime,
          child: Text('Historique complet'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatLabel(BoutiqueMapState state) {
    if (state.isAllTime) return 'Historique';
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = DateUtils.dateOnly(
      state.selectedDate ?? DateTime.now(),
    );
    if (DateUtils.isSameDay(today, selected)) {
      return "Aujourd'hui";
    }
    final day = selected.day.toString().padLeft(2, '0');
    final month = selected.month.toString().padLeft(2, '0');
    return '$day/$month/${selected.year}';
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
              isOffline ? 'Mode hors ligne' : 'Connecte',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isOffline
                    ? colorScheme.onErrorContainer
                    : colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
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
            'Aucune coordonnee disponible',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            isOffline
                ? 'Connecte-toi pour recuperer les dernieres collectes.'
                : 'Ajoute des boutiques avec coordonnees GPS pour les visualiser ici.',
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
              'Carte en mode hors ligne (affichage des donnees en cache)',
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

class _LocationMessageBanner extends StatelessWidget {
  const _LocationMessageBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xFFE0F2FE),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.my_location, color: Color(0xFF1D4ED8)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF1E3A8A),
                ),
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
            Text('Mise a jour de la carte...'),
          ],
        ),
      ),
    );
  }
}
