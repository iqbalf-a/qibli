import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notification mode for each prayer.
enum BellMode {
  off,
  notif,
  adhan;

  /// Serialise to the string stored in SharedPreferences.
  String toJson() => name;

  /// Deserialise from a stored string, defaulting to [notif].
  static BellMode fromJson(String? value) => switch (value) {
        'off' => BellMode.off,
        'adhan' => BellMode.adhan,
        _ => BellMode.notif,
      };
}

const List<Map<String, String>> calculationMethods = [
  {'key': 'MuslimWorldLeague', 'label': 'Muslim World League'},
  {'key': 'Egyptian', 'label': 'Egyptian'},
  {'key': 'Karachi', 'label': 'Karachi'},
  {'key': 'UmmAlQura', 'label': 'Umm Al-Qura'},
  {'key': 'Singapore', 'label': 'Singapore'},
  {'key': 'Kuwait', 'label': 'Kuwait'},
  {'key': 'Qatar', 'label': 'Qatar'},
  {'key': 'MoonsightingCommittee', 'label': 'Moonsighting Committee'},
];

const List<Map<String, String>> madhabs = [
  {'key': 'Standard', 'label': "Standard (Shafi'i, Maliki, Hanbali)", 'shortLabel': 'Standard'},
  {'key': 'Hanafi', 'label': 'Hanafi', 'shortLabel': 'Hanafi'},
];

const List<Map<String, String>> adhanSounds = [
  {'key': 'madinah', 'label': 'Madinah', 'file': 'audio/adhan_madinah.mp3'},
  {'key': 'makkah', 'label': 'Makkah', 'file': 'audio/adhan_makkah.mp3'},
  {'key': 'egypt', 'label': 'Egypt', 'file': 'audio/adhan_egypt.mp3'},
  {'key': 'abdul_basit', 'label': 'Abdul Basit', 'file': 'audio/adhan_abdul_basit.mp3'},
  {'key': 'aqsa', 'label': 'Al-Aqsa', 'file': 'audio/adhan_aqsa.mp3'},
];

class ManualLocation {
  final String city;
  final String country;
  final double lat;
  final double lng;

  const ManualLocation({
    required this.city,
    required this.country,
    required this.lat,
    required this.lng,
  });

  factory ManualLocation.fromJson(Map<String, dynamic> json) => ManualLocation(
        city: json['city'] as String,
        country: json['country'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'city': city,
        'country': country,
        'lat': lat,
        'lng': lng,
      };
}

class SettingsProvider extends ChangeNotifier {
  static const _prefsKey = 'qibli_settings';

  String _calculationMethod = 'MuslimWorldLeague';
  String _madhab = 'Standard';
  String _adhanSound = 'madinah';
  Map<String, BellMode> _bellState = {
    'fajr': BellMode.notif,
    'dhuhr': BellMode.notif,
    'asr': BellMode.notif,
    'maghrib': BellMode.notif,
    'isha': BellMode.notif,
  };
  int _hijriOffset = 0;
  ManualLocation? _manualLocation;
  bool _notificationsEnabled = true;

  String get calculationMethod => _calculationMethod;
  String get madhab => _madhab;
  String get adhanSound => _adhanSound;
  Map<String, BellMode> get bellState => Map.unmodifiable(_bellState);
  int get hijriOffset => _hijriOffset;
  ManualLocation? get manualLocation => _manualLocation;
  bool get notificationsEnabled => _notificationsEnabled;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      if (saved['calculationMethod'] != null) _calculationMethod = saved['calculationMethod'] as String;
      if (saved['madhab'] != null) _madhab = saved['madhab'] as String;
      if (saved['adhanSound'] != null) _adhanSound = saved['adhanSound'] as String;
      if (saved['bellState'] != null) {
        final rawBell = Map<String, dynamic>.from(saved['bellState'] as Map);
        _bellState = rawBell.map(
          (key, value) => MapEntry(key, BellMode.fromJson(value as String?)),
        );
      }
      if (saved['hijriOffset'] != null) _hijriOffset = saved['hijriOffset'] as int;
      if (saved['manualLocation'] != null) {
        _manualLocation = ManualLocation.fromJson(saved['manualLocation'] as Map<String, dynamic>);
      }
      if (saved['notificationsEnabled'] != null) {
        _notificationsEnabled = saved['notificationsEnabled'] as bool;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persist(Map<String, dynamic> patch) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final current = raw != null ? jsonDecode(raw) as Map<String, dynamic> : <String, dynamic>{};
    current.addAll(patch);
    await prefs.setString(_prefsKey, jsonEncode(current));
  }

  void updateCalculationMethod(String key) {
    _calculationMethod = key;
    notifyListeners();
    _persist({'calculationMethod': key});
  }

  void updateMadhab(String key) {
    _madhab = key;
    notifyListeners();
    _persist({'madhab': key});
  }

  void updateAdhanSound(String key) {
    _adhanSound = key;
    notifyListeners();
    _persist({'adhanSound': key});
  }

  void updateBell(String prayerKey, BellMode value) {
    _bellState = {..._bellState, prayerKey: value};
    notifyListeners();
    _persist({
      'bellState': _bellState.map((k, v) => MapEntry(k, v.toJson())),
    });
  }

  void updateHijriOffset(int value) {
    final clamped = value.clamp(-2, 2);
    _hijriOffset = clamped;
    notifyListeners();
    _persist({'hijriOffset': clamped});
  }

  void updateManualLocation(ManualLocation? loc) {
    _manualLocation = loc;
    notifyListeners();
    _persist({'manualLocation': loc?.toJson()});
  }

  void updateNotificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
    notifyListeners();
    _persist({'notificationsEnabled': enabled});
  }
}
