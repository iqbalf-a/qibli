import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants/theme.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/animated_sheet.dart';
import '../widgets/location_picker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showLocationPicker = false;
  bool _showMethodModal    = false;
  bool _showMadhabModal    = false;
  bool _showAdhanModal     = false;

  String? _previewingAdhanKey;
  final AudioPlayer _previewPlayer = AudioPlayer();

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  void _stopPreview() {
    _previewPlayer.stop();
    if (mounted) setState(() => _previewingAdhanKey = null);
  }

  Future<void> _togglePreview(String soundKey, String assetPath) async {
    if (_previewingAdhanKey == soundKey) {
      _stopPreview();
      return;
    }
    _stopPreview();
    await _previewPlayer.play(AssetSource(assetPath));
    if (mounted) setState(() => _previewingAdhanKey = soundKey);
    _previewPlayer.onPlayerComplete.first.then((_) {
      if (mounted) setState(() => _previewingAdhanKey = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final settings      = context.watch<SettingsProvider>();
    final appTheme      = themeProvider.theme;

    final methodLabel = calculationMethods
        .firstWhere((entry) => entry['key'] == settings.calculationMethod,
            orElse: () => calculationMethods.first)['label']!;
    final madhabLabel = madhabs
        .firstWhere((entry) => entry['key'] == settings.madhab,
            orElse: () => madhabs.first)['shortLabel']!;
    final adhanLabel = adhanSounds
        .firstWhere((entry) => entry['key'] == settings.adhanSound,
            orElse: () => adhanSounds.first)['label']!;

    return Scaffold(
      backgroundColor: appTheme.bg0,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    child: Text(
                      'Settings',
                      style: GoogleFonts.inter(
                          fontSize: 20, fontWeight: FontWeight.w700, color: appTheme.text),
                    ),
                  ),

                  // Location card
                  _buildLocationCard(appTheme, settings),

                  // Worship section
                  _SectionLabel(label: 'WORSHIP', appTheme: appTheme),
                  _buildWorshipCard(appTheme, settings, methodLabel, madhabLabel, adhanLabel),

                  // Theme section
                  _SectionLabel(label: 'THEME', appTheme: appTheme),
                  _buildThemeCard(appTheme, themeProvider),

                  // About section
                  _SectionLabel(label: 'ABOUT', appTheme: appTheme),
                  _buildAboutCard(appTheme),

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),

            // Modals rendered on top
            if (_showLocationPicker)
              LocationPicker(
                appTheme: appTheme,
                onSelect: (location) {
                  settings.updateManualLocation(location);
                  setState(() => _showLocationPicker = false);
                },
                onDismiss: () => setState(() => _showLocationPicker = false),
              ),

            if (_showMethodModal)
              AnimatedSheet(
                onDismiss: () => setState(() => _showMethodModal = false),
                builder: (close) => _PickerModal(
                  title: 'Calculation Method',
                  options: calculationMethods.map((entry) =>
                      _PickerOption(key: entry['key']!, label: entry['label']!)).toList(),
                  selectedKey: settings.calculationMethod,
                  appTheme: appTheme,
                  onSelect: (key) {
                    settings.updateCalculationMethod(key);
                    close();
                  },
                  onDismiss: close,
                ),
              ),

            if (_showMadhabModal)
              AnimatedSheet(
                onDismiss: () => setState(() => _showMadhabModal = false),
                builder: (close) => _PickerModal(
                  title: 'Madhab (Asr)',
                  options: madhabs.map((entry) =>
                      _PickerOption(key: entry['key']!, label: entry['label']!)).toList(),
                  selectedKey: settings.madhab,
                  appTheme: appTheme,
                  onSelect: (key) {
                    settings.updateMadhab(key);
                    close();
                  },
                  onDismiss: close,
                ),
              ),

            if (_showAdhanModal)
              AnimatedSheet(
                onDismiss: () {
                  _stopPreview();
                  setState(() => _showAdhanModal = false);
                },
                builder: (close) => _AdhanPickerModal(
                  appTheme: appTheme,
                  selectedKey: settings.adhanSound,
                  previewingKey: _previewingAdhanKey,
                  onSelect: (key) {
                    settings.updateAdhanSound(key);
                    _stopPreview();
                    close();
                  },
                  onTogglePreview: _togglePreview,
                  onDismiss: close,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Location card ────────────────────────────────────────────────────────

  Widget _buildLocationCard(AppTheme appTheme, SettingsProvider settings) {
    final hasManual = settings.manualLocation != null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: appTheme.bg1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appTheme.line),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: appTheme.rowIconBg, borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasManual ? Icons.location_on : Icons.near_me_outlined,
              size: 20, color: appTheme.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasManual ? 'MANUAL LOCATION' : 'GPS LOCATION',
                  style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w500,
                    color: appTheme.textMute, letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasManual
                      ? '${settings.manualLocation!.city}, ${settings.manualLocation!.country}'
                      : 'Using device GPS',
                  style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700, color: appTheme.text,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => setState(() => _showLocationPicker = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: appTheme.accent),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'CHANGE',
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w500,
                      color: appTheme.accent, letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              if (hasManual) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => context.read<SettingsProvider>().updateManualLocation(null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: appTheme.accent),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'USE GPS',
                      style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w500,
                        color: appTheme.accent, letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ─── Worship card ─────────────────────────────────────────────────────────

  Widget _buildWorshipCard(
    AppTheme appTheme,
    SettingsProvider settings,
    String methodLabel,
    String madhabLabel,
    String adhanLabel,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: appTheme.bg1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appTheme.line),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showMethodModal = true),
            child: _SettingRow(
              icon: Icons.list_alt_outlined,
              label: 'Calculation Method',
              trailingValue: methodLabel,
              showChevron: true,
              appTheme: appTheme,
            ),
          ),
          Divider(height: 1, color: appTheme.line, indent: 16, endIndent: 16),
          GestureDetector(
            onTap: () => setState(() => _showMadhabModal = true),
            child: _SettingRow(
              icon: Icons.nightlight_outlined,
              label: 'Madhab (Asr)',
              trailingValue: madhabLabel,
              showChevron: true,
              appTheme: appTheme,
            ),
          ),
          Divider(height: 1, color: appTheme.line, indent: 16, endIndent: 16),
          GestureDetector(
            onTap: () => setState(() => _showAdhanModal = true),
            child: _SettingRow(
              icon: Icons.notifications_outlined,
              label: 'Adhan Sound',
              trailingValue: adhanLabel,
              showChevron: true,
              appTheme: appTheme,
            ),
          ),
          Divider(height: 1, color: appTheme.line, indent: 16, endIndent: 16),
          _SettingRow(
            icon: Icons.alarm_outlined,
            label: 'Prayer Notifications',
            appTheme: appTheme,
            trailingWidget: Switch(
              value: settings.notificationsEnabled,
              onChanged: settings.updateNotificationsEnabled,
              trackColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? appTheme.accent.withValues(alpha: 0.4)
                    : appTheme.bg3,
              ),
              thumbColor: WidgetStateProperty.all(Colors.white),
            ),
          ),
          Divider(height: 1, color: appTheme.line, indent: 16, endIndent: 16),
          _SettingRow(
            icon: Icons.calendar_today_outlined,
            label: 'Hijri Adjustment',
            appTheme: appTheme,
            trailingWidget: _HijriOffsetControl(appTheme: appTheme, settings: settings),
          ),
        ],
      ),
    );
  }

  // ─── Theme card ───────────────────────────────────────────────────────────

  Widget _buildThemeCard(AppTheme appTheme, ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: appTheme.bg1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appTheme.line),
      ),
      child: Column(
        children: [
          _ThemeSection(
            label: 'DARK',
            themeKeys: darkThemeKeys,
            selectedKey: themeProvider.themeKey,
            appTheme: appTheme,
            onSelect: themeProvider.setThemeKey,
            showTopBorder: false,
          ),
          _ThemeSection(
            label: 'LIGHT',
            themeKeys: lightThemeKeys,
            selectedKey: themeProvider.themeKey,
            appTheme: appTheme,
            onSelect: themeProvider.setThemeKey,
            showTopBorder: true,
          ),
        ],
      ),
    );
  }

  // ─── About card ───────────────────────────────────────────────────────────

  Widget _buildAboutCard(AppTheme appTheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: appTheme.bg1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appTheme.line),
      ),
      child: Column(
        children: [
          _SettingRow(
            icon: Icons.info_outline,
            label: 'Version',
            trailingValue: '1.0.0',
            appTheme: appTheme,
          ),
          Divider(height: 1, color: appTheme.line, indent: 16, endIndent: 16),
          _SettingRow(
            icon: Icons.description_outlined,
            label: 'Privacy Policy',
            showChevron: true,
            appTheme: appTheme,
          ),
          Divider(height: 1, color: appTheme.line, indent: 16, endIndent: 16),
          _SettingRow(
            icon: Icons.favorite_border,
            label: 'Acknowledgements',
            showChevron: true,
            appTheme: appTheme,
          ),
        ],
      ),
    );
  }
}

// ─── Reusable sub-widgets ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final AppTheme appTheme;
  const _SectionLabel({required this.label, required this.appTheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w500,
          color: appTheme.textMute, letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailingValue;
  final bool showChevron;
  final Widget? trailingWidget;
  final AppTheme appTheme;

  const _SettingRow({
    required this.icon,
    required this.label,
    required this.appTheme,
    this.trailingValue,
    this.showChevron = false,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: appTheme.rowIconBg, borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: appTheme.textDim),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500, color: appTheme.text,
              ),
            ),
          ),
          if (trailingWidget != null)
            trailingWidget!
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailingValue != null)
                  Text(
                    trailingValue!,
                    style: GoogleFonts.inter(fontSize: 12, color: appTheme.textMute),
                  ),
                if (showChevron) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 16, color: appTheme.textMute),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _HijriOffsetControl extends StatelessWidget {
  final AppTheme appTheme;
  final SettingsProvider settings;
  const _HijriOffsetControl({required this.appTheme, required this.settings});

  @override
  Widget build(BuildContext context) {
    final offsetLabel = settings.hijriOffset == 0
        ? '0'
        : settings.hijriOffset > 0
            ? '+${settings.hijriOffset}'
            : '${settings.hijriOffset}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => settings.updateHijriOffset(settings.hijriOffset - 1),
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: appTheme.navBtnBg, borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.remove, size: 16, color: appTheme.textDim),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(
            offsetLabel,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w500, color: appTheme.textDim,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => settings.updateHijriOffset(settings.hijriOffset + 1),
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: appTheme.navBtnBg, borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.add, size: 16, color: appTheme.textDim),
          ),
        ),
      ],
    );
  }
}

class _ThemeSection extends StatelessWidget {
  final String label;
  final List<String> themeKeys;
  final String selectedKey;
  final AppTheme appTheme;
  final void Function(String key) onSelect;
  final bool showTopBorder;

  const _ThemeSection({
    required this.label,
    required this.themeKeys,
    required this.selectedKey,
    required this.appTheme,
    required this.onSelect,
    required this.showTopBorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: showTopBorder
          ? BoxDecoration(border: Border(top: BorderSide(color: appTheme.line)))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs, vertical: 4),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w500,
                color: appTheme.textMute, letterSpacing: 1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.9,
              ),
              itemCount: themeKeys.length,
              itemBuilder: (context, index) {
                final themeKey = themeKeys[index];
                final previewTheme = getTheme(themeKey);
                final isActive = themeKey == selectedKey;
                return GestureDetector(
                  onTap: () => onSelect(themeKey),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: previewTheme.bg2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive ? previewTheme.accent : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: previewTheme.swatches.map((swatchColor) => Container(
                                  width: 16, height: 16,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: swatchColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                )).toList(),
                              ),
                            ),
                            if (isActive)
                              Icon(Icons.check, size: 14, color: previewTheme.accent),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          previewTheme.name,
                          style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w500,
                            color: isActive ? previewTheme.accent : previewTheme.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Generic picker modal ─────────────────────────────────────────────────────

class _PickerOption {
  final String key;
  final String label;
  const _PickerOption({required this.key, required this.label});
}

class _PickerModal extends StatelessWidget {
  final String title;
  final List<_PickerOption> options;
  final String selectedKey;
  final AppTheme appTheme;
  final void Function(String key) onSelect;
  final VoidCallback onDismiss;

  const _PickerModal({
    required this.title,
    required this.options,
    required this.selectedKey,
    required this.appTheme,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: appTheme.bg2,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20), topRight: Radius.circular(20),
        ),
        border: Border(top: BorderSide(color: appTheme.line)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700, color: appTheme.text,
              ),
            ),
          ),
          ...options.map((option) {
            final isActive = option.key == selectedKey;
            return GestureDetector(
              onTap: () => onSelect(option.key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? appTheme.bg3 : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      option.label,
                      style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w500,
                        color: isActive ? appTheme.accent : appTheme.text,
                      ),
                    ),
                    if (isActive)
                      Icon(Icons.check, size: 16, color: appTheme.accent),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Adhan picker modal (with preview) ───────────────────────────────────────

class _AdhanPickerModal extends StatelessWidget {
  final AppTheme appTheme;
  final String selectedKey;
  final String? previewingKey;
  final void Function(String key) onSelect;
  final Future<void> Function(String key, String path) onTogglePreview;
  final VoidCallback onDismiss;

  const _AdhanPickerModal({
    required this.appTheme,
    required this.selectedKey,
    required this.previewingKey,
    required this.onSelect,
    required this.onTogglePreview,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: appTheme.bg2,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20), topRight: Radius.circular(20),
        ),
        border: Border(top: BorderSide(color: appTheme.line)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Adhan Sound',
              style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700, color: appTheme.text,
              ),
            ),
          ),
          ...adhanSounds.map((soundEntry) {
            final soundKey     = soundEntry['key']!;
            final soundLabel   = soundEntry['label']!;
            final soundFile    = soundEntry['file']!;
            final isActive     = soundKey == selectedKey;
            final isPreviewing = soundKey == previewingKey;

            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 12),
              decoration: BoxDecoration(
                color: isActive ? appTheme.bg3 : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onSelect(soundKey),
                      child: Text(
                        soundLabel,
                        style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w500,
                          color: isActive ? appTheme.accent : appTheme.text,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onTogglePreview(soundKey, soundFile),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isPreviewing
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_outline,
                        size: 24,
                        color: isPreviewing ? appTheme.accent : appTheme.textMute,
                      ),
                    ),
                  ),
                  if (isActive && !isPreviewing) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.check, size: 16, color: appTheme.accent),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
