// prayer_info_widget.dart
//
// Ultra-minimal bottom area showing ONLY the current prayer name and time
// remaining until the next prayer.
//
// Design: floating text, no cards, no borders, no boxes.
// Just elegant Arabic typography on the dark background.
//
// Providers consumed:
//   • currentPrayerProvider          — Prayer? for the current period
//   • nextPrayerProvider             — Prayer? for the next prayer
//   • timeUntilNextPrayerProvider    — StreamProvider<Duration>, ticks every second

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../prayer_engine/domain/prayer.dart';
import '../../../prayer_engine/presentation/prayer_provider.dart';

// ── PrayerInfoWidget ───────────────────────────────────────────────────────────

/// Ultra-minimal prayer info — next prayer name and countdown only.
/// No cards, no boxes. Elegant floating text.
class PrayerInfoWidget extends ConsumerWidget {
  const PrayerInfoWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextAsync = ref.watch(nextPrayerProvider);
    final countdownAsync = ref.watch(timeUntilNextPrayerProvider);

    final nextPrayer = nextAsync.valueOrNull;
    final countdown = countdownAsync.valueOrNull ?? Duration.zero;

    if (nextPrayer == null) {
      return const SizedBox.shrink();
    }

    return _MinimalPrayerDisplay(
      nextPrayer: nextPrayer,
      countdown: countdown,
    );
  }
}

// ── _MinimalPrayerDisplay ──────────────────────────────────────────────────────

class _MinimalPrayerDisplay extends StatelessWidget {
  const _MinimalPrayerDisplay({
    required this.nextPrayer,
    required this.countdown,
  });

  final Prayer nextPrayer;
  final Duration countdown;

  @override
  Widget build(BuildContext context) {
    final countdownStr = _formatCountdown(countdown);

    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Row(
          textDirection: TextDirection.rtl,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Next prayer Arabic name — right-aligned (RTL)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  nextPrayer.arabicName,
                  style: const TextStyle(
                    fontFamily: 'ArabicDisplay',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 1),
                Text(
                  'القادمة',
                  style: TextStyle(
                    fontFamily: 'ArabicDisplay',
                    fontSize: 9,
                    color: AppColors.silverDim.withOpacity(0.7),
                    letterSpacing: 0.5,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),

            // Countdown — left side (RTL layout)
            Text(
              countdownStr,
              style: const TextStyle(
                fontFamily: 'ArabicDisplay',
                fontSize: 18,
                fontWeight: FontWeight.w300,
                color: AppColors.goldPrimary,
                letterSpacing: 2.5,
                height: 1.0,
              ),
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Utility helpers ────────────────────────────────────────────────────────────

/// Formats a [Duration] as HH:MM:SS.
String _formatCountdown(Duration d) {
  if (d == Duration.zero) return '--:--';
  final h = d.inHours;
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:$m:$s';
  }
  return '$m:$s';
}
