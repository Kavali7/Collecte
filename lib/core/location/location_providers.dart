import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'location_service.dart';
import 'quartier_resolver.dart';
import 'reverse_geocoding_cache.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return const GeolocatorLocationService();
});

final reverseGeocodingCacheProvider = Provider<ReverseGeocodingCache>((ref) {
  return ReverseGeocodingCache(
    ttl: const Duration(hours: 12),
    store: ReverseGeocodingCacheStore(),
  );
});

final quartierResolverProvider = Provider<QuartierResolver>((ref) {
  final cache = ref.watch(reverseGeocodingCacheProvider);
  return LocationIqQuartierResolver(cache);
});
