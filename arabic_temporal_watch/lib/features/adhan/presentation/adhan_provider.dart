import 'dart:async';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/adhan_service.dart';
import '../domain/adhan_model.dart';
import '../../prayer_engine/domain/prayer.dart' show PrayerName;
import '../../prayer_engine/presentation/prayer_provider.dart';
import '../../settings/presentation/settings_provider.dart';

// ── adhanServiceProvider ───────────────────────────────────────────────────────

final adhanServiceProvider = Provider<AdhanService>(
  (ref) {
    final service = AdhanService();
    ref.onDispose(service.dispose);
    return service;
  },
  name: 'adhanServiceProvider',
);

// ── AdhanNotifier ──────────────────────────────────────────────────────────────

class AdhanNotifier extends StateNotifier<bool> {
  AdhanNotifier(this._ref, this._service) : super(false) {
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  final Ref _ref;
  final AdhanService _service;
  late final Timer _timer;

  // Tracks "prayerName_yyyy-MM-dd" keys already triggered today.
  final Set<String> _triggeredToday = {};
  String? _lastResetDate;

  void _tick(Timer _) {
    final settings = _ref.read(settingsProvider);
    if (!settings.enableAdhan) return;

    final timesAsync = _ref.read(prayerTimesProvider);
    final times = timesAsync.valueOrNull;
    if (times == null) return;

    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';

    // Reset triggered set at the start of a new calendar day.
    if (_lastResetDate != todayKey) {
      _triggeredToday.clear();
      _lastResetDate = todayKey;
    }

    for (final prayer in times.all) {
      final triggerKey = '${prayer.name.name}_$todayKey';
      if (_triggeredToday.contains(triggerKey)) continue;

      final diff = now.difference(prayer.time);
      if (diff.inSeconds >= 0 && diff.inSeconds < 60) {
        _triggeredToday.add(triggerKey);
        if (settings.enableVibration) {
          HapticFeedback.vibrate();
        }
        _playAndUpdateState(
          muezzin: settings.muezzin,
          isFajr: prayer.name == PrayerName.fajr,
        );
      }
    }
  }

  Future<void> _playAndUpdateState({
    required Muezzin muezzin,
    required bool isFajr,
  }) async {
    await _service.playAdhan(muezzin: muezzin, isFajr: isFajr);
    if (mounted) state = _service.isPlaying;
  }

  Future<void> silenceAdhan() async {
    await _service.stop();
    if (mounted) state = false;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

// ── adhanNotifierProvider ──────────────────────────────────────────────────────

final adhanNotifierProvider = StateNotifierProvider<AdhanNotifier, bool>(
  (ref) {
    ref.keepAlive();
    final service = ref.watch(adhanServiceProvider);
    return AdhanNotifier(ref, service);
  },
  name: 'adhanNotifierProvider',
);
