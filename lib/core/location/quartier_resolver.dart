import 'location_constants.dart';
import 'locationiq_reverse_geocoding.dart';
import 'reverse_geocoding_cache.dart';

abstract class QuartierResolver {
  Future<QuartierResolution> resolve({
    required double latitude,
    required double longitude,
  });

  Future<List<QuartierResolution>> resolveBatch(
    List<ReverseGeocodingCoordinate> coordinates,
  );
}

class QuartierResolution {
  const QuartierResolution({
    required this.label,
    required this.isResolved,
    this.address,
  });

  const QuartierResolution.unknown()
    : label = kUnknownQuartierLabel,
      isResolved = false,
      address = null;

  factory QuartierResolution.resolved(String label) {
    final normalized = label.trim().isEmpty ? kUnknownQuartierLabel : label;
    final resolved = normalized != kUnknownQuartierLabel;
    return QuartierResolution(label: normalized, isResolved: resolved);
  }

  factory QuartierResolution.fromAddress(ReverseGeocodingAddress? address) {
    if (address == null) {
      return const QuartierResolution.unknown();
    }
    final label = resolveQuartierLabelOrFallback(address).trim();
    final normalized = label.isEmpty ? kUnknownQuartierLabel : label;
    final resolved = normalized != kUnknownQuartierLabel;
    return QuartierResolution(
      label: normalized,
      isResolved: resolved,
      address: address,
    );
  }

  final String label;
  final bool isResolved;
  final ReverseGeocodingAddress? address;
}

class LocationIqQuartierResolver implements QuartierResolver {
  LocationIqQuartierResolver(this._cache);

  final ReverseGeocodingCache _cache;

  @override
  Future<QuartierResolution> resolve({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final address = await _cache.resolve(
        latitude: latitude,
        longitude: longitude,
      );
      return QuartierResolution.fromAddress(address);
    } catch (_) {
      return const QuartierResolution.unknown();
    }
  }

  @override
  Future<List<QuartierResolution>> resolveBatch(
    List<ReverseGeocodingCoordinate> coordinates,
  ) async {
    if (coordinates.isEmpty) return const [];
    List<ReverseGeocodingAddress?> addresses;
    try {
      addresses = await _cache.resolveBatch(coordinates);
    } catch (_) {
      addresses = List<ReverseGeocodingAddress?>.filled(
        coordinates.length,
        null,
        growable: false,
      );
    }
    return addresses
        .map(QuartierResolution.fromAddress)
        .toList(growable: false);
  }
}
