import 'package:collecte_revendeurs/core/location/location_service.dart';
import 'package:collecte_revendeurs/features/itinerary/application/stop_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StopDetector', () {
    late DateTime currentTime;
    late StopDetector detector;

    setUp(() {
      currentTime = DateTime(2024, 2, 1, 8);
      detector = StopDetector(clock: () => currentTime);
    });

    test('emits stop when position stays within radius long enough', () {
      final first = const DeviceLocation(latitude: 5.0, longitude: -4.0);
      final second = const DeviceLocation(latitude: 5.0, longitude: -4.0);

      final initialEvent = detector.register(first);
      expect(initialEvent, isNull);

      currentTime = currentTime.add(const Duration(minutes: 3, seconds: 10));
      final event = detector.register(second);
      expect(event, isNotNull);
      expect(event!.latitude, equals(first.latitude));
      expect(event.arrivedAt, equals(DateTime(2024, 2, 1, 8)));
    });

    test('movement outside radius resets candidate', () {
      final origin = const DeviceLocation(latitude: 5.0, longitude: -4.0);
      detector.register(origin);

      currentTime = currentTime.add(const Duration(minutes: 2));
      final far = const DeviceLocation(latitude: 5.002, longitude: -4.0);
      final event = detector.register(far);

      expect(event, isNull);

      currentTime = currentTime.add(const Duration(minutes: 3, seconds: 30));
      final nearAgain = const DeviceLocation(latitude: 5.002, longitude: -4.0);
      final newEvent = detector.register(nearAgain);
      expect(newEvent, isNotNull);
      expect(newEvent!.latitude, equals(nearAgain.latitude));
    });

    test('only emits once per stop until movement occurs', () {
      final location = const DeviceLocation(latitude: 4.5, longitude: -3.9);
      detector.register(location);

      currentTime = currentTime.add(const Duration(minutes: 4));
      final firstEvent = detector.register(location);
      expect(firstEvent, isNotNull);

      currentTime = currentTime.add(const Duration(minutes: 5));
      final duplicate = detector.register(location);
      expect(duplicate, isNull);

      currentTime = currentTime.add(const Duration(minutes: 1));
      final moved = const DeviceLocation(latitude: 4.51, longitude: -3.9);
      detector.register(moved);

      currentTime = currentTime.add(const Duration(minutes: 3, seconds: 5));
      final secondEvent = detector.register(moved);
      expect(secondEvent, isNotNull);
    });
  });
}
