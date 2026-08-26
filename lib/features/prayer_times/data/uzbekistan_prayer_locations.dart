import '../domain/prayer_time_models.dart';
import 'uzbekistan_prayer_locations.g.dart';

/// Audited stable region, city, and district slugs accepted canonically by the
/// documented Namoz-vaqti.uz JSON API.
///
/// Coordinates are approximate city centres and are used only when the user
/// explicitly enables a generic calculated fallback. They are not returned by
/// Namoz-vaqti.uz and are never presented as provider metadata.
abstract final class UzbekistanPrayerLocations {
  static const String timeZoneId = 'Asia/Tashkent';
  static const int utcOffsetMinutes = 5 * 60;

  static final List<PrayerLocation> primaryRegions =
      List<PrayerLocation>.unmodifiable(<PrayerLocation>[
        _region('andijon-viloyati', 'Andijon viloyati'),
        _region('buxoro-viloyati', 'Buxoro viloyati'),
        _region('fargona-viloyati', "Farg'ona viloyati"),
        _region('jizzax-viloyati', 'Jizzax viloyati'),
        _region('namangan-viloyati', 'Namangan viloyati'),
        _region('navoiy-viloyati', 'Navoiy viloyati'),
        _region('qashqadaryo-viloyati', 'Qashqadaryo viloyati'),
        _region('qoraqalpogiston', "Qoraqalpog'iston Resp."),
        _region('samarqand-viloyati', 'Samarqand viloyati'),
        _region('sirdaryo-viloyati', 'Sirdaryo viloyati'),
        _region('surxondaryo-viloyati', 'Surxondaryo viloyati'),
        _region('toshkent-shahri', 'Toshkent shahri'),
        _region('toshkent-viloyati', 'Toshkent viloyati'),
        _region('xorazm-viloyati', 'Xorazm viloyati'),
      ]);

  static final List<PrayerLocation> majorCities =
      List<PrayerLocation>.unmodifiable(<PrayerLocation>[
        _city(
          'toshkent-shahri',
          'Toshkent shahri',
          'toshkent-shahri',
          41.2995,
          69.2401,
        ),
        _city(
          'andijon-shahri',
          'Andijon shahri',
          'andijon-viloyati',
          40.7821,
          72.3442,
        ),
        _city(
          'buxoro-shahri',
          'Buxoro shahri',
          'buxoro-viloyati',
          39.7681,
          64.4556,
        ),
        _city(
          'jizzax-shahri',
          'Jizzax shahri',
          'jizzax-viloyati',
          40.1158,
          67.8422,
        ),
        _city(
          'qarshi-shahri',
          'Qarshi shahri',
          'qashqadaryo-viloyati',
          38.8606,
          65.7891,
        ),
        _city(
          'navoiy-shahri',
          'Navoiy shahri',
          'navoiy-viloyati',
          40.0844,
          65.3792,
        ),
        _city(
          'namangan-shahri',
          'Namangan shahri',
          'namangan-viloyati',
          40.9983,
          71.6726,
        ),
        _city(
          'samarqand-shahri',
          'Samarqand shahri',
          'samarqand-viloyati',
          39.6542,
          66.9597,
        ),
        _city(
          'termiz-shahri',
          'Termiz shahri',
          'surxondaryo-viloyati',
          37.2242,
          67.2783,
        ),
        _city(
          'guliston-shahri',
          'Guliston shahri',
          'sirdaryo-viloyati',
          40.4897,
          68.7842,
        ),
        _city(
          'fargona-shahri',
          "Farg'ona shahri",
          'fargona-viloyati',
          40.3894,
          71.7870,
        ),
        _city(
          'urganch-shahri',
          'Urganch shahri',
          'xorazm-viloyati',
          41.5500,
          60.6333,
        ),
        _city(
          'nukus-shahri',
          'Nukus shahri',
          'qoraqalpogiston',
          42.4600,
          59.6166,
        ),
        _city('chirchiq', 'Chirchiq', 'toshkent-viloyati', 41.4689, 69.5822),
      ]);

  /// Cities and districts published in the provider's public region tree.
  /// Major cities are duplicated there but [all] keeps their coordinate-rich
  /// entries from [majorCities].
  static final List<PrayerLocation> publishedSubregions =
      List<PrayerLocation>.unmodifiable(auditedNamozVaqtiUzSubregions());

  static final List<PrayerLocation> all =
      List<PrayerLocation>.unmodifiable(<PrayerLocation>[
        ...majorCities,
        ...publishedSubregions.where(
          (region) => !majorCities.any(
            (city) => city.providerSlug == region.providerSlug,
          ),
        ),
        ...primaryRegions.where(
          (region) =>
              !majorCities.any(
                (city) => city.providerSlug == region.providerSlug,
              ) &&
              !publishedSubregions.any(
                (child) => child.providerSlug == region.providerSlug,
              ),
        ),
      ]);

  static PrayerLocation? bySlug(String slug) {
    for (final location in all) {
      if (location.providerSlug == slug) return location;
    }
    return null;
  }

  static String selectorLabel(PrayerLocation location) {
    final parentSlug = location.parentProviderSlug;
    if (parentSlug == null || parentSlug == location.providerSlug) {
      return location.displayName;
    }
    final parent = primaryRegions
        .where((candidate) => candidate.providerSlug == parentSlug)
        .firstOrNull;
    return parent == null
        ? location.displayName
        : '${location.displayName} — ${parent.displayName}';
  }

  static PrayerLocation _city(
    String slug,
    String name,
    String parentSlug,
    double latitude,
    double longitude,
  ) => PrayerLocation(
    providerSlug: slug,
    displayName: name,
    timeZoneId: timeZoneId,
    utcOffsetMinutes: utcOffsetMinutes,
    parentProviderSlug: parentSlug,
    coordinates: PrayerCoordinates(latitude: latitude, longitude: longitude),
  );

  static PrayerLocation _region(String slug, String name) => PrayerLocation(
    providerSlug: slug,
    displayName: name,
    timeZoneId: timeZoneId,
    utcOffsetMinutes: utcOffsetMinutes,
    parentProviderSlug: slug,
  );
}
