import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../location/domain/location_model.dart';
import '../../location/presentation/location_provider.dart';
import '../../prayer_engine/domain/prayer.dart';
import '../domain/settings_model.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.goldPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'الإعدادات',
          style: AppTheme.darkTheme.textTheme.headlineSmall?.copyWith(
            color: AppColors.goldPrimary,
            fontFamily: 'ArabicDisplay',
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.goldDark.withOpacity(0.3)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(title: 'الموقع', subtitle: 'Location'),
          _LocationSection(settings: settings),
          _SectionHeader(title: 'مواقيت الصلاة', subtitle: 'Prayer Calculation'),
          _PrayerSection(settings: settings),
          _SectionHeader(title: 'العرض', subtitle: 'Display'),
          _DisplaySection(settings: settings),
          _SectionHeader(title: 'إمكانية الوصول', subtitle: 'Accessibility'),
          _AccessibilitySection(settings: settings),
          _SectionHeader(title: 'حول التطبيق', subtitle: 'About'),
          const _AboutSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Container(width: 3, height: 18, color: AppColors.goldPrimary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.goldPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'ArabicDisplay',
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.goldPrimary.withOpacity(0.6),
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Settings card container ────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.backgroundMid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldDark.withOpacity(0.2)),
      ),
      child: Column(children: children),
    );
  }
}

// ── Row types ─────────────────────────────────────────────────────────────────

class _SwitchRow extends ConsumerWidget {
  const _SwitchRow({
    required this.arabicLabel,
    required this.englishLabel,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String arabicLabel;
  final String englishLabel;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(icon, color: AppColors.goldPrimary, size: 22),
      title: Text(
        arabicLabel,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'ArabicDisplay',
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        englishLabel,
        style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.goldPrimary,
        activeTrackColor: AppColors.goldDark.withOpacity(0.4),
        inactiveThumbColor: Colors.grey.shade600,
        inactiveTrackColor: Colors.grey.shade800,
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  const _TapRow({
    required this.arabicLabel,
    required this.englishLabel,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String arabicLabel;
  final String englishLabel;
  final IconData icon;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.goldPrimary, size: 22),
      title: Text(
        arabicLabel,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'ArabicDisplay',
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        englishLabel,
        style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(color: AppColors.goldPrimary, fontSize: 13),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: AppColors.goldDark.withOpacity(0.7)),
        ],
      ),
      onTap: onTap,
    );
  }
}

// ── Divider ────────────────────────────────────────────────────────────────────

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        indent: 52,
        color: AppColors.goldDark.withOpacity(0.15),
      );
}

// ── Location section ──────────────────────────────────────────────────────────

class _LocationSection extends ConsumerWidget {
  const _LocationSection({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationProvider);
    final cityLabel = locationState.city ?? 'غير محدد';

    return _SettingsCard(
      children: [
        _TapRow(
          arabicLabel: 'الموقع الحالي',
          englishLabel: 'Current Location',
          icon: Icons.location_on_outlined,
          value: cityLabel,
          onTap: () => ref.read(locationProvider.notifier).refreshGPS(),
        ),
        const _RowDivider(),
        _TapRow(
          arabicLabel: 'اختيار موقع يدوي',
          englishLabel: 'Select Manual Location',
          icon: Icons.map_outlined,
          value: '',
          onTap: () => _showLocationPicker(context, ref),
        ),
      ],
    );
  }

  void _showLocationPicker(BuildContext context, WidgetRef ref) {
    final presets = ref.read(presetLocationsProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LocationPickerSheet(presets: presets, ref: ref),
    );
  }
}

class _LocationPickerSheet extends StatelessWidget {
  const _LocationPickerSheet({required this.presets, required this.ref});
  final List<PresetLocation> presets;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'اختر موقعاً',
            style: const TextStyle(
              color: AppColors.goldPrimary,
              fontSize: 18,
              fontFamily: 'ArabicDisplay',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Divider(color: AppColors.goldDark.withOpacity(0.3), height: 1),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: presets.length,
            separatorBuilder: (_, __) =>
                Divider(color: AppColors.goldDark.withOpacity(0.15), height: 1, indent: 16),
            itemBuilder: (_, i) {
              final p = presets[i];
              return ListTile(
                title: Text(
                  p.nameArabic,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'ArabicDisplay',
                  ),
                ),
                subtitle: Text(
                  p.nameEnglish,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.goldDark),
                onTap: () {
                  ref.read(locationProvider.notifier).setPresetLocation(p);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Prayer section ─────────────────────────────────────────────────────────────

class _PrayerSection extends ConsumerWidget {
  const _PrayerSection({required this.settings});
  final AppSettings settings;

  static const _methodLabels = {
    CalculationMethod.ummAlQura: 'أم القرى',
    CalculationMethod.muslimWorldLeague: 'رابطة العالم الإسلامي',
    CalculationMethod.qatar: 'قطر',
    CalculationMethod.egyptian: 'الهيئة المصرية',
    CalculationMethod.karachi: 'كراتشي',
  };

  static const _methodEnglish = {
    CalculationMethod.ummAlQura: 'Umm Al-Qura, Makkah',
    CalculationMethod.muslimWorldLeague: 'Muslim World League',
    CalculationMethod.qatar: 'Qatar',
    CalculationMethod.egyptian: 'Egyptian General Authority',
    CalculationMethod.karachi: 'University of Karachi',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsProvider.notifier);

    return _SettingsCard(
      children: [
        _TapRow(
          arabicLabel: 'طريقة الحساب',
          englishLabel: 'Calculation Method',
          icon: Icons.calculate_outlined,
          value: _methodLabels[settings.prayerMethod] ?? '',
          onTap: () => _showMethodPicker(context, notifier),
        ),
        const _RowDivider(),
        _TapRow(
          arabicLabel: 'حساب العصر',
          englishLabel: 'Asr Calculation',
          icon: Icons.access_time_outlined,
          value: settings.asrMethod == AsrMethod.standard ? 'الجمهور' : 'حنفي',
          onTap: () => notifier.setAsrMethod(
            settings.asrMethod == AsrMethod.standard
                ? AsrMethod.hanafi
                : AsrMethod.standard,
          ),
        ),
      ],
    );
  }

  void _showMethodPicker(BuildContext context, SettingsNotifier notifier) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'طريقة الحساب',
              style: const TextStyle(
                color: AppColors.goldPrimary,
                fontSize: 18,
                fontFamily: 'ArabicDisplay',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Divider(color: AppColors.goldDark.withOpacity(0.3), height: 1),
          ...CalculationMethod.values.map((m) => ListTile(
                title: Text(
                  _methodLabels[m] ?? m.name,
                  style: const TextStyle(color: Colors.white, fontFamily: 'ArabicDisplay'),
                ),
                subtitle: Text(
                  _methodEnglish[m] ?? '',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
                trailing: settings.prayerMethod == m
                    ? const Icon(Icons.check, color: AppColors.goldPrimary)
                    : null,
                onTap: () {
                  notifier.setPrayerMethod(m);
                  Navigator.of(context).pop();
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Display section ────────────────────────────────────────────────────────────

class _DisplaySection extends ConsumerWidget {
  const _DisplaySection({required this.settings});
  final AppSettings settings;

  static const _modeLabels = {
    WatchMode.hybrid: 'هجين',
    WatchMode.fullArabic: 'عربي كامل',
    WatchMode.astronomical: 'فلكي',
    WatchMode.minimal: 'بسيط',
  };

  static const _modeEnglish = {
    WatchMode.hybrid: 'Analog + Arabic ring',
    WatchMode.fullArabic: 'Arabic ring only',
    WatchMode.astronomical: 'Sky emphasis',
    WatchMode.minimal: 'Clean minimal',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsProvider.notifier);

    return _SettingsCard(
      children: [
        _TapRow(
          arabicLabel: 'وضع الساعة',
          englishLabel: 'Watch Mode',
          icon: Icons.watch_outlined,
          value: _modeLabels[settings.watchMode] ?? '',
          onTap: () => _showModePicker(context, notifier),
        ),
        const _RowDivider(),
        _SwitchRow(
          arabicLabel: 'عقرب الثواني',
          englishLabel: 'Show Seconds Hand',
          icon: Icons.timer_outlined,
          value: settings.showSeconds,
          onChanged: notifier.setShowSeconds,
        ),
        const _RowDivider(),
        _SwitchRow(
          arabicLabel: 'الوقت ٢٤ ساعة',
          englishLabel: '24-Hour Time',
          icon: Icons.access_time,
          value: settings.use24Hour,
          onChanged: notifier.setUse24Hour,
        ),
        const _RowDivider(),
        _SwitchRow(
          arabicLabel: 'النقحرة اللاتينية',
          englishLabel: 'Show Transliteration',
          icon: Icons.translate_outlined,
          value: settings.showTransliteration,
          onChanged: notifier.setShowTransliteration,
        ),
        const _RowDivider(),
        _SwitchRow(
          arabicLabel: 'خرز الدقائق',
          englishLabel: 'Minute Beads',
          icon: Icons.circle_outlined,
          value: settings.showMinuteBeads,
          onChanged: notifier.setShowMinuteBeads,
        ),
        const _RowDivider(),
        _SwitchRow(
          arabicLabel: 'قوس الصلاة',
          englishLabel: 'Prayer Arc',
          icon: Icons.arc_outlined_sharp,
          value: settings.showPrayerArc,
          onChanged: notifier.setShowPrayerArc,
        ),
      ],
    );
  }

  void _showModePicker(BuildContext context, SettingsNotifier notifier) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'وضع الساعة',
              style: const TextStyle(
                color: AppColors.goldPrimary,
                fontSize: 18,
                fontFamily: 'ArabicDisplay',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Divider(color: AppColors.goldDark.withOpacity(0.3), height: 1),
          ...WatchMode.values.map((m) => ListTile(
                leading: _modeIcon(m),
                title: Text(
                  _modeLabels[m] ?? m.name,
                  style: const TextStyle(color: Colors.white, fontFamily: 'ArabicDisplay'),
                ),
                subtitle: Text(
                  _modeEnglish[m] ?? '',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
                trailing: settings.watchMode == m
                    ? const Icon(Icons.check, color: AppColors.goldPrimary)
                    : null,
                onTap: () {
                  notifier.setWatchMode(m);
                  Navigator.of(context).pop();
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _modeIcon(WatchMode m) {
    const icons = {
      WatchMode.hybrid: Icons.watch,
      WatchMode.fullArabic: Icons.language,
      WatchMode.astronomical: Icons.nights_stay_outlined,
      WatchMode.minimal: Icons.radio_button_unchecked,
    };
    return Icon(icons[m] ?? Icons.watch, color: AppColors.goldPrimary, size: 22);
  }
}

// ── Accessibility section ─────────────────────────────────────────────────────

class _AccessibilitySection extends ConsumerWidget {
  const _AccessibilitySection({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsProvider.notifier);
    return _SettingsCard(
      children: [
        _SwitchRow(
          arabicLabel: 'إبقاء الشاشة مضاءة',
          englishLabel: 'Keep Screen On',
          icon: Icons.screen_lock_portrait_outlined,
          value: settings.keepScreenOn,
          onChanged: notifier.setKeepScreenOn,
        ),
        const _RowDivider(),
        _SwitchRow(
          arabicLabel: 'الاهتزاز عند الأذان',
          englishLabel: 'Vibrate at Prayer Time',
          icon: Icons.vibration,
          value: settings.enableVibration,
          onChanged: notifier.setEnableVibration,
        ),
      ],
    );
  }
}

// ── About section ─────────────────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline, color: AppColors.goldPrimary, size: 22),
          title: const Text(
            'الساعة العربية الذكية',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'ArabicDisplay',
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            'Arabic Temporal Watch  •  v1.0.0',
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
          ),
        ),
        const _RowDivider(),
        ListTile(
          leading: const Icon(Icons.star_border_outlined, color: AppColors.goldPrimary, size: 22),
          title: const Text(
            'مستوحى من علم الفلك العربي الكلاسيكي',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'ArabicDisplay',
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            'Inspired by classical Arabic astronomical timekeeping',
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
extension on IconData {
  // Alias so we can use Icons.arc_outlined_sharp cleanly (doesn't exist in all SDK versions)
  static IconData get arc => Icons.architecture;
}

extension on Icons {
  static IconData get arc_outlined_sharp => Icons.architecture;
}
