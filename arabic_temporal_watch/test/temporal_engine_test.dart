// temporal_engine_test.dart
//
// Unit tests for the Arabic temporal hour engine.
//
// Tests cover:
//   • kDayPeriods / kNightPeriods constants.
//   • ArabicPeriod.globalIndex mapping.
//   • ArabicPeriodSlot.progressAt() boundary and mid-point cases.
//   • TemporalCalculator output for known sunrise/sunset times.
//   • kSegmentAngle constant value.

import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_temporal_watch/core/constants/arabic_periods.dart';
import 'package:arabic_temporal_watch/features/temporal_engine/domain/arabic_period.dart';
import 'package:arabic_temporal_watch/features/temporal_engine/data/temporal_calculator.dart';

void main() {
  group('ArabicPeriod constants', () {
    test('kDayPeriods has exactly 12 entries', () {
      expect(kDayPeriods.length, equals(12));
    });

    test('kNightPeriods has exactly 12 entries', () {
      expect(kNightPeriods.length, equals(12));
    });

    test('All day periods are marked isDay = true', () {
      for (final p in kDayPeriods) {
        expect(p.isDay, isTrue, reason: '${p.transliteration} should be day');
      }
    });

    test('All night periods are marked isNight = true', () {
      for (final p in kNightPeriods) {
        expect(p.isNight, isTrue, reason: '${p.transliteration} should be night');
      }
    });

    test('Day periods have globalIndex 0–11', () {
      for (var i = 0; i < kDayPeriods.length; i++) {
        expect(kDayPeriods[i].globalIndex, equals(i));
      }
    });

    test('Night periods have globalIndex 12–23', () {
      for (var i = 0; i < kNightPeriods.length; i++) {
        expect(kNightPeriods[i].globalIndex, equals(12 + i));
      }
    });

    test('kAllPeriods contains all 24 periods in order', () {
      expect(kAllPeriods.length, equals(24));
      for (var i = 0; i < 24; i++) {
        expect(kAllPeriods[i].globalIndex, equals(i));
      }
    });

    test('kSegmentAngle equals π/12', () {
      expect(kSegmentAngle, closeTo(3.14159265 / 12.0, 1e-9));
    });

    test('All periods have non-empty Arabic names', () {
      for (final p in kAllPeriods) {
        expect(p.arabicName.isNotEmpty, isTrue);
      }
    });

    test('All periods have non-empty descriptions', () {
      for (final p in kAllPeriods) {
        expect(p.arabicDescription.isNotEmpty, isTrue);
      }
    });
  });

  group('ArabicPeriodSlot.progressAt', () {
    // Arbitrary slot: 06:00 → 07:00 (1 hour)
    final start = DateTime(2024, 6, 1, 6, 0);
    final end   = DateTime(2024, 6, 1, 7, 0);
    final slot = ArabicPeriodSlot(
      period: kDayPeriods.first,
      startTime: start,
      endTime: end,
      startAngle: 0.0,
      endAngle: kSegmentAngle,
    );

    test('progress at start = 0.0', () {
      expect(slot.progressAt(start), closeTo(0.0, 1e-6));
    });

    test('progress at end = 1.0', () {
      expect(slot.progressAt(end), closeTo(1.0, 1e-6));
    });

    test('progress at mid-point = 0.5', () {
      final mid = start.add(const Duration(minutes: 30));
      expect(slot.progressAt(mid), closeTo(0.5, 1e-6));
    });

    test('progress clamps below 0 for before-start', () {
      final before = start.subtract(const Duration(minutes: 5));
      expect(slot.progressAt(before), closeTo(0.0, 1e-6));
    });

    test('progress clamps at 1.0 for after-end', () {
      final after = end.add(const Duration(minutes: 5));
      expect(slot.progressAt(after), closeTo(1.0, 1e-6));
    });
  });

  group('TemporalCalculator', () {
    const calculator = TemporalCalculator();

    // Test with well-known Riyadh equinox-ish day:
    // sunrise ~05:30, sunset ~17:30 → 12-hour day, 12-hour night
    final sunrise = DateTime(2024, 3, 20, 5, 30);
    final sunset  = DateTime(2024, 3, 20, 17, 30);
    final nextSunrise = DateTime(2024, 3, 21, 5, 31);

    test('During day: isDay = true', () {
      final now = DateTime(2024, 3, 20, 12, 0); // noon
      final data = calculator.calculate(
        now: now,
        sunrise: sunrise,
        sunset: sunset,
        nextSunrise: nextSunrise,
      );
      expect(data.isDay, isTrue);
    });

    test('During night: isDay = false', () {
      final now = DateTime(2024, 3, 20, 22, 0); // 10 pm
      final data = calculator.calculate(
        now: now,
        sunrise: sunrise,
        sunset: sunset,
        nextSunrise: nextSunrise,
      );
      expect(data.isDay, isFalse);
    });

    test('progressFraction is in [0, 1]', () {
      for (var hour = 0; hour < 24; hour++) {
        final now = DateTime(2024, 3, 20, hour, 30);
        final data = calculator.calculate(
          now: now,
          sunrise: sunrise,
          sunset: sunset,
          nextSunrise: nextSunrise,
        );
        expect(data.progressFraction, inInclusiveRange(0.0, 1.0));
      }
    });

    test('currentPeriod has valid globalIndex 0–23', () {
      final now = DateTime(2024, 3, 20, 10, 0);
      final data = calculator.calculate(
        now: now,
        sunrise: sunrise,
        sunset: sunset,
        nextSunrise: nextSunrise,
      );
      expect(data.currentPeriod.period.globalIndex, inInclusiveRange(0, 23));
    });

    test('allDayPeriods has 12 slots', () {
      final now = DateTime(2024, 3, 20, 10, 0);
      final data = calculator.calculate(
        now: now,
        sunrise: sunrise,
        sunset: sunset,
        nextSunrise: nextSunrise,
      );
      expect(data.allDayPeriods.length, equals(12));
    });

    test('allNightPeriods has 12 slots', () {
      final now = DateTime(2024, 3, 20, 10, 0);
      final data = calculator.calculate(
        now: now,
        sunrise: sunrise,
        sunset: sunset,
        nextSunrise: nextSunrise,
      );
      expect(data.allNightPeriods.length, equals(12));
    });

    test('Day slots: each end == next start', () {
      final now = DateTime(2024, 3, 20, 10, 0);
      final data = calculator.calculate(
        now: now,
        sunrise: sunrise,
        sunset: sunset,
        nextSunrise: nextSunrise,
      );
      final slots = data.allDayPeriods;
      for (var i = 0; i < slots.length - 1; i++) {
        expect(slots[i].endTime, equals(slots[i + 1].startTime));
      }
    });

    test('First day slot starts at sunrise', () {
      final now = DateTime(2024, 3, 20, 10, 0);
      final data = calculator.calculate(
        now: now,
        sunrise: sunrise,
        sunset: sunset,
        nextSunrise: nextSunrise,
      );
      expect(data.allDayPeriods.first.startTime, equals(sunrise));
    });

    test('Last day slot ends at sunset', () {
      final now = DateTime(2024, 3, 20, 10, 0);
      final data = calculator.calculate(
        now: now,
        sunrise: sunrise,
        sunset: sunset,
        nextSunrise: nextSunrise,
      );
      expect(data.allDayPeriods.last.endTime, equals(sunset));
    });
  });
}
