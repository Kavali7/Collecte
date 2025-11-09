import 'dart:math' as math;

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
import 'widgets/itinerary_journal_table.dart';

const _tileStoreName = 'collecteCache';
final FMTCStore _tileStore = FMTCStore(_tileStoreName);
const _defaultCenter = LatLng(5.3476, -4.0264);

class AgentItineraryPage extends ConsumerStatefulWidget {
  const AgentItineraryPage({super.key});

  @override
  ConsumerState<AgentItineraryPage> createState() => _AgentItineraryPageState();
}

class _AgentItineraryPageState extends ConsumerState<AgentItineraryPage>
    with RouteAware {
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
        backgroundColor: isWarning ? colorScheme.error : colorScheme.primary,
      ),
    );
  }

  void _fitBounds(LatLngBounds bounds) {
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(32)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agentItineraryControllerProvider);
    final controller = ref.read(agentItineraryControllerProvider.notifier);
    ref.listen<AgentItineraryState>(agentItineraryControllerProvider, (
      previous,
      next,
    ) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        _showSnack(next.errorMessage!, isWarning: true);
      }
      if (next.locationErrorMessage != null &&
          next.locationErrorMessage != previous?.locationErrorMessage) {
        _showSnack(next.locationErrorMessage!, isWarning: false);
      }
      final hasNewBounds =
          next.bounds != null &&
          next.bounds != previous?.bounds &&
          next.geoPoints.isNotEmpty;
      if (hasNewBounds && next.bounds != null) {
        _fitBounds(next.bounds!);
      }
    });

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final mapHeight = math.max(320.0, screenHeight * 0.6);
    final tableHeight = math.max(280.0, screenHeight * 0.25);
    final now = DateTime.now();
    final journalEntries = buildItineraryJournalEntries(
      state.points,
      currentTime: now,
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
            onPressed: () => context.pushNamed(AppRoute.boutiqueMap.name),
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
              ItineraryMapSection(
                state: state,
                mapController: _mapController,
                height: mapHeight,
                entries: journalEntries,
              ),
              if (state.locationErrorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _InfoBanner(message: state.locationErrorMessage!),
                ),
              const SizedBox(height: 16),
              ItineraryJournalTable(
                entries: journalEntries,
                height: tableHeight,
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
    final formattedDate = MaterialLocalizations.of(
      context,
    ).formatMediumDate(selectedDate);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Date analyse',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: Colors.grey[700]),
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

class ItineraryMapSection extends StatelessWidget {
  const ItineraryMapSection({
    super.key,
    required this.state,
    required this.mapController,
    required this.height,
    required this.entries,
  });

  final AgentItineraryState state;
  final MapController mapController;
  final double height;
  final List<ItineraryJournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final mapStops = entries
        .asMap()
        .entries
        .where(
          (entry) =>
              entry.value.point.latitude.isFinite &&
              entry.value.point.longitude.isFinite,
        )
        .map((entry) => _MapStop(order: entry.key + 1, entry: entry.value))
        .toList();
    final latLngPoints = mapStops
        .map((stop) => stop.latLng)
        .toList(growable: false);
    const markerSize = 60.0;

    return SizedBox(
      height: height,
      child: Card(
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: latLngPoints.isNotEmpty
                    ? latLngPoints.first
                    : _defaultCenter,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                if (mapStops.isNotEmpty)
                  MarkerLayer(
                    markers: mapStops
                        .map(
                          (stop) => Marker(
                            point: stop.latLng,
                            width: markerSize,
                            height: markerSize,
                            child: _NumberedStopMarker(order: stop.order),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
            if (state.isLoading)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            if (!state.isLoading && entries.isEmpty)
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
}

class _MapStop {
  const _MapStop({required this.order, required this.entry});

  final int order;
  final ItineraryJournalEntry entry;

  LatLng get latLng => LatLng(entry.point.latitude, entry.point.longitude);
}

class _NumberedStopMarker extends StatelessWidget {
  const _NumberedStopMarker({required this.order});

  final int order;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = order == 1 ? Colors.green.shade600 : colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$order',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
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
