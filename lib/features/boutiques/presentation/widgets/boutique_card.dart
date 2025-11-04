import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/boutique.dart';
import '../utils/submission_date_formatter.dart';

class BoutiqueCard extends StatelessWidget {
  const BoutiqueCard({
    super.key,
    required this.boutique,
    this.onTap,
    this.onEdit,
  });

  final Boutique boutique;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayedPhones = boutique.telephones.take(2).toList();
    final extraPhones = boutique.telephones.length - displayedPhones.length;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumbnail(photoPaths: boutique.photoPaths),
                const SizedBox(width: 16),
                Expanded(
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
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Chip(
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    label: Text(boutique.specialiteLabel),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (onEdit != null)
                            IconButton(
                              tooltip: 'Modifier',
                              onPressed: onEdit,
                              icon: const Icon(Icons.edit_outlined),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        boutique.nomGerantComplet,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            buildSubmissionLabel(boutique.submittedAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (boutique.telephones.isEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.phone, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Telephone non renseigne',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < displayedPhones.length; i++)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: (i == displayedPhones.length - 1 &&
                                          extraPhones <= 0)
                                      ? 0
                                      : 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.phone, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      displayedPhones[i],
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            if (extraPhones > 0)
                              Padding(
                                padding: const EdgeInsets.only(left: 22),
                                child: Text(
                                  '+$extraPhones numeros supplementaires',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.place_outlined, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              boutique.adresse?.isNotEmpty == true
                                  ? boutique.adresse!
                                  : 'Adresse indisponible',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[700],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            boutique.coordonneesLabel,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _SyncBadge(status: boutique.syncStatus),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.photoPaths});

  final List<String> photoPaths;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        width: 76,
        height: 76,
        color: const Color(0xFFE5E7EB),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photoPaths.isEmpty)
              const Center(
                child: Icon(Icons.storefront, size: 32, color: Color(0xFF1D4ED8)),
              )
            else
              _buildThumbnailImage(photoPaths.first),
            if (photoPaths.length > 1)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+${photoPaths.length - 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;
    String label;

    switch (status) {
      case SyncStatus.synced:
        background = const Color(0xFFE8F5E9);
        foreground = const Color(0xFF2E7D32);
        label = 'Synchronisee';
        break;
      case SyncStatus.pending:
        background = const Color(0xFFFFF8E1);
        foreground = const Color(0xFFF57F17);
        label = 'A synchroniser';
        break;
      case SyncStatus.error:
        background = const Color(0xFFFFEBEE);
        foreground = const Color(0xFFC62828);
        label = 'Erreur';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Widget _buildThumbnailImage(String path) {
  if (_isRemotePhoto(path)) {
    return Image.network(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const ColoredBox(
        color: Color(0xFFE5E7EB),
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: Color(0xFF1D4ED8)),
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
