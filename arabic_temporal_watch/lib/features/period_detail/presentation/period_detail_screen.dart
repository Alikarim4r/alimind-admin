// period_detail_screen.dart
//
// Rich detail view for the currently active Arabic temporal period.
// Launched when the user taps the period progress area on the watch face.
//
// Displays: Arabic name, transliteration, time range, duration, progress,
// astronomical description, and the period's characteristic color.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../temporal_engine/domain/arabic_period.dart';

// ── PeriodDetailScreen ────────────────────────────────────────────────────────

class PeriodDetailScreen extends StatelessWidget {
  const PeriodDetailScreen({super.key, required this.slot});

  final ArabicPeriodSlot slot;

  @override
  Widget build(BuildContext context) {
    final period = slot.period;
    final color = period.primaryColor;
    final now = DateTime.now();
    final progress = slot.progressAt(now).clamp(0.0, 1.0);

    // Format time range
    final startStr = _formatTime(slot.startTime);
    final endStr = _formatTime(slot.endTime);
    final durationMin = slot.duration.inMinutes;
    final elapsed = (progress * durationMin).round();
    final remaining = durationMin - elapsed;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: CustomScrollView(
        slivers: [
          // ── App Bar with period color header ─────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.backgroundDeep,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: AppColors.goldPrimary, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _PeriodHeader(
                period: period,
                progress: progress,
                color: color,
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 24),

                // Period name
                Text(
                  period.arabicName,
                  style: TextStyle(
                    fontFamily: 'ArabicDisplay',
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 1.0,
                    shadows: [
                      Shadow(
                        color: color.withAlpha(80),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  period.transliteration,
                  style: const TextStyle(
                    fontFamily: 'ArabicDisplay',
                    fontSize: 14,
                    color: AppColors.silverDim,
                    letterSpacing: 3.0,
                  ),
                ),

                const SizedBox(height: 24),
                _Divider(color: color),
                const SizedBox(height: 24),

                // Time range
                Row(
                  children: [
                    _TimeChip(label: 'البداية', time: startStr, color: color),
                    const Spacer(),
                    const Icon(Icons.arrow_forward, color: AppColors.silverDim, size: 16),
                    const Spacer(),
                    _TimeChip(label: 'النهاية', time: endStr, color: color),
                  ],
                ),

                const SizedBox(height: 24),

                // Progress bar
                _ProgressSection(
                  progress: progress,
                  elapsed: elapsed,
                  remaining: remaining,
                  total: durationMin,
                  color: color,
                ),

                const SizedBox(height: 28),
                _Divider(color: color),
                const SizedBox(height: 24),

                // Description
                const Text(
                  'الوصف الفلكي',
                  style: TextStyle(
                    fontFamily: 'ArabicDisplay',
                    fontSize: 13,
                    color: AppColors.silverDim,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  period.arabicDescription,
                  style: const TextStyle(
                    fontFamily: 'ArabicDisplay',
                    fontSize: 17,
                    color: AppColors.silverLight,
                    height: 2.0,
                    letterSpacing: 0.3,
                  ),
                ),

                const SizedBox(height: 24),
                _Divider(color: color),
                const SizedBox(height: 24),

                // Period type badge
                _TypeBadge(isDay: period.isDay, color: color),

                const SizedBox(height: 48),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    const indic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String toIndic(String s) =>
        s.split('').map((c) => c == ':' ? ':' : indic[int.parse(c)]).join();
    return toIndic('$h:$m');
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({
    required this.period,
    required this.progress,
    required this.color,
  });
  final ArabicPeriod period;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withAlpha(50),
            AppColors.backgroundDeep,
          ],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _ArcPainter(
                  progress: progress,
                  color: color,
                  isDay: period.isDay,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                period.isDay ? 'نهاري' : 'ليلي',
                style: TextStyle(
                  fontFamily: 'ArabicDisplay',
                  fontSize: 11,
                  color: color.withAlpha(180),
                  letterSpacing: 2.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.progress,
    required this.color,
    required this.isDay,
  });
  final double progress;
  final Color color;
  final bool isDay;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8;

    // Track
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = color.withAlpha(40);
    canvas.drawCircle(center, r, trackPaint);

    // Progress arc
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + progress * 2 * math.pi,
        colors: [color, Color.lerp(color, Colors.white, 0.35)!],
      ).createShader(Rect.fromCircle(center: center, radius: r));

    if (progress > 0.001) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -math.pi / 2,
        progress * 2 * math.pi,
        false,
        arcPaint,
      );
    }

    // Center text: progress %
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${(progress * 100).round()}٪',
        style: TextStyle(
          fontFamily: 'ArabicDisplay',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            color.withAlpha(80),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.time, required this.color});
  final String label;
  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'ArabicDisplay',
            fontSize: 11,
            color: AppColors.silverDim,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.backgroundSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withAlpha(80)),
          ),
          child: Text(
            time,
            style: TextStyle(
              fontFamily: 'ArabicDisplay',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.progress,
    required this.elapsed,
    required this.remaining,
    required this.total,
    required this.color,
  });
  final double progress;
  final int elapsed;
  final int remaining;
  final int total;
  final Color color;

  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    const indic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String toIndic(int n, int pad) =>
        n.toString().padLeft(pad, '0').split('').map((c) => indic[int.parse(c)]).join();
    if (h > 0) return '${toIndic(h, 1)}س ${toIndic(m, 2)}د';
    return '${toIndic(m, 2)} دقيقة';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'التقدم: ${(progress * 100).toStringAsFixed(1)}٪',
              style: TextStyle(
                fontFamily: 'ArabicDisplay',
                fontSize: 13,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            Text(
              'الإجمالي: ${_fmt(total)}',
              style: const TextStyle(
                fontFamily: 'ArabicDisplay',
                fontSize: 11,
                color: AppColors.silverDim,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: color.withAlpha(30),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'مضى: ${_fmt(elapsed)}',
              style: const TextStyle(
                fontFamily: 'ArabicDisplay',
                fontSize: 12,
                color: AppColors.silverDim,
              ),
            ),
            const Spacer(),
            Text(
              'متبقي: ${_fmt(remaining)}',
              style: const TextStyle(
                fontFamily: 'ArabicDisplay',
                fontSize: 12,
                color: AppColors.silverMid,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.isDay, required this.color});
  final bool isDay;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDay ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            isDay ? 'ساعة نهارية — من الشروق إلى الغروب' : 'ساعة ليلية — من الغروب إلى الشروق',
            style: TextStyle(
              fontFamily: 'ArabicDisplay',
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
