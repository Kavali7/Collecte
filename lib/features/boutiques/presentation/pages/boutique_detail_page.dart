import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../routing/app_route.dart';
import '../../application/boutique_controller.dart';
import '../../domain/boutique.dart';
import '../utils/submission_date_formatter.dart';
import '../widgets/info_row.dart';

class BoutiqueDetailPage extends ConsumerWidget {
  const BoutiqueDetailPage({super.key, required this.boutiqueId});

  final String boutiqueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(boutiqueListControllerProvider);
    final boutique = _findBoutiqueById(state.boutiques, boutiqueId);

    if (boutique == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Boutique introuvable')),
      );
    }

    final materialLocalizations = MaterialLocalizations.of(context);
    final visitDateLabel = boutique.dateDeVisite == null
        ? 'Non renseignee'
        : materialLocalizations.formatFullDate(boutique.dateDeVisite!);
    final submissionLabel = buildSubmissionLabel(boutique.submittedAt);

    return Scaffold(
      appBar: AppBar(
        title: Text(boutique.nom),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            onPressed: () => context.pushNamed(
              AppRoute.boutiqueEdit.name,
              pathParameters: {'id': boutique.id},
            ),
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailGallery(photoPaths: boutique.photoPaths),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              boutique.nom,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Chip(
                              label: Text(
                                _syncStatusLabel(boutique.syncStatus),
                              ),
                              backgroundColor: _syncStatusColor(
                                boutique.syncStatus,
                              ).withValues(alpha: 0.12),
                              labelStyle: TextStyle(
                                color: _syncStatusColor(boutique.syncStatus),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.badge_outlined, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Specialite : ${boutique.specialiteLabel}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.grey[700]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.schedule, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  submissionLabel,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey[700]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Informations du gerant',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          InfoRow(
                            icon: Icons.person_outline,
                            label: 'Nom complet',
                            value: boutique.nomGerantComplet,
                          ),
                          const SizedBox(height: 12),
                          _TelephoneDetailsList(telephones: boutique.telephones),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Localisation',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          InfoRow(
                            icon: Icons.location_on_outlined,
                            label: 'Coordonnees GPS',
                            value: boutique.coordonneesLabel,
                          ),
                          InfoRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Date de visite',
                            value: visitDateLabel,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailGallery extends StatefulWidget {
  const _DetailGallery({required this.photoPaths});

  final List<String> photoPaths;

  @override
  State<_DetailGallery> createState() => _DetailGalleryState();
}

class _DetailGalleryState extends State<_DetailGallery> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photoPaths.isEmpty) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          color: const Color(0xFFE5E7EB),
          child: const Center(
            child: Icon(
              Icons.photo_camera_outlined,
              size: 72,
              color: Color(0xFF1D4ED8),
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photoPaths.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return _buildDetailImage(widget.photoPaths[index]);
            },
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_currentIndex + 1}/${widget.photoPaths.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelephoneDetailsList extends StatelessWidget {
  const _TelephoneDetailsList({required this.telephones});

  final List<String> telephones;

  @override
  Widget build(BuildContext context) {
    if (telephones.isEmpty) {
      return InfoRow(
        icon: Icons.phone,
        label: 'Telephones',
        value: 'Telephone non renseigne',
      );
    }

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.phone, color: Color(0xFF1D4ED8)),
            const SizedBox(width: 8),
            Text(
              'Telephones',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final phone in telephones)
          Padding(
            padding: const EdgeInsets.only(left: 28, bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 6, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    phone,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Boutique? _findBoutiqueById(List<Boutique> items, String id) {
  for (final boutique in items) {
    if (boutique.id == id) return boutique;
  }
  return null;
}

String _syncStatusLabel(SyncStatus status) {
  switch (status) {
    case SyncStatus.synced:
      return 'Synchronisee';
    case SyncStatus.pending:
      return 'A synchroniser';
    case SyncStatus.error:
      return 'Erreur de synchro';
  }
}

Widget _buildDetailImage(String path) {
  if (_isRemotePhoto(path)) {
    return Image.network(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: const Color(0xFFE5E7EB),
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_outlined,
          size: 56,
          color: Color(0xFF1D4ED8),
        ),
      ),
    );
  }
  return Image.file(File(path), fit: BoxFit.cover);
}

bool _isRemotePhoto(String path) {
  final normalized = path.toLowerCase();
  return normalized.startsWith('http://') || normalized.startsWith('https://');
}

Color _syncStatusColor(SyncStatus status) {
  switch (status) {
    case SyncStatus.synced:
      return const Color(0xFF2E7D32);
    case SyncStatus.pending:
      return const Color(0xFFF57F17);
    case SyncStatus.error:
      return const Color(0xFFC62828);
  }
}
