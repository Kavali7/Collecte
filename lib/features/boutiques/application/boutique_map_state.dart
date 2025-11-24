import 'package:collecte_revendeurs/core/location/location_service.dart';

import '../domain/boutique.dart';

class BoutiqueMapState {
  const BoutiqueMapState({
    this.boutiques = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.isOffline = false,
    this.errorMessage,
    this.userLocation,
    this.isLocatingUser = false,
    this.locationErrorMessage,
    this.selectedDate,
    this.isAllTime = false,
    this.canChangeDateScope = false,
  });

  const BoutiqueMapState.initial()
    : boutiques = const [],
      isLoading = true,
      isSyncing = false,
      isOffline = false,
      errorMessage = null,
      userLocation = null,
      isLocatingUser = false,
      locationErrorMessage = null,
      selectedDate = null,
      isAllTime = false,
      canChangeDateScope = false;

  final List<Boutique> boutiques;
  final bool isLoading;
  final bool isSyncing;
  final bool isOffline;
  final String? errorMessage;
  final DeviceLocation? userLocation;
  final bool isLocatingUser;
  final String? locationErrorMessage;
  final DateTime? selectedDate;
  final bool isAllTime;
  final bool canChangeDateScope;

  BoutiqueMapState copyWith({
    List<Boutique>? boutiques,
    bool? isLoading,
    bool? isSyncing,
    bool? isOffline,
    String? errorMessage,
    bool resetError = false,
    DeviceLocation? userLocation,
    bool? isLocatingUser,
    String? locationErrorMessage,
    bool resetLocationError = false,
    bool clearUserLocation = false,
    DateTime? selectedDate,
    bool clearSelectedDate = false,
    bool? isAllTime,
    bool? canChangeDateScope,
  }) {
    return BoutiqueMapState(
      boutiques: boutiques ?? this.boutiques,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      isOffline: isOffline ?? this.isOffline,
      errorMessage: resetError ? null : (errorMessage ?? this.errorMessage),
      userLocation: clearUserLocation
          ? null
          : (userLocation ?? this.userLocation),
      isLocatingUser: isLocatingUser ?? this.isLocatingUser,
      locationErrorMessage: resetLocationError
          ? null
          : (locationErrorMessage ?? this.locationErrorMessage),
      selectedDate:
          clearSelectedDate ? null : (selectedDate ?? this.selectedDate),
      isAllTime: isAllTime ?? this.isAllTime,
      canChangeDateScope: canChangeDateScope ?? this.canChangeDateScope,
    );
  }
}
