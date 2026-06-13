import 'package:accessibility_nav_assistant/services/location_service.dart';
import 'package:checks/checks.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:test/test.dart';

class _FakeGeolocatorPlatform extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  _FakeGeolocatorPlatform({
    required this.permission,
    this.permissionAfterRequest,
    this.position,
    this.positionError,
  });

  final LocationPermission permission;
  final LocationPermission? permissionAfterRequest;
  final Position? position;
  final Object? positionError;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async =>
      permissionAfterRequest ?? permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (positionError != null) {
      throw positionError!;
    }
    return position!;
  }
}

Position _samplePosition() => Position(
      latitude: 42.3192,
      longitude: -83.0391,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  group('LocationService.getCurrentPlace', () {
    test('returns the GPS position when permission is already granted',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
        permission: LocationPermission.whileInUse,
        position: _samplePosition(),
      );

      final place = await LocationService.instance.getCurrentPlace();

      check(place.id).equals('gps_current');
      check(place.lat).equals(42.3192);
      check(place.lon).equals(-83.0391);
      check(place.address).equals('42.3192° N, 83.0391° W');
    });

    test('requests permission and returns GPS position when granted',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
        permission: LocationPermission.denied,
        permissionAfterRequest: LocationPermission.whileInUse,
        position: _samplePosition(),
      );

      final place = await LocationService.instance.getCurrentPlace();

      check(place.id).equals('gps_current');
    });

    test('falls back to the default place when permission stays denied',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
        permission: LocationPermission.denied,
        permissionAfterRequest: LocationPermission.denied,
      );

      final place = await LocationService.instance.getCurrentPlace();

      check(place.id).equals('origin_default');
    });

    test(
        'falls back to the default place when permission is denied forever',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
        permission: LocationPermission.deniedForever,
      );

      final place = await LocationService.instance.getCurrentPlace();

      check(place.id).equals('origin_default');
    });

    test('falls back to the default place when getCurrentPosition throws',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
        permission: LocationPermission.whileInUse,
        positionError: Exception('no signal'),
      );

      final place = await LocationService.instance.getCurrentPlace();

      check(place.id).equals('origin_default');
    });
  });
}
