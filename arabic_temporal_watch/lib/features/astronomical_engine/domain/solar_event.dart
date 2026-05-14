// solar_event.dart
//
// Domain model for a discrete solar/lunar event at a specific moment in time.
// Events carry the computed time plus the sun's geometric position at that
// instant so callers never need to re-derive azimuth/altitude from the time.

import 'package:equatable/equatable.dart';

/// Every distinct solar or lunar horizon-crossing (or extreme) the engine
/// can compute.
enum SolarEventType {
  /// Sun centre at −18° altitude – true astronomical night ends/begins.
  astronomicalDawn,

  /// Sun centre at −12° altitude – nautical twilight begins/ends.
  nauticalDawn,

  /// Sun centre at −6° altitude – civil twilight begins/ends.
  civilDawn,

  /// Upper limb of the sun at 0° (standard −0.8333° for refraction + semi-diameter).
  sunrise,

  /// Sun transits the observer's meridian – maximum altitude of the day.
  solarNoon,

  /// Upper limb of the sun at 0° (same refraction correction as sunrise).
  sunset,

  /// Sun centre at −6° altitude – civil dusk.
  civilDusk,

  /// Sun centre at −12° altitude – nautical dusk.
  nauticalDusk,

  /// Sun centre at −18° altitude – true astronomical night begins.
  astronomicalDusk,

  /// Moon's upper limb crosses the eastern horizon.
  moonrise,

  /// Moon's upper limb crosses the western horizon.
  moonset,
}

/// Extension helpers on [SolarEventType] for display and ordering logic.
extension SolarEventTypeX on SolarEventType {
  /// Human-readable label used in the UI layer.
  String get label {
    switch (this) {
      case SolarEventType.astronomicalDawn:
        return 'Astronomical Dawn';
      case SolarEventType.nauticalDawn:
        return 'Nautical Dawn';
      case SolarEventType.civilDawn:
        return 'Civil Dawn';
      case SolarEventType.sunrise:
        return 'Sunrise';
      case SolarEventType.solarNoon:
        return 'Solar Noon';
      case SolarEventType.sunset:
        return 'Sunset';
      case SolarEventType.civilDusk:
        return 'Civil Dusk';
      case SolarEventType.nauticalDusk:
        return 'Nautical Dusk';
      case SolarEventType.astronomicalDusk:
        return 'Astronomical Dusk';
      case SolarEventType.moonrise:
        return 'Moonrise';
      case SolarEventType.moonset:
        return 'Moonset';
    }
  }

  /// Solar altitude threshold (degrees) that defines the event.
  /// Returns null for events (noon, moonrise, moonset) where altitude
  /// is not a fixed threshold.
  double? get altitudeThreshold {
    switch (this) {
      case SolarEventType.astronomicalDawn:
      case SolarEventType.astronomicalDusk:
        return -18.0;
      case SolarEventType.nauticalDawn:
      case SolarEventType.nauticalDusk:
        return -12.0;
      case SolarEventType.civilDawn:
      case SolarEventType.civilDusk:
        return -6.0;
      case SolarEventType.sunrise:
      case SolarEventType.sunset:
        // Standard depression angle: −0.8333° accounts for atmospheric
        // refraction (~0.5667°) and solar semi-diameter (~0.2667°).
        return -0.8333;
      case SolarEventType.solarNoon:
      case SolarEventType.moonrise:
      case SolarEventType.moonset:
        return null;
    }
  }

  /// Whether this event occurs in the morning half of the day.
  bool get isMorning {
    switch (this) {
      case SolarEventType.astronomicalDawn:
      case SolarEventType.nauticalDawn:
      case SolarEventType.civilDawn:
      case SolarEventType.sunrise:
      case SolarEventType.moonrise:
        return true;
      default:
        return false;
    }
  }

  /// Whether this is a lunar (moon) event.
  bool get isLunar =>
      this == SolarEventType.moonrise || this == SolarEventType.moonset;
}

// ---------------------------------------------------------------------------
// SolarEvent model
// ---------------------------------------------------------------------------

/// A single computed solar or lunar event.
///
/// [time]     – The UTC moment at which the event occurs.
/// [type]     – Which event this represents.
/// [azimuth]  – Compass bearing (°, 0 = North, clockwise) of the sun/moon
///              body at [time].
/// [altitude] – Geometric altitude (°) of the body's centre above the
///              mathematical horizon at [time].  Negative values are below
///              the horizon.
class SolarEvent extends Equatable {
  const SolarEvent({
    required this.time,
    required this.type,
    required this.azimuth,
    required this.altitude,
  });

  /// UTC time of the event.
  final DateTime time;

  /// Which astronomical event this is.
  final SolarEventType type;

  /// Azimuth of the body at [time], measured in degrees clockwise from North.
  /// Range: [0°, 360°).
  final double azimuth;

  /// Altitude of the body's centre at [time], in degrees.
  /// Positive = above horizon, negative = below.
  final double altitude;

  // ---------------------------------------------------------------------------
  // Derived convenience getters
  // ---------------------------------------------------------------------------

  /// The event's local time string (caller should format with intl as needed).
  DateTime get localTime => time.toLocal();

  /// True when the event time is in the past relative to [now].
  bool isPast([DateTime? now]) => time.isBefore(now ?? DateTime.now().toUtc());

  // ---------------------------------------------------------------------------
  // Equatable / value semantics
  // ---------------------------------------------------------------------------

  @override
  List<Object?> get props => [time, type, azimuth, altitude];

  @override
  String toString() =>
      'SolarEvent(type: ${type.label}, time: $time, '
      'azimuth: ${azimuth.toStringAsFixed(2)}°, '
      'altitude: ${altitude.toStringAsFixed(4)}°)';

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  SolarEvent copyWith({
    DateTime? time,
    SolarEventType? type,
    double? azimuth,
    double? altitude,
  }) {
    return SolarEvent(
      time: time ?? this.time,
      type: type ?? this.type,
      azimuth: azimuth ?? this.azimuth,
      altitude: altitude ?? this.altitude,
    );
  }
}
