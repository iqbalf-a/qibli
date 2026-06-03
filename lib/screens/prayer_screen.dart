import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants/theme.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/hijri_utils.dart';
import '../utils/prayer_utils.dart';
import '../widgets/animated_sheet.dart';

// ─── Prayer list definition ───────────────────────────────────────────────────

class _PrayerEntry {
  final String key;
  final String name;
  final IconData icon;
  final bool noAlert;
  const _PrayerEntry({
    required this.key,
    required this.name,
    required this.icon,
    this.noAlert = false,
  });
}

const List<_PrayerEntry> _prayerEntries = [
  _PrayerEntry(key: 'imsak',   name: 'Imsak',   icon: Icons.access_time_outlined,       noAlert: true),
  _PrayerEntry(key: 'fajr',    name: 'Fajr',    icon: Icons.nightlight_outlined),
  _PrayerEntry(key: 'sunrise', name: 'Sunrise', icon: Icons.wb_sunny_outlined,           noAlert: true),
  _PrayerEntry(key: 'dhuhr',   name: 'Dhuhr',   icon: Icons.wb_sunny_outlined),
  _PrayerEntry(key: 'asr',     name: 'Asr',     icon: Icons.cloud_outlined),
  _PrayerEntry(key: 'maghrib', name: 'Maghrib', icon: Icons.wb_twilight_outlined),
  _PrayerEntry(key: 'isha',    name: 'Isha',    icon: Icons.nightlight_round_outlined),
];

const List<Map<String, dynamic>> _bellOptions = [
  {'value': 'off',   'label': 'Off',          'desc': 'No notification',    'icon': Icons.notifications_off_outlined},
  {'value': 'notif', 'label': 'Notification', 'desc': 'Silent alert only',  'icon': Icons.notifications_outlined},
  {'value': 'adhan', 'label': 'Adhan',        'desc': 'Alert + adhan sound','icon': Icons.volume_up_outlined},
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _formatTime(DateTime? dateTime) {
  if (dateTime == null) return '--:--';
  final hour   = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatCountdown(Duration duration) {
  if (duration.isNegative) return '00:00:00';
  final hours   = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String _formatGregorianShort(DateTime date) {
  const monthLabels = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${monthLabels[date.month]} ${date.year}';
}

String _weekdayName(int weekday) {
  const names = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return names[weekday];
}

const _monthFullNames = ['', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'];

// ─── Screen ───────────────────────────────────────────────────────────────────

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  double? _latitude;
  double? _longitude;
  String _cityName = 'Locating...';
  PrayerData? _selectedDayPrayerData;
  PrayerData? _todayPrayerData;
  DateTime _now = DateTime.now();
  late DateTime _selectedDate;
  String? _openBellModalKey;
  bool _isRefreshing = false;
  bool _isAdhanPlaying = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _clockTimer;
  Timer? _adhanStopTimer;

  static DateTime _todayMidnight() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isViewingToday {
    final today = _todayMidnight();
    return _selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day;
  }

  int get _dayOffset => _selectedDate.difference(_todayMidnight()).inDays;

  @override
  void initState() {
    super.initState();
    _selectedDate = _todayMidnight();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _fetchLocation();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _adhanStopTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ─── Location & prayer time loading ──────────────────────────────────────

  Future<void> _fetchLocation() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);

    final settings = context.read<SettingsProvider>();
    if (settings.manualLocation != null) {
      final loc = settings.manualLocation!;
      if (mounted) {
        setState(() {
          _latitude = loc.lat;
          _longitude = loc.lng;
          _cityName = '${loc.city}, ${loc.country}';
          _isRefreshing = false;
        });
        _rebuildPrayerTimes();
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) setState(() { _cityName = 'Set location in Settings'; _isRefreshing = false; });
      return;
    }

    try {
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = position!.latitude;
        _longitude = position.longitude;
      });
      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;
          final area = (place.subAdministrativeArea?.isNotEmpty == true)
              ? place.subAdministrativeArea!
              : (place.locality?.isNotEmpty == true)
                  ? place.locality!
                  : place.administrativeArea ?? '';
          final countryCode = place.isoCountryCode ?? place.country ?? '';
          setState(() => _cityName = '$area, $countryCode');
        }
      } catch (_) {
        if (mounted) {
          setState(() => _cityName =
              '${position!.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}');
        }
      }
      _rebuildPrayerTimes();
    } catch (_) {
      if (mounted) setState(() => _cityName = 'Enable location services');
    }
    if (mounted) setState(() => _isRefreshing = false);
  }

  void _rebuildPrayerTimes() {
    if (_latitude == null || _longitude == null || !mounted) return;
    final settings = context.read<SettingsProvider>();
    final today = DateTime.now();
    setState(() {
      _selectedDayPrayerData = buildPrayerTimes(
        latitude: _latitude!,
        longitude: _longitude!,
        date: _selectedDate,
        calculationMethod: settings.calculationMethod,
        madhab: settings.madhab,
      );
      _todayPrayerData = buildPrayerTimes(
        latitude: _latitude!,
        longitude: _longitude!,
        date: today,
        calculationMethod: settings.calculationMethod,
        madhab: settings.madhab,
      );
    });
  }

  void _goToPreviousDay() {
    if (_dayOffset <= -7) return;
    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
    _rebuildPrayerTimes();
  }

  void _goToNextDay() {
    if (_dayOffset >= 7) return;
    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
    _rebuildPrayerTimes();
  }

  void _goToToday() {
    setState(() => _selectedDate = _todayMidnight());
    _rebuildPrayerTimes();
  }

  // ─── Adhan playback ───────────────────────────────────────────────────────

  void _stopAdhan() {
    _adhanStopTimer?.cancel();
    _audioPlayer.stop();
    if (mounted) setState(() => _isAdhanPlaying = false);
  }

  // ignore: unused_element
  Future<void> _playAdhan(String soundKey) async {
    _stopAdhan();
    final soundEntry = adhanSounds.firstWhere(
      (entry) => entry['key'] == soundKey,
      orElse: () => adhanSounds.first,
    );
    await _audioPlayer.play(AssetSource(soundEntry['file']!));
    if (mounted) setState(() => _isAdhanPlaying = true);
    _adhanStopTimer = Timer(const Duration(minutes: 5), _stopAdhan);
    _audioPlayer.onPlayerComplete.first.then((_) => _stopAdhan());
  }

  // ─── Next prayer calculation ──────────────────────────────────────────────

  ({_PrayerEntry? entry, DateTime? time}) _getNextPrayer() {
    final todayData = _todayPrayerData;
    if (todayData == null) return (entry: null, time: null);
    for (final prayerEntry in _prayerEntries) {
      if (prayerEntry.noAlert) continue;
      final prayerTime = getPrayerTime(todayData, prayerEntry.key);
      if (prayerTime != null && prayerTime.isAfter(_now)) {
        return (entry: prayerEntry, time: prayerTime);
      }
    }
    if (_latitude != null && _longitude != null) {
      final settings = context.read<SettingsProvider>();
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowData = buildPrayerTimes(
        latitude: _latitude!,
        longitude: _longitude!,
        date: tomorrow,
        calculationMethod: settings.calculationMethod,
        madhab: settings.madhab,
      );
      return (entry: _prayerEntries[1], time: tomorrowData.fajr);
    }
    return (entry: null, time: null);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<ThemeProvider>().theme;
    final settings = context.watch<SettingsProvider>();

    // Sync manual location changes reactively
    final manualLoc = settings.manualLocation;
    if (manualLoc != null &&
        (_latitude != manualLoc.lat || _longitude != manualLoc.lng)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _latitude = manualLoc.lat;
          _longitude = manualLoc.lng;
          _cityName = '${manualLoc.city}, ${manualLoc.country}';
        });
        _rebuildPrayerTimes();
      });
    }

    final nextPrayer = _getNextPrayer();
    final countdown = nextPrayer.time != null
        ? nextPrayer.time!.difference(_now)
        : Duration.zero;
    final currentWindowLabel = _isViewingToday
        ? getCurrentPrayerWindow(_todayPrayerData, _now)
        : null;

    return Scaffold(
      backgroundColor: appTheme.bg1,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(appTheme),
                _buildHeroCard(appTheme, nextPrayer.entry, nextPrayer.time, countdown, settings.hijriOffset),
                _buildDateNav(appTheme, settings.hijriOffset),
                if (currentWindowLabel != null) ...[
                  const SizedBox(height: 4),
                  _buildWindowBadge(appTheme, currentWindowLabel),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (_isAdhanPlaying) _buildAdhanBanner(appTheme),
                Expanded(child: _buildPrayerList(appTheme, settings, nextPrayer.entry)),
              ],
            ),
            if (_openBellModalKey != null)
              AnimatedSheet(
                key: ValueKey(_openBellModalKey),
                onDismiss: () => setState(() => _openBellModalKey = null),
                builder: (close) => _BellModal(
                  prayerKey: _openBellModalKey!,
                  prayerName: _prayerEntries.firstWhere((e) => e.key == _openBellModalKey).name,
                  currentValue: settings.bellState[_openBellModalKey!] ?? 'notif',
                  appTheme: appTheme,
                  onSelect: (value) {
                    settings.updateBell(_openBellModalKey!, value);
                    close();
                  },
                  onDismiss: close,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Sub-widgets ──────────────────────────────────────────────────────────

  Widget _buildHeader(AppTheme appTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Prayer Times',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: appTheme.text),
          ),
          Row(
            children: [
              _isRefreshing
                  ? SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: appTheme.textMute),
                    )
                  : Icon(Icons.location_on_outlined, size: 13, color: appTheme.textMute),
              const SizedBox(width: 4),
              Text(
                _cityName.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w500,
                  color: appTheme.textMute, letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 2),
              GestureDetector(
                onTap: _isRefreshing ? null : _fetchLocation,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.refresh,
                    size: 14,
                    color: _isRefreshing ? appTheme.bg3 : appTheme.textMute,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(
    AppTheme appTheme,
    _PrayerEntry? nextEntry,
    DateTime? nextTime,
    Duration countdown,
    int hijriOffset,
  ) {
    final clockLabel = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: appTheme.cardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: appTheme.shadow.withValues(alpha: appTheme.cardShadowOpacity),
            blurRadius: appTheme.cardShadowRadius,
            offset: Offset(0, appTheme.cardShadowOffsetY),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                clockLabel,
                style: GoogleFonts.inter(
                  fontSize: 44, fontWeight: FontWeight.w300,
                  color: appTheme.text, height: 1.1,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatGregorianShort(_now),
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: appTheme.textDim, letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatHijriDate(_now, offset: hijriOffset),
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: appTheme.textMute, letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'NEXT PRAYER',
            style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w500,
              color: appTheme.accent, letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                nextEntry?.name ?? '--',
                style: GoogleFonts.nunito(
                  fontSize: 28, fontWeight: FontWeight.w600, color: appTheme.text,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'UNTIL',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: appTheme.accent, letterSpacing: 1,
                    ),
                  ),
                  Text(
                    _formatCountdown(countdown),
                    style: GoogleFonts.nunito(
                      fontSize: 28, fontWeight: FontWeight.w600, color: appTheme.text,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateNav(AppTheme appTheme, int hijriOffset) {
    final dateLabel = _isViewingToday
        ? 'Today · ${_weekdayName(_selectedDate.weekday)}, ${_selectedDate.day} ${_monthFullNames[_selectedDate.month]}'
        : '${_weekdayName(_selectedDate.weekday)}, ${_selectedDate.day} ${_monthFullNames[_selectedDate.month]}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _goToPreviousDay,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.chevron_left,
                size: 18,
                color: _dayOffset <= -7 ? appTheme.bg3 : appTheme.textMute,
              ),
            ),
          ),
          Column(
            children: [
              Text(
                dateLabel,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: appTheme.text),
              ),
              const SizedBox(height: 2),
              Text(
                formatHijriDate(_selectedDate, offset: hijriOffset),
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: appTheme.textMute),
              ),
              if (!_isViewingToday) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _goToToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: appTheme.accent),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Back to Today',
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w500,
                        color: appTheme.accent, letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          GestureDetector(
            onTap: _goToNextDay,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: _dayOffset >= 7 ? appTheme.bg3 : appTheme.textMute,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowBadge(AppTheme appTheme, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: appTheme.accent, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 6),
          Text(
            '$label time',
            style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w500,
              color: appTheme.accent, letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdhanBanner(AppTheme appTheme) {
    return GestureDetector(
      onTap: _stopAdhan,
      child: Container(
        margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
        decoration: BoxDecoration(
          color: appTheme.rowActiveBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: appTheme.accentGlow),
        ),
        child: Row(
          children: [
            Icon(Icons.volume_up, size: 16, color: appTheme.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Adhan playing — tap to stop',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: appTheme.accent),
              ),
            ),
            Icon(Icons.close, size: 16, color: appTheme.textMute),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerList(
    AppTheme appTheme,
    SettingsProvider settings,
    _PrayerEntry? nextEntry,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: _prayerEntries.length,
      itemBuilder: (context, index) {
        final prayerEntry = _prayerEntries[index];
        final prayerTime = getPrayerTime(_selectedDayPrayerData, prayerEntry.key);
        final isPassed = _isViewingToday && prayerTime != null && prayerTime.isBefore(_now);
        final isNext = _isViewingToday && nextEntry?.key == prayerEntry.key;
        final currentBell = settings.bellState[prayerEntry.key] ?? (prayerEntry.noAlert ? 'off' : 'notif');

        final IconData bellIcon;
        final Color bellColor;
        if (currentBell == 'adhan') {
          bellIcon = Icons.volume_up_outlined;
          bellColor = appTheme.accent;
        } else if (currentBell == 'off') {
          bellIcon = Icons.notifications_off_outlined;
          bellColor = isNext ? appTheme.textMute : appTheme.lineStrong;
        } else {
          bellIcon = Icons.notifications_outlined;
          bellColor = isNext ? appTheme.accent : appTheme.textMute;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: isNext ? appTheme.rowActiveBg : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              if (isNext)
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: appTheme.accent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Icon(
                        prayerEntry.icon,
                        size: 18,
                        color: isNext ? appTheme.accent : appTheme.textMute,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        prayerEntry.name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isPassed
                              ? appTheme.textMute
                              : isNext
                                  ? appTheme.text
                                  : prayerEntry.noAlert
                                      ? appTheme.textMute
                                      : appTheme.textDim,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.md),
                      child: Text(
                        _formatTime(prayerTime),
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isPassed
                              ? appTheme.textMute
                              : isNext
                                  ? appTheme.accentSoft
                                  : appTheme.textMute,
                        ),
                      ),
                    ),
                    if (!prayerEntry.noAlert)
                      GestureDetector(
                        onTap: () => setState(() => _openBellModalKey = prayerEntry.key),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(bellIcon, size: 16, color: bellColor),
                        ),
                      )
                    else
                      const SizedBox(width: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Bell bottom sheet modal ──────────────────────────────────────────────────

class _BellModal extends StatelessWidget {
  final String prayerKey;
  final String prayerName;
  final String currentValue;
  final AppTheme appTheme;
  final void Function(String value) onSelect;
  final VoidCallback onDismiss;

  const _BellModal({
    required this.prayerKey,
    required this.prayerName,
    required this.currentValue,
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
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
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
              '$prayerName · Notification',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: appTheme.text,
                letterSpacing: 0.3,
              ),
            ),
          ),
          ..._bellOptions.map((option) {
            final isActive = currentValue == option['value'];
            return GestureDetector(
              onTap: () => onSelect(option['value'] as String),
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? appTheme.bg3 : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      option['icon'] as IconData,
                      size: 20,
                      color: isActive ? appTheme.accent : appTheme.textDim,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option['label'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isActive ? appTheme.accent : appTheme.text,
                            ),
                          ),
                          Text(
                            option['desc'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: appTheme.textMute,
                            ),
                          ),
                        ],
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
