// temporal_info_widget.dart
//
// Compact overlay card showing the current Arabic temporal period information.
//
// Content (RTL):
//   • Arabic period name  — large, right-aligned
//   • Latin transliteration — small gold subtext
//   • Duration line       — "٥٢ / ٨٤ دقيقة" in Eastern Arabic numerals
//   • Gradient progress bar — left to right, period primaryColor → goldBright
//
// This widget is designed to float near the top of the watch face as a small
// info card.  It is typically composed inside [WatchScreen] or shown as an
// overlay triggered by a long-press on the watch face.
//
// Providers consumed:
//   • temporalDataProvider  — StreamProvider<TemporalData>

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../temporal_engine/domain/arabic_period.dart';
import '../../../temporal_engine/presentation/temporal_provider.dart';

// ── TemporalInfoWidget ─────────────────────────────────────────────────────────

/// Small information card overlaying the watch face with the current Arabic
/// temporal period details.
///
/// Typically placed near the top-center of the watch face via a [Positioned]
/// widget inside the watch face [Stack].
class TemporalInfoWidget extends ConsumerWidget {
  const TemporalInfoWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final temporalAsync = ref.watch(temporalDataProvider);

    return temporalAsync.when(
      loading: () => const _TemporalCardShimmer(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) => _TemporalCard(data: data),
    );
  }
}

// ── _TemporalCard ──────────────────────────────────────────────────────────────

class _TemporalCard extends StatelessWidget {
  const _TemporalCard({required this.data});

  final TemporalData data;

  @override
  Widget build(BuildContext context) {
    final elapsed = data.elapsed.inMinutes;
    final total = data.totalDuration.inMinutes;
    final fraction = data.progressFraction.clamp(0.0, 1.0);
    final primaryColor = data.primaryColor;

    final elapsedAr = _toArabicNumerals(elapsed);
    final totalAr = _toArabicNumerals(total);

    return Container(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 200),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard.withOpacity(0.90),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primaryColor.withOpacity(0.35),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.18),
            blurRadius: 12,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: AppColors.backgroundDeep.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Arabic period name ────────────────────────────────────────
          Text(
            data.arabicName,
            style: const TextStyle(
              fontFamily: 'ArabicDisplay',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
            textDirection: TextDirection.rtl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 2),

          // ── Transliteration ───────────────────────────────────────────
          Text(
            data.transliteration,
            style: const TextStyle(
              fontFamily: 'ArabicDisplay',
              fontSize: 10,
              color: AppColors.goldPrimary,
              letterSpacing: 1.0,
              height: 1.3,
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 6),

          // ── Duration line ─────────────────────────────────────────────
          Text(
            '$elapsedAr / $totalAr دقيقة',
            style: const TextStyle(
              fontFamily: 'ArabicDisplay',
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
            textDirection: TextDirection.rtl,
          ),

          const SizedBox(height: 6),

          // ── Gradient progress bar ─────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  // Track
                  Container(
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // Fill
                  FractionallySizedBox(
                    alignment: Alignment.centerRight,
                    widthFactor: fraction,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          // RTL: fill grows from right to left.
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            primaryColor,
                            Color.lerp(
                              primaryColor,
                              AppColors.goldBright,
                              0.6,
                            )!,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.4),
                            blurRadius: 4,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _TemporalCardShimmer ───────────────────────────────────────────────────────

/// Placeholder card shown while temporal data is loading.
class _TemporalCardShimmer extends StatelessWidget {
  const _TemporalCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.backgroundCard.withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle, width: 0.5),
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: AppColors.goldAntique,
          ),
        ),
      ),
    );
  }
}

// ── Utility: Eastern Arabic-Indic numerals ─────────────────────────────────────

const _arabicDigits = [
  '٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩',
];

String _toArabicNumerals(int n) {
  if (n < 0) return '−${_toArabicNumerals(-n)}';
  return n.toString().split('').map((c) {
    final d = int.tryParse(c);
    return d != null ? _arabicDigits[d] : c;
  }).join();
}
