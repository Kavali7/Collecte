import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../routing/app_route.dart';
import '../../../routing/app_router.dart';
import '../application/agent_itinerary_controller.dart';
import '../application/agent_itinerary_state.dart';
import '../application/collector_track_recorder.dart';
import '../domain/collector_track_point.dart';

const _tileStoreName = 'collecteCache';
final FMTCStore _tileStore = FMTCStore(_tileStoreName);
const _defaultCenter = LatLng(5.3476, -4.0264);

class AgentItineraryPage extends ConsumerStatefulWidget {
  const AgentItineraryPage({super.key});

  @override
  ConsumerState<AgentItineraryPage> createState() =>
      _AgentItineraryPageState();
}

class _AgentItineraryPageState
    extends ConsumerState<AgentItineraryPage> with RouteAware {
  late final MapController _mapController;
  RouteObserver<ModalRoute<void>>? _routeObserver;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final observer = ref.read(routeObserverProvider);
    final route = ModalRoute.of(context);
    if (route is PageRoute && _routeObserver != observer) {
      _routeObserver?.unsubscribe(this);
      _routeObserver = observer;
      observer.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _routeObserver?.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    _triggerSync();
  }

  @override
  void didPopNext() {
    _triggerSync();
  }

  void _triggerSync() {
    ref.read(collectorTrackRecorderProvider.notifier).syncNow();
  }

  void _showSnack(String message, {required bool isWarning}) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isWarning ? colorScheme.error : colorScheme.primary,
      ),
    );
  }

  void _fitBounds(LatLngBounds bounds) {
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agentItineraryControllerProvider);
    final controller = ref.read(agentItineraryControllerProvider.notifier);
    final recorderState = ref.watch(collectorTrackRecorderProvider);
    ref.listen<AgentItineraryState>(
      agentItineraryControllerProvider,
      (previous, next) {
        if (next.errorMessage != null &&
            next.errorMessage != previous?.errorMessage) {
          _showSnack(next.errorMessage!, isWarning: true);
        }
        if (next.locationErrorMessage != null &&
            next.locationErrorMessage != previous?.locationErrorMessage) {
          _showSnack(next.locationErrorMessage!, isWarning: false);
        }
        final hasNewBounds = next.bounds != null &&
            next.bounds != previous?.bounds &&
            next.geoPoints.isNotEmpty;
        if (hasNewBounds && next.bounds != null) {
          _fitBounds(next.bounds!);
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        title: const Text('Itineraire du collecteur'),
        actions: [
          IconButton(
            tooltip: 'Carte des boutiques',
            icon: const Icon(Icons.map_outlined),
            onPressed: () =>
                context.pushNamed(AppRoute.boutiqueMap.name),
          ),
          IconButton(
            tooltip: 'Liste des boutiques',
            icon: const Icon(Icons.store_mall_directory_outlined),
            onPressed: () => context.pushNamed(AppRoute.boutiques.name),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ItineraryControls(
                selectedDate: state.selectedDate,
                isLoading: state.isLoading,
                onSelectDate: (picked) => controller.changeDate(picked),
              ),
              const SizedBox(height: 16),
              _MapSection(
                state: state,
                mapController: _mapController,
              ),
              if (state.locationErrorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _InfoBanner(message: state.locationErrorMessage!),
                ),
              const SizedBox(height: 16),
              _TrackSummaryCard(
                pointsCount: state.points.length,
                pendingCount: recorderState.pendingPoints,
                hasPendingSync: recorderState.hasPendingSync,
                hasError: recorderState.hasError || state.errorMessage != null,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItineraryControls extends StatelessWidget {
  const _ItineraryControls({
    required this.selectedDate,
    required this.isLoading,
    required this.onSelectDate,
  });

  final DateTime selectedDate;
  final bool isLoading;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        MaterialLocalizations.of(context).formatMediumDate(selectedDate);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Date analyse',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: isLoading ? null : () => _pickDate(context),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(formattedDate),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        if (isLoading) const CircularProgressIndicator(),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final initial = selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked != null && picked != selectedDate) {
      onSelectDate(picked);
    }
  }
}

class _MapSection extends StatelessWidget {
  const _MapSection({
    required this.state,
    required this.mapController,
  });

  final AgentItineraryState state;
  final MapController mapController;

  @override
  Widget build(BuildContext context) {
    final points = state.geoPoints;
    final latLngPoints = points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
    final markers = _buildMarkers(points);

    return SizedBox(
      height: 280,
      child: Card(
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: points.isNotEmpty
                    ? latLngPoints.first
                    : _defaultCenter,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.collecte.revendeurs',
                  tileProvider: _tileStore.getTileProvider(),
                ),
                if (latLngPoints.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        strokeWidth: 4,
                        color: const Color(0xFF2563EB),
                        points: latLngPoints,
                      ),
                    ],
                  ),
                if (markers.isNotEmpty) MarkerLayer(markers: markers),
              ],
            ),
            if (state.isLoading)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            if (!state.isLoading && points.isEmpty)
              const Positioned.fill(
                child: _EmptyMapMessage(
                  message:
                      'Aucune donnee d\'itineraire pour cette date.\nVerifie la synchronisation.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Marker> _buildMarkers(List<CollectorTrackPoint> points) {
    if (points.isEmpty) return const <Marker>[];
    const markerSize = 72.0;
    final markers = <Marker>[];
    final start = points.first;
    final end = points.last;
    markers.add(
      Marker(
        point: LatLng(start.latitude, start.longitude),
        width: markerSize,
        height: markerSize,
        child: _MarkerBadge(
          label: 'Depart',
          icon: Icons.flag,
          color: Colors.green.shade600,
        ),
      ),
    );
    if (end.id != start.id) {
      markers.add(
        Marker(
          point: LatLng(end.latitude, end.longitude),
          width: markerSize,
          height: markerSize,
          child: _MarkerBadge(
            label: 'Arrivee',
            icon: Icons.location_on,
            color: Colors.red.shade600,
          ),
        ),
      );
    }
    return markers;
  }
}

class _MarkerBadge extends StatelessWidget {
  const _MarkerBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _EmptyMapMessage extends StatelessWidget {
  const _EmptyMapMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white70),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xFFE0F2FE),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF0369A1)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackSummaryCard extends StatelessWidget {
  const _TrackSummaryCard({
    required this.pointsCount,
    required this.pendingCount,
    required this.hasPendingSync,
    required this.hasError,
  });

  final int pointsCount;
  final int pendingCount;
  final bool hasPendingSync;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messages = <_SummaryMessage>[];
    if (pointsCount == 0) {
      messages.add(
        _SummaryMessage(
          label: 'Aucun trajet',
          color: const Color(0xFF6B7280),
          icon: Icons.route,
        ),
      );
    }
    if (hasPendingSync) {
      final label = pendingCount > 0
          ? 'Synchronisation en attente ($pendingCount)'
          : 'Synchronisation en attente';
      messages.add(
        _SummaryMessage(
          label: label,
          color: const Color(0xFFF97316),
          icon: Icons.sync_problem,
        ),
      );
    }
    if (hasError) {
      messages.add(
        _SummaryMessage(
          label: 'Erreur reseau/permissions',
          color: theme.colorScheme.error,
          icon: Icons.warning_amber_rounded,
        ),
      );
    }

    final summaryLabel = '$pointsCount arrets enregistres';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summaryLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (messages.isEmpty)
              Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Trajet synchronise.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: messages
                    .map(
                      (message) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(message.icon, color: message.color, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                message.label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: message.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMessage {
  const _SummaryMessage({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}
