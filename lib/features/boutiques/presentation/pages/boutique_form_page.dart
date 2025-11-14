import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import 'package:collecte_revendeurs/core/location/locationiq_reverse_geocoding.dart';
import 'package:collecte_revendeurs/core/location/location_providers.dart';
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
  final List<_TelephoneFieldState> _telephoneFields = [];
  final _adresseController = TextEditingController();
  BoutiqueSpecialite? _selectedSpecialite;
  String? _collectorId;

  List<String> _photoPaths = [];
  DateTime? _dateDeVisite;
  DateTime? _submittedAt;
  double? _latitude;
  double? _longitude;
  bool _isExtractingLocation = false;
  String? _locationMessage;
  SyncStatus _syncStatus = SyncStatus.pending;
  bool _isResolvingAddress = false;
  String? _addressError;

  bool get _isEditing => widget.boutiqueId != null;
  bool get _hasValidatedTelephones =>
      _telephoneFields.isNotEmpty &&
      _telephoneFields.every(
        (field) => field.isValid && field.controller.text.trim().isNotEmpty,
      );
  bool get _isAnyTelephoneChecking =>
      _telephoneFields.any((field) => field.isChecking);

  @override
  void initState() {
    super.initState();
    _telephoneFields.add(_createTelephoneField(''));
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadExistingValues();
      });
    } else {
      _locationMessage =
          'La localisation sera determinee automatiquement via le GPS du telephone lors de la premiere photo.';
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _nomGerantController.dispose();
    _adresseController.dispose();
    for (final field in _telephoneFields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(
      boutiqueListControllerProvider.select((state) => state.isLoading),
    );
    final isOffline = ref.watch(
      boutiqueListControllerProvider.select((state) => state.isOffline),
    );
    final materialLocalizations = MaterialLocalizations.of(context);
    final visitLabel = _dateDeVisite == null
        ? 'Capture une premiere photo pour renseigner automatiquement la date.'
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
                if (isOffline) const _OfflineFormBanner(),
                if (isOffline) const SizedBox(height: 12),
                _PhotoPickerSection(
                  photoPaths: _photoPaths,
                  isEditable: !_isEditing && !isOffline,
                  onAddPhoto:
                      (_isEditing || isOffline) ? null : _capturePhoto,
                  onRemovePhoto: _isEditing ? null : _removePhotoAt,
                ),
                const SizedBox(height: 16),
                _LocationPreview(
                  latitude: _latitude,
                  longitude: _longitude,
                  isLoading: _isExtractingLocation,
                  message: _locationMessage,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _adresseController,
                  readOnly: true,
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Adresse detectee',
                    helperText:
                        'Basee sur la localisation au moment de la premiere photo.',
                    suffixIcon: _isResolvingAddress
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_adresseController.text.isNotEmpty
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : null),
                  ),
                ),
                if (_addressError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _addressError!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.red),
                  ),
                ],
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
                const SizedBox(height: 12),
                DropdownButtonFormField<BoutiqueSpecialite>(
                  initialValue: _selectedSpecialite,
                  decoration: const InputDecoration(labelText: 'Specialite'),
                  items: BoutiqueSpecialite.values
                      .map(
                        (specialite) => DropdownMenuItem(
                          value: specialite,
                          child: Text(specialite.displayLabel),
                        ),
                      )
                      .toList(),
                  onChanged: _isEditing
                      ? null
                      : (value) {
                          setState(() {
                            _selectedSpecialite = value;
                          });
                        },
                  validator: (value) =>
                      value == null ? 'Selectionne une specialite' : null,
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
                _TelephoneFieldsEditor(
                  fields: _telephoneFields,
                  onAddField: _addTelephoneField,
                  onRemoveField: _removeTelephoneField,
                  buildSuffix: _buildTelephoneSuffix,
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
                      isOffline ||
                              isSaving ||
                              !_hasValidatedTelephones ||
                              _isAnyTelephoneChecking
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

  Widget? _buildTelephoneSuffix(
    BuildContext context,
    _TelephoneFieldState field,
  ) {
    if (field.isChecking) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final current = field.controller.text.trim();
    final hasValidated =
        field.isValid &&
        field.lastValidatedValue == current &&
        current.isNotEmpty;

    if (hasValidated) {
      return const Icon(Icons.check_circle, color: Color(0xFF16A34A));
    }

    final theme = Theme.of(context);
    final hasErrorFeedback = !field.isValid && field.feedback != null;
    final iconData = hasErrorFeedback
        ? Icons.error_outline
        : Icons.check_circle_outline;
    final iconColor = hasErrorFeedback
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return IconButton(
      onPressed: () => _validateTelephone(field),
      icon: Icon(iconData, color: iconColor),
      tooltip: 'Verifier le numero',
    );
  }

  void _handleTelephoneChanged(_TelephoneFieldState field) {
    final current = field.controller.text.trim();
    final alreadyValidated =
        field.lastValidatedValue != null && current == field.lastValidatedValue;

    if (alreadyValidated) {
      if (!field.isValid) {
        setState(() {
          field.isValid = true;
        });
      }
      return;
    }

    if (field.isValid ||
        field.feedback != null ||
        field.lastValidatedValue != null) {
      setState(() {
        field
          ..isValid = false
          ..feedback = null
          ..lastValidatedValue = null;
      });
    }
  }

  Future<void> _validateTelephone(_TelephoneFieldState field) async {
    if (field.isChecking) return;

    final telephone = field.controller.text.trim();
    if (telephone.isEmpty) {
      setState(() {
        field
          ..isValid = false
          ..feedback = 'Renseigne un numero avant de lancer la verification.'
          ..lastValidatedValue = null;
      });
      return;
    }

    if (_isDuplicateInForm(field, telephone)) {
      setState(() {
        field
          ..isValid = false
          ..feedback = 'Ce numero est deja renseigne dans le formulaire.'
          ..lastValidatedValue = null;
      });
      return;
    }

    setState(() {
      field
        ..isChecking = true
        ..feedback = null;
    });

    try {
      final controller = ref.read(boutiqueListControllerProvider.notifier);
      final available = await controller.isTelephoneAvailable(
        telephone,
        excludeId: widget.boutiqueId,
      );
      if (!mounted) return;
      setState(() {
        field
          ..isChecking = false
          ..isValid = available
          ..lastValidatedValue = telephone
          ..feedback = available
              ? 'Numero valide. Tu peux continuer.'
              : 'Ce numero est deja enregistre. Tu ne peux pas reutiliser un numero existant.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        field
          ..isChecking = false
          ..isValid = false
          ..lastValidatedValue = null
          ..feedback =
              'Verification impossible pour le moment. Reessaie dans un instant.';
      });
    }
  }

  _TelephoneFieldState _createTelephoneField(String initialValue) {
    final controller = TextEditingController(text: initialValue);
    final field = _TelephoneFieldState(controller);
    field.listener = () => _handleTelephoneChanged(field);
    controller.addListener(field.listener!);
    return field;
  }

  void _addTelephoneField() {
    setState(() {
      _telephoneFields.add(_createTelephoneField(''));
    });
  }

  void _removeTelephoneField(_TelephoneFieldState field) {
    if (_telephoneFields.length == 1) return;
    setState(() {
      _telephoneFields.remove(field);
    });
    field.dispose();
  }

  void _setTelephoneValues(List<String> values) {
    for (final field in _telephoneFields) {
      field.dispose();
    }
    _telephoneFields
      ..clear()
      ..addAll(
        (values.isEmpty ? [''] : values).map((value) {
          final field = _createTelephoneField(value);
          final trimmed = value.trim();
          if (trimmed.isNotEmpty) {
            field
              ..isValid = true
              ..lastValidatedValue = trimmed;
          }
          return field;
        }),
      );
  }

  bool _isDuplicateInForm(_TelephoneFieldState currentField, String value) {
    final normalized = value.trim().toLowerCase();
    return _telephoneFields.any((field) {
      if (field == currentField) return false;
      final otherValue = field.controller.text.trim().toLowerCase();
      return otherValue.isNotEmpty && otherValue == normalized;
    });
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

    final shouldFetchLocation = _photoPaths.isEmpty;

    setState(() {
      _photoPaths = [..._photoPaths, image.path];
      if (shouldFetchLocation) {
        _locationMessage = 'Recuperation de la localisation du telephone...';
        _latitude = null;
        _longitude = null;
        _dateDeVisite = DateTime.now();
      } else {
        _dateDeVisite ??= DateTime.now();
      }
    });

    if (shouldFetchLocation) {
      await _fetchDeviceLocation();
    }
  }

  void _removePhotoAt(int index) {
    if (index < 0 || index >= _photoPaths.length) return;
    setState(() {
      _photoPaths = List.of(_photoPaths)..removeAt(index);
      if (_photoPaths.isEmpty) {
        _latitude = null;
        _longitude = null;
        _dateDeVisite = null;
        _adresseController.clear();
        _addressError = null;
        _isResolvingAddress = false;
        _locationMessage =
            'La localisation sera determinee automatiquement via le GPS du telephone lors de la premiere photo.';
      }
    });
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
      if (latitude == null || longitude == null) {
        _adresseController.clear();
        _addressError = 'Adresse indisponible.';
      }
    });

    if (latitude != null && longitude != null) {
      await _resolveAddressFromLocation(latitude, longitude);
    }
  }

  Future<void> _resolveAddressFromLocation(
    double latitude,
    double longitude,
  ) async {
    setState(() {
      _isResolvingAddress = true;
      _addressError = null;
    });

    ReverseGeocodingAddress? address;
    String? error;
    try {
      final cache = ref.read(reverseGeocodingCacheProvider);
      address = await cache.resolve(latitude: latitude, longitude: longitude);
      if (address == null) {
        error = 'Adresse indisponible.';
      }
    } catch (_) {
      error = 'Adresse indisponible.';
    }

    if (!mounted) return;

    setState(() {
      _isResolvingAddress = false;
      if (address != null) {
        _adresseController.text = address.formatted;
        _addressError = null;
      } else {
        _adresseController.clear();
        _addressError = error ?? 'Adresse indisponible.';
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSpecialite == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selectionne la specialite de la boutique.'),
        ),
      );
      return;
    }

    if (!_hasValidatedTelephones) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Valide tous les numeros de telephone avant de continuer.',
          ),
        ),
      );
      return;
    }

    if (!_isEditing) {
      if (_photoPaths.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ajoute au moins une photo pour enregistrer la boutique.',
            ),
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
    final telephones = _telephoneFields
        .map((field) => field.controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    final boutique = Boutique(
      id: widget.boutiqueId ?? '',
      nom: _nomController.text.trim(),
      nomGerantComplet: _nomGerantController.text.trim(),
      collectorId: _collectorId ?? '',
      specialite: _selectedSpecialite!,
      adresse: _adresseController.text.trim().isEmpty
          ? null
          : _adresseController.text.trim(),
      telephones: telephones,
      latitude: _latitude,
      longitude: _longitude,
      photoPaths: _photoPaths,
      dateDeVisite: visitDate,
      submittedAt: _submittedAt,
      syncStatus: _syncStatus,
    );

    await controller.createOrUpdate(boutique);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _loadExistingValues() async {
    final boutique = ref
        .read(boutiqueListControllerProvider)
        .boutiques
        .where((item) => item.id == widget.boutiqueId)
        .cast<Boutique?>()
        .firstWhere((item) => item != null, orElse: () => null);
    if (boutique == null) {
      setState(() {
        _locationMessage =
            'La localisation sera determinee automatiquement via le GPS du telephone lors de la premiere photo.';
      });
      return;
    }

    setState(() {
      _nomController.text = boutique.nom;
      _nomGerantController.text = boutique.nomGerantComplet;
      _collectorId = boutique.collectorId;
      _selectedSpecialite = boutique.specialite;
      _adresseController.text = boutique.adresse ?? '';
      _setTelephoneValues(boutique.telephones);
      _photoPaths = boutique.photoPaths;
      _dateDeVisite = boutique.dateDeVisite;
      _submittedAt = boutique.submittedAt;
      _syncStatus = boutique.syncStatus;
      _latitude = boutique.latitude;
      _longitude = boutique.longitude;
      _locationMessage = boutique.latitude != null && boutique.longitude != null
          ? 'Coordonnees deja renseignees pour cette boutique.'
          : 'Prends une premiere photo pour recuperer automatiquement la localisation.';
    });

    if ((boutique.adresse == null || boutique.adresse!.isEmpty) &&
        boutique.latitude != null &&
        boutique.longitude != null) {
      await _resolveAddressFromLocation(
        boutique.latitude!,
        boutique.longitude!,
      );
    }
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
              'Seuls le nom et les numeros de telephone peuvent etre modifies pour cette boutique.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPickerSection extends StatelessWidget {
  const _PhotoPickerSection({
    required this.photoPaths,
    required this.isEditable,
    this.onAddPhoto,
    this.onRemovePhoto,
  });

  final List<String> photoPaths;
  final bool isEditable;
  final VoidCallback? onAddPhoto;
  final ValueChanged<int>? onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Photos de la boutique',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (photoPaths.isEmpty)
          GestureDetector(
            onTap: isEditable ? onAddPhoto : null,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFFE5E7EB),
                border: Border.all(
                  color: Colors.blueGrey.withValues(alpha: 0.1),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_camera_outlined, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      isEditable
                          ? 'Ajoute au moins une photo'
                          : 'Aucune photo disponible',
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < photoPaths.length; i++)
                _PhotoThumbnail(
                  path: photoPaths[i],
                  index: i,
                  totalCount: photoPaths.length,
                  isEditable: isEditable,
                  onRemove: onRemovePhoto,
                ),
            ],
          ),
        const SizedBox(height: 12),
        if (isEditable)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAddPhoto,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Ajouter une photo'),
            ),
          ),
      ],
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({
    required this.path,
    required this.index,
    required this.totalCount,
    required this.isEditable,
    required this.onRemove,
  });

  final String path;
  final int index;
  final int totalCount;
  final bool isEditable;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildPhotoPreview(path),
            ),
          ),
          if (!isEditable)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black.withValues(alpha: 0.25),
                ),
                child: const Center(
                  child: Icon(Icons.lock_outline, color: Colors.white70),
                ),
              ),
            )
          else if (onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.55),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => onRemove!(index),
              ),
            ),
          Positioned(
            bottom: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${index + 1}/$totalCount',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelephoneFieldsEditor extends StatelessWidget {
  const _TelephoneFieldsEditor({
    required this.fields,
    required this.onAddField,
    required this.onRemoveField,
    required this.buildSuffix,
  });

  final List<_TelephoneFieldState> fields;
  final VoidCallback onAddField;
  final void Function(_TelephoneFieldState field) onRemoveField;
  final Widget? Function(BuildContext context, _TelephoneFieldState field)
  buildSuffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: fields[i].controller,
                  decoration: InputDecoration(
                    labelText: 'Telephone ${i + 1}',
                    prefixIcon: const Icon(Icons.phone),
                    suffixIcon: buildSuffix(context, fields[i]),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 8),
              if (fields.length > 1)
                IconButton(
                  tooltip: 'Supprimer ce numero',
                  onPressed: () => onRemoveField(fields[i]),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
            ],
          ),
          if (fields[i].feedback != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                fields[i].feedback!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: fields[i].isValid
                      ? const Color(0xFF16A34A)
                      : theme.colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onAddField,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un numero'),
          ),
        ),
      ],
    );
  }
}

class _OfflineFormBanner extends StatelessWidget {
  const _OfflineFormBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEAE5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFB8C00)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off, color: Color(0xFFEF6C00)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Soumission indisponible hors connexion',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFBF360C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reconnecte-toi a Internet pour prendre des photos et enregistrer de nouvelles boutiques.',
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

class _TelephoneFieldState {
  _TelephoneFieldState(this.controller);

  final TextEditingController controller;
  bool isChecking = false;
  bool isValid = false;
  String? feedback;
  String? lastValidatedValue;
  VoidCallback? listener;

  void dispose() {
    if (listener != null) {
      controller.removeListener(listener!);
    }
    controller.dispose();
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
