import 'dart:convert';

import 'package:http/http.dart' as http;

import 'locationiq_config.dart';

class ReverseGeocodingAddress {
  const ReverseGeocodingAddress({
    required this.formatted,
    required this.city,
    required this.arrondissement,
    required this.quartier,
  });

  final String formatted;
  final String? city;
  final String? arrondissement;
  final String? quartier;
}

class ReverseGeocodingResult {
  const ReverseGeocodingResult.success(this.address)
    : errorMessage = null;

  const ReverseGeocodingResult.failure(this.errorMessage)
    : address = null;

  final ReverseGeocodingAddress? address;
  final String? errorMessage;

  bool get isSuccess => address != null;
}

class LocationIqReverseGeocodingService {
  LocationIqReverseGeocodingService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<ReverseGeocodingResult> resolve({
    required double latitude,
    required double longitude,
  }) async {
    if (locationIqApiKey.isEmpty) {
      return const ReverseGeocodingResult.failure(
        'Clé LocationIQ manquante.',
      );
    }
    final uri = Uri.parse(
      '$locationIqBaseUrl/reverse.php',
    ).replace(
      queryParameters: {
        'key': locationIqApiKey,
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'format': 'json',
        'addressdetails': '1',
        'zoom': '16',
      },
    );

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        return ReverseGeocodingResult.failure(
          'Adresse indisponible (code ${response.statusCode}).',
        );
      }
      final body = jsonDecode(response.body);
      final address = body['address'] as Map<String, dynamic>? ?? {};
      final city = _firstNonEmpty([
        address['city'],
        address['town'],
        address['state'],
        address['region'],
      ]);
      final arrondissement = _firstNonEmpty([
        address['state_district'],
        address['county'],
        address['district'],
      ]);
      final quartier = _firstNonEmpty([
        address['suburb'],
        address['neighbourhood'],
        address['village'],
        address['hamlet'],
      ]);

      final formatted = _formatAddress(
        city: city,
        arrondissement: arrondissement,
        quartier: quartier,
      );

      return ReverseGeocodingResult.success(
        ReverseGeocodingAddress(
          formatted: formatted,
          city: city,
          arrondissement: arrondissement,
          quartier: quartier,
        ),
      );
    } catch (error) {
      return ReverseGeocodingResult.failure(
        'Erreur de geocodage: $error',
      );
    }
  }

  static String _formatAddress({
    String? city,
    String? arrondissement,
    String? quartier,
  }) {
    final safeCity = city ?? 'Ville inconnue';
    final safeArr = arrondissement ?? 'Arrondissement inconnu';
    final safeQuartier = quartier ?? 'Quartier inconnu';
    return '$safeCity / Arr: $safeArr / $safeQuartier';
  }

  static String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}
