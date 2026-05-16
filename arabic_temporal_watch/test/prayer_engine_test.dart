// prayer_engine_test.dart
//
// Unit tests for the prayer time calculation engine.

import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_temporal_watch/features/prayer_engine/data/prayer_calculator.dart';
import 'package:arabic_temporal_watch/features/prayer_engine/domain/prayer.dart';

void main() {
  const calculator = PrayerCalculator();

  // Riyadh, Saudi Arabia — a well-known reference location.
  const lat = 24.6877;
  const lon = 46.7219;
  final date = DateTime(2024, 6, 15); // summer day

  final params = PrayerCalculationParameters.ummAlQura();
  late PrayerTimes times;

  setUp(() {
    times = calculator.calculate(
      latitude: lat,
      longitude: lon,
      date: date,
      params: params,
    );
  });

  group('PrayerCalculator — Riyadh, June 15', () {
    test('Returns 6 prayers', () {
      expect(times.all.length, equals(6));
    });

    test('Prayer names are in chronological order', () {
      final names = times.all.map((p) => p.name).toList();
      expect(names, [
        PrayerName.fajr,
        PrayerName.sunrise,
        PrayerName.dhuhr,
        PrayerName.asr,
        PrayerName.maghrib,
        PrayerName.isha,
      ]);
    });

    test('Each prayer time is after the previous', () {
      final all = times.all;
      for (var i = 1; i < all.length; i++) {
        expect(
          all[i].time.isAfter(all[i - 1].time),
          isTrue,
          reason: '${all[i].name} should be after ${all[i - 1].name}',
        );
      }
    });

    test('Fajr is before sunrise', () {
      expect(times.fajr.time.isBefore(times.sunrise.time), isTrue);
    });

    test('Sunrise is before Dhuhr', () {
      expect(times.sunrise.time.isBefore(times.dhuhr.time), isTrue);
    });

    test('Dhuhr is before Asr', () {
      expect(times.dhuhr.time.isBefore(times.asr.time), isTrue);
    });

    test('Asr is before Maghrib', () {
      expect(times.asr.time.isBefore(times.maghrib.time), isTrue);
    });

    test('Maghrib is before Isha', () {
      expect(times.maghrib.time.isBefore(times.isha.time), isTrue);
    });

    test('Fajr is in early morning (before 06:00)', () {
      expect(times.fajr.time.hour, lessThan(6));
    });

    test('Dhuhr is around midday (11:00–13:00)', () {
      expect(times.dhuhr.time.hour, inInclusiveRange(11, 13));
    });

    test('All prayer times are on the same calendar date', () {
      for (final p in times.all) {
        expect(p.time.year, equals(date.year));
        expect(p.time.month, equals(date.month));
        expect(p.time.day, equals(date.day));
      }
    });

    test('nextPrayer returns null when after Isha', () {
      final afterIsha = times.isha.time.add(const Duration(hours: 2));
      expect(times.nextPrayer(afterIsha), isNull);
    });

    test('nextPrayer before Fajr returns Fajr', () {
      final midnight = DateTime(date.year, date.month, date.day, 1, 0);
      expect(times.nextPrayer(midnight)?.name, equals(PrayerName.fajr));
    });
  });

  group('PrayerCalculationParameters', () {
    test('ummAlQura creates valid params', () {
      final p = PrayerCalculationParameters.ummAlQura();
      expect(p, isNotNull);
    });

    test('muslimWorldLeague creates valid params', () {
      final p = PrayerCalculationParameters.muslimWorldLeague();
      expect(p, isNotNull);
    });
  });
}
