import 'dart:convert';

enum LocationSource {
  gps,
  network,
  manual,
  defaultMakkah, // fallback
}

class LocationData {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final String? city;
  final String? country;
  final String timezoneName;
  final DateTime timestamp;

  /// Is this a GPS fix or a manual/default location?
  final LocationSource source;

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.city,
    this.country,
    required this.timezoneName,
    required this.timestamp,
    required this.source,
  });

  LocationData copyWith({
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracy,
    String? city,
    String? country,
    String? timezoneName,
    DateTime? timestamp,
    LocationSource? source,
  }) {
    return LocationData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      city: city ?? this.city,
      country: country ?? this.country,
      timezoneName: timezoneName ?? this.timezoneName,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'city': city,
      'country': country,
      'timezoneName': timezoneName,
      'timestamp': timestamp.toIso8601String(),
      'source': source.name,
    };
  }

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: json['altitude'] != null
          ? (json['altitude'] as num).toDouble()
          : null,
      accuracy: json['accuracy'] != null
          ? (json['accuracy'] as num).toDouble()
          : null,
      city: json['city'] as String?,
      country: json['country'] as String?,
      timezoneName: json['timezoneName'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      source: LocationSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => LocationSource.manual,
      ),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory LocationData.fromJsonString(String jsonString) =>
      LocationData.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  @override
  String toString() =>
      'LocationData(lat: $latitude, lng: $longitude, tz: $timezoneName, source: ${source.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationData &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          timezoneName == other.timezoneName &&
          source == other.source;

  @override
  int get hashCode =>
      latitude.hashCode ^
      longitude.hashCode ^
      timezoneName.hashCode ^
      source.hashCode;
}

// ---------------------------------------------------------------------------
// Preset locations for manual selection
// ---------------------------------------------------------------------------

class PresetLocation {
  final String nameArabic;
  final String nameEnglish;
  final double latitude;
  final double longitude;
  final String timezoneName;

  const PresetLocation({
    required this.nameArabic,
    required this.nameEnglish,
    required this.latitude,
    required this.longitude,
    required this.timezoneName,
  });

  LocationData toLocationData() {
    return LocationData(
      latitude: latitude,
      longitude: longitude,
      city: nameEnglish,
      timezoneName: timezoneName,
      timestamp: DateTime.now(),
      source: LocationSource.manual,
    );
  }
}

// ---------------------------------------------------------------------------
// Well-known preset locations
// ---------------------------------------------------------------------------

const List<PresetLocation> kPresetLocations = [
  PresetLocation(
    nameArabic: 'مكة المكرمة',
    nameEnglish: 'Makkah',
    latitude: 21.3891,
    longitude: 39.8579,
    timezoneName: 'Asia/Riyadh',
  ),
  PresetLocation(
    nameArabic: 'المدينة المنورة',
    nameEnglish: 'Madinah',
    latitude: 24.5247,
    longitude: 39.5692,
    timezoneName: 'Asia/Riyadh',
  ),
  PresetLocation(
    nameArabic: 'الرياض',
    nameEnglish: 'Riyadh',
    latitude: 24.6877,
    longitude: 46.7219,
    timezoneName: 'Asia/Riyadh',
  ),
  PresetLocation(
    nameArabic: 'القاهرة',
    nameEnglish: 'Cairo',
    latitude: 30.0444,
    longitude: 31.2357,
    timezoneName: 'Africa/Cairo',
  ),
  PresetLocation(
    nameArabic: 'دبي',
    nameEnglish: 'Dubai',
    latitude: 25.2048,
    longitude: 55.2708,
    timezoneName: 'Asia/Dubai',
  ),
  PresetLocation(
    nameArabic: 'إسطنبول',
    nameEnglish: 'Istanbul',
    latitude: 41.0082,
    longitude: 28.9784,
    timezoneName: 'Europe/Istanbul',
  ),
  PresetLocation(
    nameArabic: 'لندن',
    nameEnglish: 'London',
    latitude: 51.5074,
    longitude: -0.1278,
    timezoneName: 'Europe/London',
  ),
  PresetLocation(
    nameArabic: 'نيويورك',
    nameEnglish: 'New York',
    latitude: 40.7128,
    longitude: -74.0060,
    timezoneName: 'America/New_York',
  ),
  PresetLocation(
    nameArabic: 'كوالالمبور',
    nameEnglish: 'Kuala Lumpur',
    latitude: 3.1390,
    longitude: 101.6869,
    timezoneName: 'Asia/Kuala_Lumpur',
  ),
  PresetLocation(
    nameArabic: 'جاكرتا',
    nameEnglish: 'Jakarta',
    latitude: -6.2088,
    longitude: 106.8456,
    timezoneName: 'Asia/Jakarta',
  ),
];

/// The fallback location used when GPS is unavailable and no saved location exists.
const LocationData kDefaultMakkahLocation = LocationData(
  latitude: 21.3891,
  longitude: 39.8579,
  city: 'Makkah',
  country: 'Saudi Arabia',
  timezoneName: 'Asia/Riyadh',
  // ignore: prefer_const_constructors — DateTime.utc is not const
  timestamp: _kEpoch,
  source: LocationSource.defaultMakkah,
);

// Compile-time constant epoch used as placeholder timestamp for the default location.
const DateTime _kEpoch = DateTime.utc(2000);
