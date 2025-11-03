import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'permissions_state.dart';

final permissionsControllerProvider =
    StateNotifierProvider<PermissionsController, PermissionsState>(
      (ref) => PermissionsController(),
    );

class PermissionsController extends StateNotifier<PermissionsState> {
  PermissionsController() : super(const PermissionsState.initial());

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    final cameraStatus = await Permission.camera.status;
    final locationStatus = await Permission.locationWhenInUse.status;
    _updateStateFromStatuses(cameraStatus, locationStatus, requesting: false);
  }

  Future<void> requestPermissions() async {
    state = state.copyWith(isLoading: true);
    final cameraStatus = await requestCameraOnly();
    if (!cameraStatus.isGranted) return;
    await requestLocationOnly();
  }

  Future<void> openSettings() async {
    state = state.copyWith(isLoading: true);
    await openAppSettings();
    final cameraStatus = await Permission.camera.status;
    final locationStatus = await Permission.locationWhenInUse.status;
    _updateStateFromStatuses(cameraStatus, locationStatus, requesting: false);
  }

  Future<PermissionStatus> requestCameraOnly() async {
    state = state.copyWith(isLoading: true);
    final status = await _ensurePermission(Permission.camera);
    final locationStatus = await Permission.locationWhenInUse.status;
    _updateStateFromStatuses(status, locationStatus, requesting: true);
    return status;
  }

  Future<PermissionStatus> requestLocationOnly() async {
    state = state.copyWith(isLoading: true);
    final cameraStatus = await Permission.camera.status;
    final status = await _ensurePermission(Permission.locationWhenInUse);
    _updateStateFromStatuses(cameraStatus, status, requesting: true);
    return status;
  }

  Future<void> refreshStatuses() async {
    final cameraStatus = await Permission.camera.status;
    final locationStatus = await Permission.locationWhenInUse.status;
    _updateStateFromStatuses(cameraStatus, locationStatus, requesting: false);
  }

  Future<PermissionStatus> _ensurePermission(Permission permission) async {
    var status = await permission.status;
    if (!status.isGranted) {
      status = await permission.request();
    }
    return status;
  }

  void _updateStateFromStatuses(
    PermissionStatus cameraStatus,
    PermissionStatus locationStatus, {
    required bool requesting,
  }) {
    final granted = cameraStatus.isGranted && locationStatus.isGranted;
    final permanentlyDenied =
        cameraStatus.isPermanentlyDenied || locationStatus.isPermanentlyDenied;
    final deniedButRequestable =
        !granted && (cameraStatus.isDenied || locationStatus.isDenied);

    String? message;
    if (permanentlyDenied) {
      message =
          'Active les autorisations camera et localisation dans les reglages pour continuer.';
    } else if (deniedButRequestable && requesting) {
      message = 'Les autorisations sont requises pour utiliser l\'application.';
    }

    state = state.copyWith(
      isGranted: granted,
      isLoading: false,
      permanentlyDenied: permanentlyDenied,
      message: message,
    );
  }
}
