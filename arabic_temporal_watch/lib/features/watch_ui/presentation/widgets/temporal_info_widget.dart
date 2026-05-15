// temporal_info_widget.dart
//
// Minimal overlay showing the current Arabic temporal period.
//
// Design: no cards, no borders, no boxes.
// Just large gold Arabic period name + small silver remaining time,
// floating as a subtle overlay on the watch face.
//
// Providers consumed:
//   • temporalDataProvider  — StreamProvider<TemporalData>

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../temporal_engine/domain/arabic_period.dart';
import '../../../temporal_engine/presentation/temporal_provider.dart';

// ── TemporalInfoWidget ─────────────────────────────────────────────────────────

/// Minimal overlay for the current Arabic temporal period.
/// Arabic name (large gold) + remaining time (small silver).
/// No container — just text floating on the watch face.
class TemporalInfoWidget extends ConsumerWidget {
  const TemporalInfoWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final temporalAsync = ref.watch(temporalDataProvider);

    return temporalAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) => _TemporalOverlay(data: data),
    );
  }
}

// ── _TemporalOverlay ───────────────────────────────────────────────────────────

class _TemporalOverlay extends StatelessWidget {
  const _TemporalOverlay({required this.data});

  final TemporalData data;

  @override
  Widget build(BuildContext context) {
    final remaining = data.remaining;
    final remainingStr = _formatRemaining(remaining);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Arabic period name — large, gold, centered
        Text(
          data.arabicName,
          style: const TextStyle(
            fontFamily: 'ArabicDisplay',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.goldPrimary,
            letterSpacing: 0.5,
            height: 1.2,
            shadows: [
              Shadow(
                color: Color(0x60000000),
                offset: Offset(0, 1),
                blurRadius: 4.0,
              ),
            ],
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 3),

        // Remaining time — small, silver, minimal
        Text(
          remainingStr,
          style: const TextStyle(
            fontFamily: 'ArabicDisplay',
            fontSize: 11,
            fontWeight: FontWeight.w300,
            color: AppColors.silverDim,
            letterSpacing: 1.2,
            height: 1.2,
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Utility helpers ────────────────────────────────────────────────────────────

/// Formats a [Duration] as "MM:SS" remaining.
String _formatRemaining(Duration d) {
  if (d <= Duration.zero) return '00:00';
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    final h = d.inHours.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
  return '$m:$s';
}
