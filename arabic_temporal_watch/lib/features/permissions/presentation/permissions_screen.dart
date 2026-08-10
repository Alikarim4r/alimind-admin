// permissions_screen.dart
//
// Shown when location permission is denied or unavailable.
// Provides three clear paths:
//   1. Request permission (first denial — triggers OS dialog).
//   2. Open app settings (permanently denied — OS settings page).
//   3. Use Makkah as default location and continue without GPS.

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../core/constants/app_colors.dart';

// ── PermissionsScreen ─────────────────────────────────────────────────────────

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _loading = false;
  String? _errorMessage;

  Future<void> _requestPermission() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // Check if already permanently denied.
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.deniedForever) {
        // Must go to OS settings.
        setState(() {
          _errorMessage =
              'تم رفض الإذن بشكل دائم. يرجى فتح الإعدادات وتفعيل الموقع يدوياً.';
          _loading = false;
        });
        return;
      }

      // Request via geolocator.
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      } else {
        setState(() {
          _errorMessage = 'لم يتم منح إذن الموقع. يمكنك المتابعة بموقع مكة المكرمة.';
          _loading = false;
        });
      }
    } catch (_) {
      setState(() {
        _errorMessage = 'حدث خطأ أثناء طلب الإذن. حاول مرة أخرى.';
        _loading = false;
      });
    }
  }

  /// Opens the OS settings page for this app.
  ///
  /// `permission_handler` implements Android and iOS only; on macOS and the
  /// other desktop targets the call throws, so surface an instruction the user
  /// can act on instead of failing silently.
  Future<void> _openSettings() async {
    if (!_supportsAppSettings) {
      setState(() {
        _errorMessage = 'افتح إعدادات النظام ← الخصوصية والأمان ← خدمات '
            'الموقع، وفعّل الوصول لهذا التطبيق.';
      });
      return;
    }

    try {
      await ph.openAppSettings();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذّر فتح الإعدادات تلقائياً. افتحها يدوياً وفعّل '
            'إذن الموقع.';
      });
    }
  }

  static bool get _supportsAppSettings =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void _useMakkah() {
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.goldPrimary.withAlpha(15),
                  border: Border.all(
                    color: AppColors.goldPrimary.withAlpha(60),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.goldPrimary,
                  size: 44,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              const Text(
                'إذن الموقع مطلوب',
                style: TextStyle(
                  fontFamily: 'ArabicDisplay',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.goldPrimary,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Explanation
              const Text(
                'تحتاج الساعة العربية إلى موقعك الجغرافي لحساب:\n'
                '• وقت الشروق والغروب بدقة فلكية\n'
                '• أوقات الصلوات الخمس وفق موقعك\n'
                '• الساعات الزمنية العربية المتغيرة بتغير الفصول',
                style: TextStyle(
                  fontFamily: 'ArabicDisplay',
                  fontSize: 15,
                  color: AppColors.silverMid,
                  height: 2.0,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Privacy note
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline,
                        color: AppColors.silverDim, size: 14),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'موقعك يُستخدم محلياً فقط — لا يُرسَل لأي خادم خارجي.',
                        style: TextStyle(
                          fontFamily: 'ArabicDisplay',
                          fontSize: 12,
                          color: AppColors.silverDim,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A0010),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFD4364A).withAlpha(60)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontFamily: 'ArabicDisplay',
                      fontSize: 13,
                      color: Color(0xFFFF6B8A),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Primary button — request permission
              if (_loading)
                const CircularProgressIndicator(
                  color: AppColors.goldPrimary,
                  strokeWidth: 2,
                )
              else
                _PrimaryButton(
                  label: 'السماح بالوصول إلى الموقع',
                  icon: Icons.location_on_outlined,
                  onTap: _requestPermission,
                ),

              const SizedBox(height: 14),

              // Open settings (if permanently denied)
              _SecondaryButton(
                label: 'فتح إعدادات التطبيق',
                icon: Icons.settings_outlined,
                onTap: _openSettings,
              ),

              const Spacer(),

              // Skip — use Makkah default
              GestureDetector(
                onTap: _useMakkah,
                child: Column(
                  children: [
                    const Text(
                      'المتابعة بموقع مكة المكرمة',
                      style: TextStyle(
                        fontFamily: 'ArabicDisplay',
                        fontSize: 13,
                        color: AppColors.silverDim,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.silverDim,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '٢١.٣٩°ش، ٣٩.٨٦°ش',
                      style: TextStyle(
                        fontFamily: 'ArabicDisplay',
                        fontSize: 10,
                        color: AppColors.silverDeep,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared buttons ─────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.goldDark, AppColors.goldPrimary, AppColors.goldLight],
            stops: [0.0, 0.55, 1.0],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.goldPrimary.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.backgroundDeep, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'ArabicDisplay',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.backgroundDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.backgroundSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.silverMid, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'ArabicDisplay',
                fontSize: 15,
                color: AppColors.silverMid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
