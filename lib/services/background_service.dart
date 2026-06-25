import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:workmanager/workmanager.dart';

import '../providers/settings_provider.dart';
import '../utils/prayer_utils.dart';
import 'notification_service.dart';

const _rescheduleTaskName = 'prayer_reschedule';
const _cachedLatKey = 'qibli_cached_lat';
const _cachedLngKey = 'qibli_cached_lng';

/// Called by WorkManager in a headless Flutter isolate.
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _rescheduleTaskName) {
      await _rescheduleNotifications();
    }
    return true;
  });
}

/// Register a periodic background task that reschedules prayer notifications
/// every 5 days so the 7-day window never expires.
Future<void> registerRescheduleTask() async {
  await Workmanager().initialize(backgroundCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'prayer_reschedule_periodic',
    _rescheduleTaskName,
    frequency: const Duration(days: 5),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    constraints: Constraints(networkType: NetworkType.notRequired),
  );
}

/// Save the current GPS coordinates so the background task can use them.
Future<void> cacheCoordinates(double lat, double lng) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(_cachedLatKey, lat);
  await prefs.setDouble(_cachedLngKey, lng);
}

Future<void> _rescheduleNotifications() async {
  tz_data.initializeTimeZones();

  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('qibli_settings');
  if (raw == null) return;

  final saved = jsonDecode(raw) as Map<String, dynamic>;

  // Prefer manual location stored in settings; fall back to last-known GPS.
  double? lat;
  double? lng;
  if (saved['manualLocation'] != null) {
    final loc = saved['manualLocation'] as Map<String, dynamic>;
    lat = (loc['lat'] as num).toDouble();
    lng = (loc['lng'] as num).toDouble();
  } else {
    lat = prefs.getDouble(_cachedLatKey);
    lng = prefs.getDouble(_cachedLngKey);
  }
  if (lat == null || lng == null) return;

  final calculationMethod =
      saved['calculationMethod'] as String? ?? 'MuslimWorldLeague';
  final madhab = saved['madhab'] as String? ?? 'Standard';
  final adhanSound = saved['adhanSound'] as String? ?? 'madinah';
  final notificationsEnabled =
      saved['notificationsEnabled'] as bool? ?? true;

  Map<String, BellMode> bellState = {
    'fajr': BellMode.notif,
    'dhuhr': BellMode.notif,
    'asr': BellMode.notif,
    'maghrib': BellMode.notif,
    'isha': BellMode.notif,
  };
  if (saved['bellState'] != null) {
    final rawBell = Map<String, dynamic>.from(saved['bellState'] as Map);
    bellState =
        rawBell.map((k, v) => MapEntry(k, BellMode.fromJson(v as String?)));
  }

  await NotificationService.init();

  const prayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
  const scheduleDays = 7;
  final today = DateTime.now();

  final dayTimesList = <Map<String, DateTime?>>[];
  for (var dayOffset = 0; dayOffset < scheduleDays; dayOffset++) {
    final date = today.add(Duration(days: dayOffset));
    final prayerData = buildPrayerTimes(
      latitude: lat,
      longitude: lng,
      date: date,
      calculationMethod: calculationMethod,
      madhab: madhab,
    );
    final Map<String, DateTime?> dayTimes = {};
    for (final key in prayerKeys) {
      dayTimes[key] = getPrayerTime(prayerData, key);
    }
    dayTimesList.add(dayTimes);
  }

  await NotificationService.schedulePrayers(
    dayTimesList: dayTimesList,
    bellState: bellState,
    notificationsEnabled: notificationsEnabled,
    adhanSound: adhanSound,
  );
}
