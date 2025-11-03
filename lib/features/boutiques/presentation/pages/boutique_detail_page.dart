import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../routing/app_route.dart';
import '../../application/boutique_controller.dart';
import '../../domain/boutique.dart';
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
            _DetailHeader(photoPath: boutique.photoPath),
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
                          InfoRow(
                            icon: Icons.phone,
                            label: 'Telephone',
                            value: boutique.telephone.isEmpty
                                ? 'Telephone non renseigne'
                                : boutique.telephone,
                          ),
                          InfoRow(
                            icon: Icons.place_outlined,
                            label: 'Adresse',
                            value: boutique.adresse,
                          ),
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

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({this.photoPath});

  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: photoPath == null
          ? Container(
              color: const Color(0xFFE5E7EB),
              child: const Center(
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: 72,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            )
          : _buildDetailImage(photoPath!),
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
