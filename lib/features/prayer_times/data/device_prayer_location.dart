import 'package:geolocator/geolocator.dart';

import '../domain/prayer_time_models.dart';
import 'uzbekistan_prayer_locations.dart';

enum DevicePrayerLocationStatus {
  acquired,
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  outsideUzbekistan,
  failed,
}

final class DevicePrayerLocationResult {
  const DevicePrayerLocationResult(this.status, {this.location});

  final DevicePrayerLocationStatus status;
  final PrayerLocation? location;
}

abstract interface class DevicePrayerLocationService {
  Future<DevicePrayerLocationResult> requestUzbekistanLocation();
}

/// Requests foreground location only after an explicit user action.
///
/// No background permission or continuous position stream is used. A denied
/// decision is returned immediately to the UI, which keeps manual region
/// selection fully available.
final class GeolocatorDevicePrayerLocationService
    implements DevicePrayerLocationService {
  const GeolocatorDevicePrayerLocationService();

  @override
  Future<DevicePrayerLocationResult> requestUzbekistanLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const DevicePrayerLocationResult(
          DevicePrayerLocationStatus.servicesDisabled,
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const DevicePrayerLocationResult(
          DevicePrayerLocationStatus.permissionDenied,
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const DevicePrayerLocationResult(
          DevicePrayerLocationStatus.permissionDeniedForever,
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final location = _uzbekistanLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      return location == null
          ? const DevicePrayerLocationResult(
              DevicePrayerLocationStatus.outsideUzbekistan,
            )
          : DevicePrayerLocationResult(
              DevicePrayerLocationStatus.acquired,
              location: location,
            );
    } on Object {
      return const DevicePrayerLocationResult(
        DevicePrayerLocationStatus.failed,
      );
    }
  }

  PrayerLocation? _uzbekistanLocation({
    required double latitude,
    required double longitude,
  }) {
    // This action is intentionally Uzbekistan-scoped because the product has
    // no audited timezone lookup database. Outside this broad national bound,
    // the UI asks for a manual region instead of assigning a false timezone.
    if (latitude < 36.5 ||
        latitude > 46.7 ||
        longitude < 55.5 ||
        longitude > 74.0) {
      return null;
    }
    final coordinates = PrayerCoordinates(
      latitude: latitude,
      longitude: longitude,
    );
    final slugLatitude = latitude.toStringAsFixed(4).replaceAll('-', 'm');
    final slugLongitude = longitude.toStringAsFixed(4).replaceAll('-', 'm');
    return PrayerLocation(
      providerSlug:
          '${PrayerLocation.deviceCoordinatesSlugPrefix}'
          '$slugLatitude-$slugLongitude',
      displayName: 'My location',
      timeZoneId: UzbekistanPrayerLocations.timeZoneId,
      utcOffsetMinutes: UzbekistanPrayerLocations.utcOffsetMinutes,
      coordinates: coordinates,
    );
  }
}
