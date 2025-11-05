import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../routing/app_route.dart';
import '../application/agent_itinerary_controller.dart';
import '../application/agent_itinerary_state.dart';
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
    extends ConsumerState<AgentItineraryPage> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
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
              Expanded(child: _TrackTable(points: state.points)),
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

class _TrackTable extends StatelessWidget {
  const _TrackTable({required this.points});

  final List<CollectorTrackPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Container(
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: const [
                _HeaderCell('Quartier', flex: 4),
                _HeaderCell('Latitude', flex: 3),
                _HeaderCell('Longitude', flex: 3),
                _HeaderCell('Heure', flex: 2),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: points.isEmpty
                ? const _EmptyTableMessage()
                : ListView.separated(
                    itemCount: points.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final point = points[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            _ValueCell(point.quartier, flex: 4),
                            _ValueCell(
                              point.latitude.toStringAsFixed(5),
                              flex: 3,
                            ),
                            _ValueCell(
                              point.longitude.toStringAsFixed(5),
                              flex: 3,
                            ),
                            _ValueCell(
                              _formatHour(point.timestamp),
                              flex: 2,
                              align: TextAlign.right,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatHour(DateTime dateTime) {
    final hours = dateTime.hour.toString().padLeft(2, '0');
    final minutes = dateTime.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {this.flex = 1});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        );
    return Expanded(
      flex: flex,
      child: Text(label, style: style),
    );
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell(
    this.value, {
    this.flex = 1,
    this.align = TextAlign.left,
  });

  final String value;
  final int flex;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Expanded(
      flex: flex,
      child: Text(
        value,
        textAlign: align,
        style: style,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _EmptyTableMessage extends StatelessWidget {
  const _EmptyTableMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Aucune donnee a afficher pour cette date.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
