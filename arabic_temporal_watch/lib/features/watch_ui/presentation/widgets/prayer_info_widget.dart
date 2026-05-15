// prayer_info_widget.dart
//
// Bottom info area: current prayer (left) and next prayer + countdown (right),
// or just next prayer + countdown centered when no current prayer is active.
//
// Providers consumed:
//   • currentPrayerProvider          — Prayer? for the current prayer window
//   • nextPrayerProvider             — Prayer? for the next prayer
//   • timeUntilNextPrayerProvider    — StreamProvider<Duration>, ticks every second

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../prayer_engine/domain/prayer.dart';
import '../../../prayer_engine/presentation/prayer_provider.dart';

// ── PrayerInfoWidget ───────────────────────────────────────────────────────────

class PrayerInfoWidget extends ConsumerWidget {
  const PrayerInfoWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentAsync = ref.watch(currentPrayerProvider);
    final nextAsync = ref.watch(nextPrayerProvider);
    final countdownAsync = ref.watch(timeUntilNextPrayerProvider);

    final currentPrayer = currentAsync.valueOrNull;
    final nextPrayer = nextAsync.valueOrNull;
    final countdown = countdownAsync.valueOrNull ?? Duration.zero;

    if (nextPrayer == null) {
      return const SizedBox.shrink();
    }

    return _PrayerDisplay(
      currentPrayer: currentPrayer,
      nextPrayer: nextPrayer,
      countdown: countdown,
    );
  }
}

// ── _PrayerDisplay ─────────────────────────────────────────────────────────────

class _PrayerDisplay extends StatelessWidget {
  const _PrayerDisplay({
    required this.currentPrayer,
    required this.nextPrayer,
    required this.countdown,
  });

  final Prayer? currentPrayer;
  final Prayer nextPrayer;
  final Duration countdown;

  @override
  Widget build(BuildContext context) {
    final countdownStr = _formatCountdown(countdown);

    if (currentPrayer == null) {
      return _NextPrayerCentered(
        nextPrayer: nextPrayer,
        countdownStr: countdownStr,
      );
    }

    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Current prayer — left side (LTR layout)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentPrayer!.arabicName,
                  style: TextStyle(
                    fontFamily: 'ArabicDisplay',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: currentPrayer!.color,
                    height: 1.2,
                    shadows: [
                      Shadow(
                        color: currentPrayer!.color.withOpacity(0.55),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 1),
                Text(
                  'الآن',
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

            // Center divider dot
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.silverDim.withOpacity(0.3),
              ),
            ),

            // Next prayer + countdown — right side
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      nextPrayer.arabicName,
                      style: const TextStyle(
                        fontFamily: 'ArabicDisplay',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.goldPrimary,
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
                const SizedBox(width: 10),
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
          ],
        ),
      ),
    );
  }
}

// ── _NextPrayerCentered ────────────────────────────────────────────────────────

class _NextPrayerCentered extends StatelessWidget {
  const _NextPrayerCentered({
    required this.nextPrayer,
    required this.countdownStr,
  });

  final Prayer nextPrayer;
  final String countdownStr;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Row(
          textDirection: TextDirection.rtl,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
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
