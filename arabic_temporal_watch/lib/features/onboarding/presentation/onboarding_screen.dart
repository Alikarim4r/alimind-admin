// onboarding_screen.dart
//
// Three-page first-run onboarding experience:
//   Page 1 — Welcome: app concept and name.
//   Page 2 — How it works: explanation of Arabic temporal hours.
//   Page 3 — Setup: prayer method selection + finish.
//
// On completion writes 'onboarding_completed = true' to SharedPreferences
// and navigates to the main watch face.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../prayer_engine/domain/prayer.dart' show CalculationMethod;
import '../../settings/presentation/settings_provider.dart';

// ── OnboardingScreen ──────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;

  // Selected prayer method on page 3.
  CalculationMethod _selectedMethod = CalculationMethod.ummAlQura;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    // Persist chosen prayer method.
    await ref
        .read(settingsProvider.notifier)
        .setPrayerMethod(_selectedMethod);

    // Mark onboarding done.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Stack(
        children: [
          // ── Pages ─────────────────────────────────────────────────────────
          PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              _WelcomePage(onNext: _nextPage),
              _HowItWorksPage(onNext: _nextPage),
              _SetupPage(
                selectedMethod: _selectedMethod,
                onMethodChanged: (m) => setState(() => _selectedMethod = m),
                onFinish: _finish,
              ),
            ],
          ),

          // ── Page indicator ─────────────────────────────────────────────────
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: _PageIndicator(current: _currentPage, total: 3),
          ),
        ],
      ),
    );
  }
}

// ── Page 1: Welcome ───────────────────────────────────────────────────────────

class _WelcomePage extends StatefulWidget {
  const _WelcomePage({required this.onNext});
  final VoidCallback onNext;

  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Decorative ring diagram
              const _RingDiagram(size: 180),
              const SizedBox(height: 40),

              // App name
              const Text(
                'الساعة العربية',
                style: TextStyle(
                  fontFamily: 'ArabicDisplay',
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: AppColors.goldPrimary,
                  letterSpacing: 1.5,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Subtitle
              const Text(
                'Arabic Temporal Watch',
                style: TextStyle(
                  fontFamily: 'ArabicDisplay',
                  fontSize: 13,
                  color: AppColors.silverDim,
                  letterSpacing: 4.0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Tagline
              const Text(
                'استعد الوقت العربي الأصيل\nكما عرفه أجدادك',
                style: TextStyle(
                  fontFamily: 'ArabicDisplay',
                  fontSize: 18,
                  color: AppColors.silverMid,
                  height: 1.8,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 56),

              _GoldButton(
                label: 'ابدأ الاستكشاف',
                onTap: widget.onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Page 2: How It Works ──────────────────────────────────────────────────────

class _HowItWorksPage extends StatelessWidget {
  const _HowItWorksPage({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'الساعات الزمنية العربية',
            style: TextStyle(
              fontFamily: 'ArabicDisplay',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.goldPrimary,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Arabic Temporal Hours',
            style: TextStyle(
              fontFamily: 'ArabicDisplay',
              fontSize: 11,
              color: AppColors.silverDim,
              letterSpacing: 3.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Mini ring split diagram
          const _SplitDiagram(),
          const SizedBox(height: 32),

          // Explanation points
          const _InfoCard(
            icon: Icons.wb_sunny_outlined,
            color: AppColors.goldPrimary,
            title: 'ساعات النهار — ١٢ ساعة',
            body:
                'تُقسَّم المدة من الشروق إلى الغروب إلى اثنتي عشرة ساعة متساوية. '
                'تطول في الصيف وتقصر في الشتاء.',
          ),
          const SizedBox(height: 14),
          const _InfoCard(
            icon: Icons.nights_stay_outlined,
            color: AppColors.crescentSilver,
            title: 'ساعات الليل — ١٢ ساعة',
            body:
                'كذلك الليل يُقسَّم من الغروب إلى الشروق. '
                'وقت كل ساعة ليلية يتغير بتغير الفصول والموقع.',
          ),
          const SizedBox(height: 14),
          const _InfoCard(
            icon: Icons.mosque_outlined,
            color: AppColors.prayerFajr,
            title: 'الصلوات والأوقات',
            body:
                'تُثبَّت علامات الصلوات الخمس على الحلقة الدوارة عند '
                'بداية الساعة الزمنية التي تقع فيها، '
                'مما يجعلها مرجعاً بصرياً دقيقاً.',
          ),
          const SizedBox(height: 14),
          const _InfoCard(
            icon: Icons.rotate_left,
            color: AppColors.goldAntique,
            title: 'الحلقة الدوارة',
            body:
                'تدور الحلقة عكس اتجاه عقارب الساعة بحيث تبقى '
                'الساعة الحالية دائماً عند مؤشر الثانية عشرة.',
          ),
          const SizedBox(height: 40),

          _GoldButton(label: 'التالي', onTap: onNext),
        ],
      ),
    );
  }
}

// ── Page 3: Setup ─────────────────────────────────────────────────────────────

class _SetupPage extends StatelessWidget {
  const _SetupPage({
    required this.selectedMethod,
    required this.onMethodChanged,
    required this.onFinish,
  });

  final CalculationMethod selectedMethod;
  final ValueChanged<CalculationMethod> onMethodChanged;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    const methods = [
      (CalculationMethod.ummAlQura, 'أم القرى — مكة المكرمة'),
      (CalculationMethod.muslimWorldLeague, 'رابطة العالم الإسلامي'),
      (CalculationMethod.qatar, 'ديوان الأوقاف القطري'),
      (CalculationMethod.egyptian, 'الهيئة المصرية للمساحة'),
      (CalculationMethod.karachi, 'جامعة العلوم الإسلامية — كراتشي'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'اختر طريقة حساب أوقات الصلاة',
            style: TextStyle(
              fontFamily: 'ArabicDisplay',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.goldPrimary,
              letterSpacing: 0.3,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'يمكنك تغييرها لاحقاً من الإعدادات',
            style: TextStyle(
              fontFamily: 'ArabicDisplay',
              fontSize: 12,
              color: AppColors.silverDim,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Method selector
          ...methods.map((entry) {
            final (method, label) = entry;
            final isSelected = selectedMethod == method;
            return _MethodOption(
              label: label,
              isSelected: isSelected,
              onTap: () => onMethodChanged(method),
            );
          }),

          const SizedBox(height: 40),

          // Location note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: const Row(
              children: [
                Icon(Icons.location_on_outlined,
                    color: AppColors.goldPrimary, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'يستخدم التطبيق موقعك للحساب الفلكي الدقيق. '
                    'عند عدم توفر GPS يُستخدم موقع مكة المكرمة.',
                    style: TextStyle(
                      fontFamily: 'ArabicDisplay',
                      fontSize: 13,
                      color: AppColors.silverMid,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          _GoldButton(label: 'ابدأ', onTap: onFinish),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.goldDark, AppColors.goldPrimary, AppColors.goldLight],
            stops: [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: AppColors.goldPrimary.withOpacity(0.4),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'ArabicDisplay',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.backgroundDeep,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ArabicDisplay',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontFamily: 'ArabicDisplay',
                    fontSize: 13,
                    color: AppColors.silverMid,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodOption extends StatelessWidget {
  const _MethodOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.goldPrimary.withAlpha(20)
              : AppColors.backgroundSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.goldPrimary
                : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.goldPrimary
                      : AppColors.silverDim,
                  width: 1.5,
                ),
                color: isSelected
                    ? AppColors.goldPrimary
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check,
                      size: 12, color: AppColors.backgroundDeep)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'ArabicDisplay',
                  fontSize: 14,
                  color: isSelected
                      ? AppColors.goldPrimary
                      : AppColors.silverMid,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? AppColors.goldPrimary : AppColors.silverDim,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ── Decorative painters ───────────────────────────────────────────────────────

class _RingDiagram extends StatefulWidget {
  const _RingDiagram({required this.size});
  final double size;

  @override
  State<_RingDiagram> createState() => _RingDiagramState();
}

class _RingDiagramState extends State<_RingDiagram>
    with SingleTickerProviderStateMixin {
  late AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _spin,
      builder: (_, __) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _RingDiagramPainter(rotation: _spin.value * 2 * math.pi),
      ),
    );
  }
}

class _RingDiagramPainter extends CustomPainter {
  const _RingDiagramPainter({required this.rotation});
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-rotation);

    // 24 segments
    for (var i = 0; i < 24; i++) {
      final angle = i * math.pi / 12;
      final isDay = i < 12;
      final t = i / 24.0;

      final color = isDay
          ? Color.lerp(const Color(0xFFFF6B35), const Color(0xFF3A5BA8), t * 2)!
          : Color.lerp(const Color(0xFF3A5BA8), const Color(0xFF7BAFD4), (t - 0.5) * 2)!;

      final segPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = color.withAlpha(i == 0 ? 255 : 160);

      final sweep = math.pi / 12 - 0.03;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r - 6),
        angle - math.pi / 2,
        sweep,
        false,
        segPaint,
      );
    }

    // Center dot
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.goldPrimary;
    canvas.drawCircle(Offset.zero, 5, dotPaint);

    canvas.restore();

    // Fixed 12-o-clock indicator
    final indicPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.goldPrimary;
    canvas.drawLine(
      Offset(center.dx, 2),
      Offset(center.dx, 14),
      indicPaint,
    );
  }

  @override
  bool shouldRepaint(_RingDiagramPainter old) => old.rotation != rotation;
}

class _SplitDiagram extends StatelessWidget {
  const _SplitDiagram();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: CustomPaint(painter: const _SplitPainter()),
    );
  }
}

class _SplitPainter extends CustomPainter {
  const _SplitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8;

    // Day half (top) — gold arc
    final dayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..color = AppColors.goldPrimary.withAlpha(200)
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi,
      math.pi,
      false,
      dayPaint,
    );

    // Night half (bottom) — silver arc
    final nightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..color = AppColors.crescentSilver.withAlpha(180)
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      0,
      math.pi,
      false,
      nightPaint,
    );

    // Labels
    _drawLabel(canvas, 'نهار', center.translate(0, -(r + 18)), AppColors.goldPrimary);
    _drawLabel(canvas, 'ليل', center.translate(0, r + 18), AppColors.crescentSilver);
  }

  void _drawLabel(Canvas canvas, String text, Offset pos, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'ArabicDisplay',
          fontSize: 12,
          color: color,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_SplitPainter old) => false;
}
