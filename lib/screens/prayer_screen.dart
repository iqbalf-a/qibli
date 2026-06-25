import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants/theme.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/location_service.dart';
import '../services/background_service.dart';
import '../services/notification_service.dart';
import '../utils/hijri_utils.dart';
import '../utils/prayer_utils.dart';
import '../widgets/animated_sheet.dart';
import '../widgets/app_widgets.dart';

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
  _PrayerEntry(key: 'asr',     name: 'Asr',     icon: Icons.wb_cloudy_outlined),
  _PrayerEntry(key: 'maghrib', name: 'Maghrib', icon: Icons.wb_twilight_outlined),
  _PrayerEntry(key: 'isha',    name: 'Isha',    icon: Icons.nightlight_outlined),
];

// Bell option descriptor — uses BellMode values.
class _BellOption {
  final BellMode value;
  final String label;
  final String desc;
  final IconData icon;
  const _BellOption({
    required this.value,
    required this.label,
    required this.desc,
    required this.icon,
  });
}

const List<_BellOption> _bellOptions = [
  _BellOption(
    value: BellMode.off,
    label: 'Off',
    desc: 'No notification',
    icon: Icons.notifications_off_outlined,
  ),
  _BellOption(
    value: BellMode.notif,
    label: 'Notification',
    desc: 'Silent alert only',
    icon: Icons.notifications_outlined,
  ),
  _BellOption(
    value: BellMode.adhan,
    label: 'Adhan',
    desc: 'Alert + adhan sound',
    icon: Icons.volume_up_outlined,
  ),
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
  PrayerData? _tomorrowPrayerData;
  DateTime _now = DateTime.now();
  late DateTime _selectedDate;
  String? _openBellModalKey;
  bool _isRefreshing = false;
  bool _isAdhanPlaying = false;
  DateTime? _lastAdhanTrigger;

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
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _checkAdhanTrigger();
    });
    _fetchLocation();
    // Reschedule notifications when settings change (bell, sound, toggle).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SettingsProvider>().addListener(_onSettingsChanged);
      }
    });
  }

  void _onSettingsChanged() {
    if (mounted && _todayPrayerData != null) {
      _scheduleNotifications();
    }
  }

  @override
  void dispose() {
    context.read<SettingsProvider>().removeListener(_onSettingsChanged);
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

    final result = await LocationService.fetchLocation();
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _cityName = 'Set location in Settings';
        _isRefreshing = false;
      });
      return;
    }

    setState(() {
      _latitude = result.lat;
      _longitude = result.lng;
      _cityName = result.cityName;
      _isRefreshing = false;
    });
    _rebuildPrayerTimes();
  }

  void _rebuildPrayerTimes() {
    if (_latitude == null || _longitude == null || !mounted) return;
    cacheCoordinates(_latitude!, _longitude!);
    final settings = context.read<SettingsProvider>();
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
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
      _tomorrowPrayerData = buildPrayerTimes(
        latitude: _latitude!,
        longitude: _longitude!,
        date: tomorrow,
        calculationMethod: settings.calculationMethod,
        madhab: settings.madhab,
      );
    });
    _scheduleNotifications();
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

  Future<void> _playAdhan(String soundKey) async {
    if (_isAdhanPlaying) return;
    final sound = adhanSounds.firstWhere(
      (s) => s['key'] == soundKey,
      orElse: () => adhanSounds.first,
    );
    setState(() => _isAdhanPlaying = true);
    await _audioPlayer.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.music,
          audioFocus: AndroidAudioFocus.gainTransient,
          isSpeakerphoneOn: false,
          stayAwake: false,
        ),
      ),
    );
    await _audioPlayer.play(AssetSource(sound['file']!));
    if (!mounted) return;
    _adhanStopTimer = Timer(const Duration(minutes: 5), _stopAdhan);
  }

  /// Called every second from the clock timer. Triggers in-app adhan playback
  /// when the current time matches a prayer time (within a 1-second window) and
  /// the prayer is configured for adhan mode.
  void _checkAdhanTrigger() {
    if (_isAdhanPlaying) return;
    final last = _lastAdhanTrigger;
    if (last != null && DateTime.now().difference(last).inMinutes < 5) return;
    final settings = context.read<SettingsProvider>();
    if (!settings.notificationsEnabled) return;

    final todayData = _todayPrayerData;
    if (todayData == null) return;

    const prayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    for (final key in prayerKeys) {
      final mode = settings.bellState[key] ?? BellMode.notif;
      if (mode != BellMode.adhan) continue;

      final prayerTime = getPrayerTime(todayData, key);
      if (prayerTime == null) continue;

      final diff = DateTime.now().difference(prayerTime).inSeconds.abs();
      if (diff <= 1) {
        _lastAdhanTrigger = DateTime.now();
        _playAdhan(settings.adhanSound);
        break;
      }
    }
  }

  // ─── Notification scheduling ──────────────────────────────────────────────

  Future<void> _scheduleNotifications() async {
    if (_latitude == null || _longitude == null) return;
    final settings = context.read<SettingsProvider>();

    const prayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    const scheduleDays = 7;
    final today = DateTime.now();

    final dayTimesList = <Map<String, DateTime?>>[];
    for (var dayOffset = 0; dayOffset < scheduleDays; dayOffset++) {
      final date = today.add(Duration(days: dayOffset));
      final prayerData = buildPrayerTimes(
        latitude: _latitude!,
        longitude: _longitude!,
        date: date,
        calculationMethod: settings.calculationMethod,
        madhab: settings.madhab,
      );
      final Map<String, DateTime?> dayTimes = {};
      for (final key in prayerKeys) {
        dayTimes[key] = getPrayerTime(prayerData, key);
      }
      dayTimesList.add(dayTimes);
    }

    await NotificationService.schedulePrayers(
      dayTimesList: dayTimesList,
      bellState: settings.bellState,
      notificationsEnabled: settings.notificationsEnabled,
      adhanSound: settings.adhanSound,
    );
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
    // All today's prayers have passed — show tomorrow's Fajr.
    final tomorrowFajr = _tomorrowPrayerData?.fajr;
    if (tomorrowFajr != null) {
      return (entry: _prayerEntries[1], time: tomorrowFajr);
    }
    return (entry: null, time: null);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<ThemeProvider>().theme;
    // Only rebuild when manualLocation changes — other settings are read via
    // context.read() inside callbacks or _rebuildPrayerTimes().
    final manualLoc = context.select<SettingsProvider, ManualLocation?>(
      (s) => s.manualLocation,
    );

    // Sync manual location changes reactively.
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

    // Read bell state and hijriOffset without triggering a full rebuild on
    // unrelated setting changes.
    final settings = context.read<SettingsProvider>();
    final hijriOffset = context.select<SettingsProvider, int>(
      (s) => s.hijriOffset,
    );
    final bellState = context.select<SettingsProvider, Map<String, BellMode>>(
      (s) => s.bellState,
    );
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
                _buildHeroCard(
                  appTheme,
                  nextPrayer.entry,
                  nextPrayer.time,
                  countdown,
                  hijriOffset,
                ),
                _buildDateNav(appTheme, hijriOffset),
                if (currentWindowLabel != null) ...[
                  const SizedBox(height: 4),
                  _buildWindowBadge(appTheme, currentWindowLabel),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (_isAdhanPlaying) _buildAdhanBanner(appTheme),
                Expanded(
                  child: _buildPrayerList(appTheme, bellState, nextPrayer.entry),
                ),
              ],
            ),
            if (_openBellModalKey != null)
              AnimatedSheet(
                key: ValueKey(_openBellModalKey),
                onDismiss: () => setState(() => _openBellModalKey = null),
                builder: (close) => _BellModal(
                  prayerKey: _openBellModalKey!,
                  prayerName: _prayerEntries
                      .firstWhere((e) => e.key == _openBellModalKey)
                      .name,
                  currentValue: bellState[_openBellModalKey!] ?? BellMode.notif,
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
                BorderIconButton(
                  appTheme: appTheme,
                  label: 'Back to Today',
                  onTap: _goToToday,
                  fontSize: 11,
                  letterSpacing: 0.5,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
    Map<String, BellMode> bellState,
    _PrayerEntry? nextEntry,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
      itemCount: _prayerEntries.length,
      itemBuilder: (context, index) {
        final prayerEntry = _prayerEntries[index];
        final prayerTime = getPrayerTime(_selectedDayPrayerData, prayerEntry.key);
        final isNext = _isViewingToday && nextEntry?.key == prayerEntry.key;
        final isPassed = _isViewingToday && prayerTime != null && prayerTime.isBefore(_now);
        final currentBell = bellState[prayerEntry.key] ??
            (prayerEntry.noAlert ? BellMode.off : BellMode.notif);

        final IconData bellIcon;
        final Color bellColor;
        if (currentBell == BellMode.adhan) {
          bellIcon = Icons.volume_up_outlined;
          bellColor = appTheme.accent;
        } else if (currentBell == BellMode.off) {
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
  final BellMode currentValue;
  final AppTheme appTheme;
  final void Function(BellMode value) onSelect;
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
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        32,
      ),
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
            final isActive = currentValue == option.value;
            return GestureDetector(
              onTap: () => onSelect(option.value),
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isActive ? appTheme.bg3 : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      option.icon,
                      size: 20,
                      color: isActive ? appTheme.accent : appTheme.textDim,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.label,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isActive ? appTheme.accent : appTheme.text,
                            ),
                          ),
                          Text(
                            option.desc,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: appTheme.textMute,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      Icon(
                        Icons.check,
                        size: 16,
                        color: appTheme.accent,
                      ),
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
