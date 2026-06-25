import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../providers/settings_provider.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelSoundId = 'prayer_sound';
  static const _channelAdhanId = 'prayer_adhan';

  static const Map<String, int> _prayerIds = {
    'fajr': 0,
    'dhuhr': 1,
    'asr': 2,
    'maghrib': 3,
    'isha': 4,
  };

  static const Map<String, String> _prayerNames = {
    'fajr': 'Fajr',
    'dhuhr': 'Dhuhr',
    'asr': 'Asr',
    'maghrib': 'Maghrib',
    'isha': 'Isha',
  };

  static const Map<String, String> _adhanRawFiles = {
    'madinah': 'adhan_madinah',
    'makkah': 'adhan_makkah',
    'egypt': 'adhan_egypt',
    'abdul_basit': 'adhan_abdul_basit',
    'aqsa': 'adhan_aqsa',
  };

  static Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    // Standard notification sound channel.
    const soundChannel = AndroidNotificationChannel(
      _channelSoundId,
      'Prayer Time',
      description: 'Prayer time notifications with default sound',
      importance: Importance.high,
      playSound: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(soundChannel);
  }

  /// Create (or recreate) the adhan notification channel for the given sound key.
  /// On Android 8+ the sound cannot be changed after channel creation, so we
  /// create a unique channel per sound key.
  static Future<void> _ensureAdhanChannel(String soundKey) async {
    final rawFile = _adhanRawFiles[soundKey] ?? 'adhan_madinah';
    final adhanChannel = AndroidNotificationChannel(
      '${_channelAdhanId}_$soundKey',
      'Prayer Adhan',
      description: 'Prayer time notifications with adhan sound',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(rawFile),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(adhanChannel);
  }

  static Future<bool> _canScheduleExactAlarms() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? false;
  }

  /// Schedule prayer notifications for the next N days.
  /// [dayTimesList] index 0 = today, 1 = tomorrow, etc.
  static Future<void> schedulePrayers({
    required List<Map<String, DateTime?>> dayTimesList,
    required Map<String, BellMode> bellState,
    required bool notificationsEnabled,
    required String adhanSound,
  }) async {
    await _plugin.cancelAll();

    if (!notificationsEnabled) return;

    final rawFile = _adhanRawFiles[adhanSound] ?? 'adhan_madinah';
    await _ensureAdhanChannel(adhanSound);

    final canExact = await _canScheduleExactAlarms();
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexact;

    final now = DateTime.now();

    for (var dayOffset = 0; dayOffset < dayTimesList.length; dayOffset++) {
      final dayTimes = dayTimesList[dayOffset];

      for (final key in _prayerIds.keys) {
        final mode = bellState[key] ?? BellMode.notif;
        if (mode == BellMode.off) continue;

        final prayerTime = dayTimes[key];
        if (prayerTime == null) continue;
        // Skip prayers that have already passed today.
        if (dayOffset == 0 && !prayerTime.isAfter(now)) continue;

        await _scheduleOne(
          id: _prayerIds[key]! + dayOffset * 10,
          prayerName: _prayerNames[key]!,
          scheduledTime: prayerTime,
          mode: mode,
          adhanSoundKey: adhanSound,
          adhanRawFile: rawFile,
          scheduleMode: scheduleMode,
        );
      }
    }
  }

  static Future<void> _scheduleOne({
    required int id,
    required String prayerName,
    required DateTime scheduledTime,
    required BellMode mode,
    required String adhanSoundKey,
    required String adhanRawFile,
    required AndroidScheduleMode scheduleMode,
  }) async {
    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    final AndroidNotificationDetails androidDetails;

    if (mode == BellMode.adhan) {
      androidDetails = AndroidNotificationDetails(
        '${_channelAdhanId}_$adhanSoundKey',
        'Prayer Adhan',
        channelDescription: 'Prayer time notifications with adhan sound',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(adhanRawFile),
      );
    } else {
      androidDetails = const AndroidNotificationDetails(
        _channelSoundId,
        'Prayer Time',
        channelDescription: 'Prayer time notifications with default sound',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      );
    }

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      prayerName,
      "It's time for $prayerName prayer",
      tzTime,
      notificationDetails,
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Request notification permission on Android 13+.
  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }
}
