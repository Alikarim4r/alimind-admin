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

    // The calculator returns wall-clock times in the *device's* timezone, so
    // assertions on `.hour` only hold when the test machine happens to run at
    // UTC+3 like Riyadh. The underlying instant is the same everywhere, so
    // these tests assert in UTC and stay green on any developer machine.

    test('Fajr precedes sunrise by 60–120 minutes', () {
      final gap = times.sunrise.time.difference(times.fajr.time);
      expect(gap.inMinutes, inInclusiveRange(60, 120));
    });

    test('Dhuhr is around solar noon (08:00–10:00 UTC for Riyadh)', () {
      expect(times.dhuhr.time.toUtc().hour, inInclusiveRange(8, 10));
    });

    test('Dhuhr sits midway between sunrise and maghrib', () {
      final morning = times.dhuhr.time.difference(times.sunrise.time);
      final afternoon = times.maghrib.time.difference(times.dhuhr.time);
      // Solar noon is symmetric between sunrise and sunset to within a few
      // minutes (the small drift comes from the equation of time).
      expect((morning - afternoon).inMinutes.abs(), lessThan(15));
    });

    test('All prayer times fall on the same UTC calendar date', () {
      for (final p in times.all) {
        final utc = p.time.toUtc();
        expect(utc.year, equals(date.year));
        expect(utc.month, equals(date.month));
        expect(utc.day, equals(date.day));
      }
    });

    test('nextPrayer returns null when after Isha', () {
      final afterIsha = times.isha.time.add(const Duration(hours: 2));
      expect(times.nextPrayer(afterIsha), isNull);
    });

    test('nextPrayer just before Fajr returns Fajr', () {
      // Anchored to Fajr itself rather than a fixed wall-clock hour, which
      // would land after Fajr on machines west of Riyadh.
      final beforeFajr = times.fajr.time.subtract(const Duration(minutes: 30));
      expect(times.nextPrayer(beforeFajr)?.name, equals(PrayerName.fajr));
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
