import 'package:adhan/adhan.dart';

class PrayerData {
  final DateTime? fajr;
  final DateTime? sunrise;
  final DateTime? dhuhr;
  final DateTime? asr;
  final DateTime? maghrib;
  final DateTime? isha;
  final DateTime? imsak;

  const PrayerData({
    this.fajr,
    this.sunrise,
    this.dhuhr,
    this.asr,
    this.maghrib,
    this.isha,
    this.imsak,
  });
}

CalculationParameters _buildParams(String methodKey, String madhabKey) {
  CalculationParameters params;
  switch (methodKey) {
    case 'Egyptian':
      params = CalculationMethod.egyptian.getParameters();
      break;
    case 'Karachi':
      params = CalculationMethod.karachi.getParameters();
      break;
    case 'UmmAlQura':
      params = CalculationMethod.umm_al_qura.getParameters();
      break;
    case 'Singapore':
      params = CalculationMethod.singapore.getParameters();
      break;
    case 'Kuwait':
      params = CalculationMethod.kuwait.getParameters();
      break;
    case 'Qatar':
      params = CalculationMethod.qatar.getParameters();
      break;
    case 'MoonsightingCommittee':
      params = CalculationMethod.moon_sighting_committee.getParameters();
      break;
    case 'MuslimWorldLeague':
    default:
      params = CalculationMethod.muslim_world_league.getParameters();
      break;
  }
  params.madhab = madhabKey == 'Hanafi' ? Madhab.hanafi : Madhab.shafi;
  return params;
}

PrayerData buildPrayerTimes({
  required double latitude,
  required double longitude,
  required DateTime date,
  required String calculationMethod,
  required String madhab,
}) {
  final coordinates = Coordinates(latitude, longitude);
  final params = _buildParams(calculationMethod, madhab);
  final dateComponents = DateComponents.from(date);
  final times = PrayerTimes(coordinates, dateComponents, params);

  final fajr = times.fajr;
  final imsak = fajr.subtract(const Duration(minutes: 10));

  return PrayerData(
    fajr: fajr,
    sunrise: times.sunrise,
    dhuhr: times.dhuhr,
    asr: times.asr,
    maghrib: times.maghrib,
    isha: times.isha,
    imsak: imsak,
  );
}

DateTime? getPrayerTime(PrayerData? data, String key) {
  if (data == null) return null;
  switch (key) {
    case 'imsak': return data.imsak;
    case 'fajr': return data.fajr;
    case 'sunrise': return data.sunrise;
    case 'dhuhr': return data.dhuhr;
    case 'asr': return data.asr;
    case 'maghrib': return data.maghrib;
    case 'isha': return data.isha;
    default: return null;
  }
}

String? getCurrentPrayerWindow(PrayerData? data, DateTime now) {
  if (data == null) return null;
  final windows = [
    if (data.fajr != null && data.sunrise != null)
      ('Fajr', data.fajr!, data.sunrise!),
    if (data.sunrise != null && data.dhuhr != null)
      ('Duha', data.sunrise!, data.dhuhr!),
    if (data.dhuhr != null && data.asr != null)
      ('Dhuhr', data.dhuhr!, data.asr!),
    if (data.asr != null && data.maghrib != null)
      ('Asr', data.asr!, data.maghrib!),
    if (data.maghrib != null && data.isha != null)
      ('Maghrib', data.maghrib!, data.isha!),
    if (data.isha != null)
      ('Isha', data.isha!, null as DateTime?),
  ];

  for (final (label, start, end) in windows) {
    if (now.isAfter(start) || now.isAtSameMomentAs(start)) {
      if (end == null || now.isBefore(end)) return label;
    }
  }
  return null;
}
