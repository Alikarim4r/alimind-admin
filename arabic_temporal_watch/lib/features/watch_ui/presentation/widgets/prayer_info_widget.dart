// prayer_info_widget.dart
//
// Bottom bar widget displaying current and next prayer information with a
// live countdown timer.
//
// Layout (RTL, glassmorphism card):
//   ┌───────────────────────────────────────────────────────────┐
//   │  ● الفجر  ٠٣:٤٨    │   العشاء ←  ٠١:٢٢:٠٨  │
//   │  (current, Arabic) │   (next + countdown)    │
//   └───────────────────────────────────────────────────────────┘
//
// Providers consumed:
//   • prayerTimesProvider       — full PrayerTimes object
//   • currentPrayerProvider     — Prayer? for the current period
//   • nextPrayerProvider        — Prayer? for the next prayer
//   • timeUntilNextPrayerProvider — StreamProvider<Duration>, ticks every second

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../prayer_engine/domain/prayer.dart';
import '../../../prayer_engine/presentation/prayer_provider.dart';

// ── PrayerInfoWidget ───────────────────────────────────────────────────────────

/// Compact bottom bar that shows current and next prayer info with a live
/// countdown.  Uses a glassmorphism-style dark card with gold text.
class PrayerInfoWidget extends ConsumerWidget {
  const PrayerInfoWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerAsync = ref.watch(prayerTimesProvider);
    final currentAsync = ref.watch(currentPrayerProvider);
    final nextAsync = ref.watch(nextPrayerProvider);
    final countdownAsync = ref.watch(timeUntilNextPrayerProvider);

    return prayerAsync.when(
      loading: () => const _LoadingBar(),
      error: (_, __) => const _ErrorBar(),
      data: (times) {
        final currentPrayer = currentAsync.valueOrNull;
        final nextPrayer = nextAsync.valueOrNull;
        final countdown = countdownAsync.valueOrNull ?? Duration.zero;

        return _PrayerCard(
          currentPrayer: currentPrayer,
          nextPrayer: nextPrayer,
          countdown: countdown,
          prayerTimes: times,
        );
      },
    );
  }
}

// ── _PrayerCard ────────────────────────────────────────────────────────────────

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({
    required this.currentPrayer,
    required this.nextPrayer,
    required this.countdown,
    required this.prayerTimes,
  });

  final Prayer? currentPrayer;
  final Prayer? nextPrayer;
  final Duration countdown;
  final PrayerTimes prayerTimes;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderNormal,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.backgroundDeep.withOpacity(0.6),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top row: current prayer (large) + next prayer + countdown ────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                // Current prayer — large Arabic name + colored dot
                Expanded(
                  flex: 5,
                  child: _CurrentPrayerCell(prayer: currentPrayer),
                ),

                // Divider
                Container(
                  width: 0.5,
                  height: 44,
                  color: AppColors.borderNormal,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),

                // Next prayer + countdown
                Expanded(
                  flex: 7,
                  child: _NextPrayerCell(
                    prayer: nextPrayer,
                    countdown: countdown,
                  ),
                ),
              ],
            ),
          ),

          // ── Prayer time dots row ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _PrayerDotsRow(
              prayerTimes: prayerTimes,
              currentPrayer: currentPrayer,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _CurrentPrayerCell ─────────────────────────────────────────────────────────

class _CurrentPrayerCell extends StatelessWidget {
  const _CurrentPrayerCell({required this.prayer});

  final Prayer? prayer;

  @override
  Widget build(BuildContext context) {
    if (prayer == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'بين الصلاتين',
            style: const TextStyle(
              fontFamily: 'ArabicDisplay',
              fontSize: 11,
              color: AppColors.textMuted,
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      );
    }

    final p = prayer!;
    final timeStr = _formatTime(p.time);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Colored dot + Arabic name
        Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl,
          children: [
            Text(
              p.arabicName,
              style: TextStyle(
                fontFamily: 'ArabicDisplay',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(width: 6),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: p.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: p.color.withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          timeStr,
          style: const TextStyle(
            fontFamily: 'ArabicDisplay',
            fontSize: 13,
            color: AppColors.textAccent,
            letterSpacing: 1.0,
          ),
          textDirection: TextDirection.ltr,
        ),
      ],
    );
  }
}

// ── _NextPrayerCell ────────────────────────────────────────────────────────────

class _NextPrayerCell extends StatelessWidget {
  const _NextPrayerCell({
    required this.prayer,
    required this.countdown,
  });

  final Prayer? prayer;
  final Duration countdown;

  @override
  Widget build(BuildContext context) {
    if (prayer == null) {
      return const Text(
        'لا توجد صلاة قادمة',
        style: TextStyle(
          fontFamily: 'ArabicDisplay',
          fontSize: 12,
          color: AppColors.textMuted,
        ),
        textDirection: TextDirection.rtl,
      );
    }

    final p = prayer!;
    final countdownStr = _formatCountdown(countdown);
    final nextTimeStr = _formatTime(p.time);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // "Next prayer" label
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 10,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              '${p.arabicName}  $nextTimeStr',
              style: const TextStyle(
                fontFamily: 'ArabicDisplay',
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Countdown — large, monospaced feel
        Text(
          countdownStr,
          style: const TextStyle(
            fontFamily: 'ArabicDisplay',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.goldPrimary,
            letterSpacing: 2.0,
            height: 1.1,
          ),
          textDirection: TextDirection.ltr,
        ),
      ],
    );
  }
}

// ── _PrayerDotsRow ─────────────────────────────────────────────────────────────

/// A horizontal row of 6 prayer-time indicator dots with names beneath them.
class _PrayerDotsRow extends StatelessWidget {
  const _PrayerDotsRow({
    required this.prayerTimes,
    required this.currentPrayer,
  });

  final PrayerTimes prayerTimes;
  final Prayer? currentPrayer;

  @override
  Widget build(BuildContext context) {
    final prayers = prayerTimes.all;
    final now = DateTime.now();

    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: prayers.map((prayer) {
        final isPast = prayer.time.isBefore(now);
        final isCurrent = prayer.name == currentPrayer?.name;
        return _PrayerDot(
          prayer: prayer,
          isPast: isPast,
          isCurrent: isCurrent,
        );
      }).toList(),
    );
  }
}

class _PrayerDot extends StatelessWidget {
  const _PrayerDot({
    required this.prayer,
    required this.isPast,
    required this.isCurrent,
  });

  final Prayer prayer;
  final bool isPast;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final dotColor = isCurrent
        ? prayer.color
        : isPast
            ? prayer.color.withOpacity(0.35)
            : prayer.color.withOpacity(0.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dot
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isCurrent ? 10 : 7,
          height: isCurrent ? 10 : 7,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: prayer.color.withOpacity(0.6),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 3),
        // Short Arabic prayer name
        Text(
          _shortName(prayer.name),
          style: TextStyle(
            fontFamily: 'ArabicDisplay',
            fontSize: 8.5,
            color: isCurrent
                ? AppColors.goldPrimary
                : AppColors.textMuted,
            fontWeight:
                isCurrent ? FontWeight.w700 : FontWeight.w400,
          ),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }

  String _shortName(PrayerName name) {
    switch (name) {
      case PrayerName.fajr:
        return 'فجر';
      case PrayerName.sunrise:
        return 'شروق';
      case PrayerName.dhuhr:
        return 'ظهر';
      case PrayerName.asr:
        return 'عصر';
      case PrayerName.maghrib:
        return 'مغرب';
      case PrayerName.isha:
        return 'عشاء';
    }
  }
}

// ── _LoadingBar / _ErrorBar ────────────────────────────────────────────────────

class _LoadingBar extends StatelessWidget {
  const _LoadingBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.backgroundCard.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle, width: 0.5),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: AppColors.goldPrimary,
          ),
        ),
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.backgroundCard.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle, width: 0.5),
      ),
      child: const Center(
        child: Text(
          'تعذّر تحميل أوقات الصلاة',
          style: TextStyle(
            fontFamily: 'ArabicDisplay',
            fontSize: 12,
            color: AppColors.textMuted,
          ),
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }
}

// ── Utility helpers ────────────────────────────────────────────────────────────

/// Formats a [DateTime] as a 12-hour (h:mm) or 24-hour (HH:mm) string.
String _formatTime(DateTime dt) {
  final h = dt.hour;
  final m = dt.minute.toString().padLeft(2, '0');
  // Use 24-hour notation for simplicity; can be toggled via settings if needed.
  return '${h.toString().padLeft(2, '0')}:$m';
}

/// Formats a [Duration] as HH:MM:SS.
String _formatCountdown(Duration d) {
  if (d == Duration.zero) return '--:--:--';
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}
