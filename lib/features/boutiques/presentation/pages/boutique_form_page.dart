import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../../application/boutique_controller.dart';
import '../../domain/boutique.dart';

class BoutiqueFormPage extends ConsumerStatefulWidget {
  const BoutiqueFormPage({super.key, this.boutiqueId});

  final String? boutiqueId;

  @override
  ConsumerState<BoutiqueFormPage> createState() => _BoutiqueFormPageState();
}

class _BoutiqueFormPageState extends ConsumerState<BoutiqueFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _nomGerantController = TextEditingController();
  final _telephoneController = TextEditingController();

  String? _photoPath;
  DateTime? _dateDeVisite;
  double? _latitude;
  double? _longitude;
  bool _isExtractingLocation = false;
  String? _locationMessage;
  SyncStatus _syncStatus = SyncStatus.pending;

  bool _isTelephoneChecking = false;
  bool _isTelephoneValid = false;
  String? _telephoneFeedback;
  String? _lastValidatedTelephone;

  bool get _isEditing => widget.boutiqueId != null;
  bool get _hasValidatedTelephone {
    final current = _telephoneController.text.trim();
    return _isTelephoneValid &&
        _lastValidatedTelephone != null &&
        current == _lastValidatedTelephone;
  }

  @override
  void initState() {
    super.initState();
    _telephoneController.addListener(_handleTelephoneChanged);
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadExistingValues();
      });
    } else {
      _locationMessage =
          'La localisation sera determinee automatiquement via le GPS du telephone.';
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _nomGerantController.dispose();
    _telephoneController.removeListener(_handleTelephoneChanged);
    _telephoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(
      boutiqueListControllerProvider.select((state) => state.isLoading),
    );
    final materialLocalizations = MaterialLocalizations.of(context);
    final visitLabel = _dateDeVisite == null
        ? 'Capture une photo pour renseigner automatiquement la date.'
        : '${materialLocalizations.formatMediumDate(_dateDeVisite!)} '
              '${materialLocalizations.formatTimeOfDay(TimeOfDay.fromDateTime(_dateDeVisite!), alwaysUse24HourFormat: true)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier la boutique' : 'Nouvelle boutique'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CameraCaptureSection(
                  photoPath: _photoPath,
                  onCapture: _isEditing ? null : _capturePhoto,
                  onRemove: _isEditing || _photoPath == null
                      ? null
                      : () {
                          setState(() {
                            _photoPath = null;
                            _latitude = null;
                            _longitude = null;
                            _dateDeVisite = null;
                            _locationMessage =
                                'La localisation sera determinee automatiquement via le GPS du telephone.';
                          });
                        },
                  isEnabled: !_isEditing,
                ),
                const SizedBox(height: 16),
                _LocationPreview(
                  latitude: _latitude,
                  longitude: _longitude,
                  isLoading: _isExtractingLocation,
                  message: _locationMessage,
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 16),
                  const _LockedFieldsBanner(),
                ],
                const SizedBox(height: 24),
                Text(
                  'Informations boutique',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la boutique',
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Indique le nom' : null,
                ),
                const SizedBox(height: 20),
                Text(
                  'Informations gerant',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nomGerantController,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet du gerant',
                  ),
                  enabled: !_isEditing,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Indique le nom complet'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telephoneController,
                  decoration: InputDecoration(
                    labelText: 'Telephone',
                    prefixIcon: const Icon(Icons.phone),
                    suffixIcon: _buildTelephoneSuffix(context),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                if (_telephoneFeedback != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _telephoneFeedback!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _isTelephoneValid
                            ? const Color(0xFF16A34A)
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Visite',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blueGrey.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, color: Color(0xFF1D4ED8)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date de visite',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                    letterSpacing: 0.2,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              visitLabel,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  key: const Key('boutique-form-submit-button'),
                  onPressed:
                      isSaving ||
                          !_hasValidatedTelephone ||
                          _isTelephoneChecking
                      ? null
                      : _submit,
                  icon: const Icon(Icons.save),
                  label: Text(_isEditing ? 'Mettre a jour' : 'Enregistrer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildTelephoneSuffix(BuildContext context) {
    if (_isTelephoneChecking) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_hasValidatedTelephone) {
      return const Icon(Icons.check_circle, color: Color(0xFF16A34A));
    }

    final theme = Theme.of(context);
    final hasErrorFeedback = !_isTelephoneValid && _telephoneFeedback != null;
    final iconData = hasErrorFeedback
        ? Icons.error_outline
        : Icons.check_circle_outline;
    final iconColor = hasErrorFeedback
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return IconButton(
      onPressed: _validateTelephone,
      icon: Icon(iconData, color: iconColor),
      tooltip: 'Verifier le numero',
    );
  }

  void _handleTelephoneChanged() {
    final current = _telephoneController.text.trim();
    final alreadyValidated =
        _lastValidatedTelephone != null && current == _lastValidatedTelephone;

    if (alreadyValidated) {
      if (!_isTelephoneValid) {
        setState(() {
          _isTelephoneValid = true;
        });
      }
      return;
    }

    if (_isTelephoneValid ||
        _telephoneFeedback != null ||
        _lastValidatedTelephone != null) {
      setState(() {
        _isTelephoneValid = false;
        _telephoneFeedback = null;
        _lastValidatedTelephone = null;
      });
    }
  }

  Future<void> _validateTelephone() async {
    if (_isTelephoneChecking) return;

    final telephone = _telephoneController.text.trim();
    if (telephone.isEmpty) {
      setState(() {
        _isTelephoneValid = false;
        _telephoneFeedback =
            'Renseigne un numero avant de lancer la verification.';
        _lastValidatedTelephone = null;
      });
      return;
    }

    setState(() {
      _isTelephoneChecking = true;
      _telephoneFeedback = null;
    });

    try {
      final controller = ref.read(boutiqueListControllerProvider.notifier);
      final available = await controller.isTelephoneAvailable(
        telephone,
        excludeId: widget.boutiqueId,
      );
      if (!mounted) return;
      setState(() {
        _isTelephoneChecking = false;
        _isTelephoneValid = available;
        _lastValidatedTelephone = telephone;
        _telephoneFeedback = available
            ? 'Numero valide. Tu peux continuer.'
            : 'Ce numero est deja enregistre. Tu ne peux pas reutiliser un numero existant.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isTelephoneChecking = false;
        _isTelephoneValid = false;
        _lastValidatedTelephone = null;
        _telephoneFeedback =
            'Verification impossible pour le moment. Reessaie dans un instant.';
      });
    }
  }

  Future<void> _capturePhoto() async {
    if (_isEditing) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1280,
      maxHeight: 720,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() {
      _photoPath = image.path;
      _locationMessage = 'Recuperation de la localisation du telephone...';
      _latitude = null;
      _longitude = null;
      _dateDeVisite = DateTime.now();
    });

    await _fetchDeviceLocation();
  }

  Future<void> _fetchDeviceLocation() async {
    setState(() {
      _isExtractingLocation = true;
      _locationMessage = 'Recuperation de la localisation du telephone...';
    });

    double? latitude;
    double? longitude;
    String? message;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        message =
            'Le service de localisation est desactive. Active le GPS du telephone puis reessaye.';
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          message =
              'Autorisation localisation indisponible. Active-la dans les reglages et reessaie.';
        } else {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          latitude = position.latitude;
          longitude = position.longitude;
          message = 'Coordonnees recuperees via le GPS du telephone.';
        }
      }
    } catch (error) {
      message = 'Erreur lors de la recuperation de la localisation: $error';
    }

    if (!mounted) return;

    setState(() {
      _isExtractingLocation = false;
      _latitude = latitude;
      _longitude = longitude;
      _locationMessage = message;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_hasValidatedTelephone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Valide le numero de telephone avant de continuer.'),
        ),
      );
      return;
    }

    if (!_isEditing) {
      if (_photoPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ajoute une photo pour enregistrer la boutique.'),
          ),
        );
        return;
      }

      if (_latitude == null || _longitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Coordonnees GPS manquantes. Active la localisation, reprends la photo et recommence.',
            ),
          ),
        );
        return;
      }
    }

    final controller = ref.read(boutiqueListControllerProvider.notifier);
    final visitDate = _dateDeVisite ?? DateTime.now();

    final boutique = Boutique(
      id: widget.boutiqueId ?? '',
      nom: _nomController.text.trim(),
      nomGerantComplet: _nomGerantController.text.trim(),
      telephone: _telephoneController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      photoPath: _photoPath,
      dateDeVisite: visitDate,
      syncStatus: _syncStatus,
    );

    await controller.createOrUpdate(boutique);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _loadExistingValues() {
    final boutique = ref
        .read(boutiqueListControllerProvider)
        .boutiques
        .where((item) => item.id == widget.boutiqueId)
        .cast<Boutique?>()
        .firstWhere((item) => item != null, orElse: () => null);
    if (boutique == null) {
      setState(() {
        _locationMessage =
            'La localisation sera determinee automatiquement via le GPS du telephone.';
      });
      return;
    }

    final telephone = boutique.telephone.trim();
    setState(() {
      _nomController.text = boutique.nom;
      _nomGerantController.text = boutique.nomGerantComplet;
      _telephoneController.text = telephone;
      _lastValidatedTelephone = telephone.isEmpty ? null : telephone;
      _isTelephoneValid = _lastValidatedTelephone != null;
      _telephoneFeedback = null;
      _isTelephoneChecking = false;
      _photoPath = boutique.photoPath;
      _dateDeVisite = boutique.dateDeVisite;
      _syncStatus = boutique.syncStatus;
      _latitude = boutique.latitude;
      _longitude = boutique.longitude;
      _locationMessage = boutique.latitude != null && boutique.longitude != null
          ? 'Coordonnees deja renseignees pour cette boutique.'
          : 'Prends une photo pour recuperer la localisation via le GPS du telephone.';
    });
  }
}

class _LockedFieldsBanner extends StatelessWidget {
  const _LockedFieldsBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF4F46E5)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Seuls le nom et le numero de telephone peuvent etre modifies pour cette boutique.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraCaptureSection extends StatelessWidget {
  const _CameraCaptureSection({
    required this.photoPath,
    this.onCapture,
    this.onRemove,
    this.isEnabled = true,
  });

  final VoidCallback? onCapture;
  final String? photoPath;
  final VoidCallback? onRemove;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: GestureDetector(
            onTap: isEnabled ? onCapture : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFFE5E7EB),
                  ),
                  child: photoPath == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.photo_camera_outlined,
                              size: 48,
                              color: Color(0xFF1D4ED8),
                            ),
                            SizedBox(height: 12),
                            Text('Prendre une photo'),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _buildPhotoPreview(photoPath!),
                        ),
                ),
                if (!isEnabled)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                      child: const Center(
                        child: Icon(Icons.lock_outline, color: Colors.white70),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (isEnabled && photoPath != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Retirer la photo'),
            ),
          ),
        ],
      ],
    );
  }
}

class _LocationPreview extends StatelessWidget {
  const _LocationPreview({
    required this.latitude,
    required this.longitude,
    required this.isLoading,
    required this.message,
  });

  final double? latitude;
  final double? longitude;
  final bool isLoading;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLocation = latitude != null && longitude != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: Color(0xFF1D4ED8)),
              const SizedBox(width: 8),
              Text(
                'Localisation',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Extraction en cours...'),
              ],
            )
          else if (hasLocation)
            Text(
              'Lat: ${latitude!.toStringAsFixed(5)} / Lng: ${longitude!.toStringAsFixed(5)}',
              style: theme.textTheme.bodyMedium,
            )
          else
            Text(
              message ??
                  'Coordonnees GPS absentes. Assure-toi que la localisation du telephone est active puis prends une photo.',
              style: theme.textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }
}

Widget _buildPhotoPreview(String path) {
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
