// Hijri calendar math using the tabular/astronomical method (Julian Day Number).
// Ported from calendar.jsx in the reference Expo project.

class HijriDate {
  final int year;
  final int month;
  final int day;
  const HijriDate({required this.year, required this.month, required this.day});
}

int _gregorianToJulianDay(DateTime date) {
  final day = date.day;
  final month = date.month;
  final year = date.year;
  final monthAdjust = ((14 - month) / 12).floor();
  final adjustedYear = year + 4800 - monthAdjust;
  final adjustedMonth = month + 12 * monthAdjust - 3;
  return day +
      ((153 * adjustedMonth + 2) / 5).floor() +
      365 * adjustedYear +
      (adjustedYear / 4).floor() -
      (adjustedYear / 100).floor() +
      (adjustedYear / 400).floor() -
      32045;
}

HijriDate _julianDayToHijri(int julianDay) {
  final epochOffset = julianDay - 1948440 + 10632;
  final thirtyYearCycles = ((epochOffset - 1) / 10631).floor();
  final remainder = epochOffset - 10631 * thirtyYearCycles + 354;
  final yearInCycle =
      ((10985 - remainder) / 5316).floor() * ((50 * remainder) / 17719).floor() +
      (remainder / 5670).floor() * ((43 * remainder) / 15238).floor();
  final dayInYear = remainder -
      ((30 - yearInCycle) / 15).floor() * ((17719 * yearInCycle) / 50).floor() -
      (yearInCycle / 16).floor() * ((15238 * yearInCycle) / 43).floor() +
      29;
  final hijriMonth = ((24 * dayInYear) / 709).floor();
  return HijriDate(
    year: 30 * thirtyYearCycles + yearInCycle - 30,
    month: hijriMonth,
    day: dayInYear - ((709 * hijriMonth) / 24).floor(),
  );
}

int _hijriToJulianDay(int hijriYear, int hijriMonth, int hijriDay) {
  return ((11 * hijriYear + 3) / 30).floor() +
      354 * hijriYear +
      30 * hijriMonth -
      ((hijriMonth - 1) / 2).floor() +
      hijriDay +
      1948440 -
      385;
}

DateTime _julianDayToGregorian(int julianDay) {
  int temp = julianDay + 68569;
  final centuryBucket = ((4 * temp) / 146097).floor();
  temp = temp - ((146097 * centuryBucket + 3) / 4).floor();
  final yearEstimate = ((4000 * (temp + 1)) / 1461001).floor();
  temp = temp - ((1461 * yearEstimate) / 4).floor() + 31;
  final monthEstimate = ((80 * temp) / 2447).floor();
  final day = temp - ((2447 * monthEstimate) / 80).floor();
  final monthAdjust = (monthEstimate / 11).floor();
  return DateTime(
    100 * (centuryBucket - 49) + yearEstimate + monthAdjust,
    monthEstimate + 2 - 12 * monthAdjust,
    day,
  );
}

HijriDate gregorianToHijri(DateTime date) =>
    _julianDayToHijri(_gregorianToJulianDay(date));

DateTime hijriToGregorian(int hijriYear, int hijriMonth, int hijriDay) =>
    _julianDayToGregorian(_hijriToJulianDay(hijriYear, hijriMonth, hijriDay));

int daysInHijriMonth(int hijriYear, int hijriMonth) {
  final nextMonth = hijriMonth == 12 ? 1 : hijriMonth + 1;
  final nextYear = hijriMonth == 12 ? hijriYear + 1 : hijriYear;
  return _hijriToJulianDay(nextYear, nextMonth, 1) -
      _hijriToJulianDay(hijriYear, hijriMonth, 1);
}

// ─── Constants ────────────────────────────────────────────────────────────────

const List<String> hijriMonths = [
  'Muharram', 'Safar', "Rabi' al-Awwal", "Rabi' al-Akhir",
  'Jumada al-Awwal', 'Jumada al-Akhir', 'Rajab', "Sha'ban",
  'Ramadan', 'Shawwal', "Dhu al-Qa'dah", "Dhu al-Hijjah",
];

const List<String> hijriShort = [
  'Muh', 'Saf', 'RaI', 'RaA', 'JuI', 'JuA', 'Raj', 'Sha', 'Ram', 'Shw', 'Qad', 'Dhj',
];

const List<String> gregMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const List<String> gregShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// ─── Holiday & notable data ───────────────────────────────────────────────────

class HolidayInfo {
  final int hijriMonth;
  final int hijriDay;
  final String name;
  final String desc;
  const HolidayInfo({
    required this.hijriMonth,
    required this.hijriDay,
    required this.name,
    required this.desc,
  });
}

const List<HolidayInfo> islamicHolidays = [
  HolidayInfo(hijriMonth: 1,  hijriDay: 1,  name: 'Islamic New Year', desc: 'First day of Muharram'),
  HolidayInfo(hijriMonth: 3,  hijriDay: 12, name: 'Maulid Nabi',      desc: "Birthday of Prophet Muhammad ﷺ"),
  HolidayInfo(hijriMonth: 7,  hijriDay: 27, name: "Isra' Mi'raj",     desc: 'Night journey and ascension'),
  HolidayInfo(hijriMonth: 10, hijriDay: 1,  name: 'Eid al-Fitr',      desc: 'End of Ramadan · day 1'),
  HolidayInfo(hijriMonth: 10, hijriDay: 2,  name: 'Eid al-Fitr',      desc: 'End of Ramadan · day 2'),
  HolidayInfo(hijriMonth: 10, hijriDay: 3,  name: 'Eid al-Fitr',      desc: 'End of Ramadan · day 3'),
  HolidayInfo(hijriMonth: 12, hijriDay: 10, name: 'Eid al-Adha',      desc: 'Feast of sacrifice'),
];

class NotableDay {
  final int hijriMonth;
  final int hijriDay;
  final String name;
  final String desc;
  const NotableDay({
    required this.hijriMonth,
    required this.hijriDay,
    required this.name,
    required this.desc,
  });
}

const List<NotableDay> islamicNotableDays = [
  NotableDay(hijriMonth: 1,  hijriDay: 9,  name: "Tasu'a",            desc: 'Recommended fast before Ashura'),
  NotableDay(hijriMonth: 1,  hijriDay: 10, name: 'Day of Ashura',     desc: 'Moses freed from Pharaoh'),
  NotableDay(hijriMonth: 8,  hijriDay: 15, name: "Nisfu Sha'ban",     desc: 'Night of forgiveness'),
  NotableDay(hijriMonth: 9,  hijriDay: 1,  name: 'First of Ramadan',  desc: 'Beginning of the fasting month'),
  NotableDay(hijriMonth: 9,  hijriDay: 17, name: 'Nuzul Quran',       desc: 'Revelation of the Quran'),
  NotableDay(hijriMonth: 9,  hijriDay: 27, name: 'Laylatul Qadr',     desc: 'Night of Power'),
  NotableDay(hijriMonth: 10, hijriDay: 2,  name: '6 Days of Shawwal', desc: 'Recommended fast · day 1 of 6'),
  NotableDay(hijriMonth: 10, hijriDay: 3,  name: '6 Days of Shawwal', desc: 'Recommended fast · day 2 of 6'),
  NotableDay(hijriMonth: 10, hijriDay: 4,  name: '6 Days of Shawwal', desc: 'Recommended fast · day 3 of 6'),
  NotableDay(hijriMonth: 10, hijriDay: 5,  name: '6 Days of Shawwal', desc: 'Recommended fast · day 4 of 6'),
  NotableDay(hijriMonth: 10, hijriDay: 6,  name: '6 Days of Shawwal', desc: 'Recommended fast · day 5 of 6'),
  NotableDay(hijriMonth: 10, hijriDay: 7,  name: '6 Days of Shawwal', desc: 'Recommended fast · day 6 of 6'),
  NotableDay(hijriMonth: 12, hijriDay: 8,  name: 'Fast of Tarwiyah',  desc: 'Recommended fast on 8 Dhu al-Hijjah'),
  NotableDay(hijriMonth: 12, hijriDay: 9,  name: 'Fast of Arafah',    desc: 'Recommended fast on the Day of Arafah'),
  NotableDay(hijriMonth: 12, hijriDay: 11, name: 'Ayyam al-Tasyrik',  desc: 'Fasting prohibited'),
  NotableDay(hijriMonth: 12, hijriDay: 12, name: 'Ayyam al-Tasyrik',  desc: 'Fasting prohibited'),
  NotableDay(hijriMonth: 12, hijriDay: 13, name: 'Ayyam al-Tasyrik',  desc: 'Fasting prohibited'),
];

// O(1) lookup maps built once at startup.
final Map<(int, int), HolidayInfo> _holidayMap = Map.fromEntries(
  islamicHolidays.map((h) => MapEntry((h.hijriMonth, h.hijriDay), h)),
);

final Map<(int, int), NotableDay> _notableDayMap = Map.fromEntries(
  islamicNotableDays.map((n) => MapEntry((n.hijriMonth, n.hijriDay), n)),
);

HolidayInfo? getHoliday(int hijriMonth, int hijriDay) =>
    _holidayMap[(hijriMonth, hijriDay)];

NotableDay? getNotableDay(int hijriMonth, int hijriDay) =>
    _notableDayMap[(hijriMonth, hijriDay)];

// ─── Calendar grid builders ───────────────────────────────────────────────────

class CalendarCell {
  final int primaryNumber;
  final String subLabel;
  final DateTime gregorianDate;
  final HijriDate hijriDate;
  final HolidayInfo? holiday;
  final NotableDay? notable;
  final bool isAyyamAlBid;

  const CalendarCell({
    required this.primaryNumber,
    required this.subLabel,
    required this.gregorianDate,
    required this.hijriDate,
    this.holiday,
    this.notable,
    this.isAyyamAlBid = false,
  });
}

List<CalendarCell?> buildHijriGrid(int hijriYear, int hijriMonth) {
  final totalDays = daysInHijriMonth(hijriYear, hijriMonth);
  final firstGregorianDay = hijriToGregorian(hijriYear, hijriMonth, 1);
  final startDayOfWeek = firstGregorianDay.weekday % 7; // 0=Sunday
  final cells = <CalendarCell?>[];
  for (var index = 0; index < startDayOfWeek; index++) {
    cells.add(null);
  }
  for (var day = 1; day <= totalDays; day++) {
    final gregorianDate = hijriToGregorian(hijriYear, hijriMonth, day);
    cells.add(CalendarCell(
      primaryNumber: day,
      subLabel: '${gregorianDate.day} ${gregShort[gregorianDate.month - 1]}',
      gregorianDate: gregorianDate,
      hijriDate: HijriDate(year: hijriYear, month: hijriMonth, day: day),
      holiday: getHoliday(hijriMonth, day),
      notable: getNotableDay(hijriMonth, day),
      isAyyamAlBid: day >= 13 && day <= 15,
    ));
  }
  return cells;
}

List<CalendarCell?> buildGregorianGrid(int year, int month, {int hijriOffset = 0}) {
  final totalDays = DateTime(year, month + 1, 0).day;
  final startDayOfWeek = DateTime(year, month, 1).weekday % 7; // 0=Sunday
  final cells = <CalendarCell?>[];
  for (var index = 0; index < startDayOfWeek; index++) {
    cells.add(null);
  }
  for (var day = 1; day <= totalDays; day++) {
    final date = DateTime(year, month, day);
    final hijri = gregorianToHijri(date.add(Duration(days: hijriOffset)));
    cells.add(CalendarCell(
      primaryNumber: day,
      subLabel: '${hijri.day} ${hijriShort[hijri.month - 1]}',
      gregorianDate: date,
      hijriDate: hijri,
      holiday: getHoliday(hijri.month, hijri.day),
      notable: getNotableDay(hijri.month, hijri.day),
      isAyyamAlBid: hijri.day >= 13 && hijri.day <= 15,
    ));
  }
  return cells;
}

String hijriMonthRange(int hijriYear, int hijriMonth) {
  final totalDays = daysInHijriMonth(hijriYear, hijriMonth);
  final startDate = hijriToGregorian(hijriYear, hijriMonth, 1);
  final endDate = hijriToGregorian(hijriYear, hijriMonth, totalDays);
  final startMonthLabel = gregShort[startDate.month - 1];
  final endMonthLabel = gregShort[endDate.month - 1];
  if (startDate.month == endDate.month) return '$startMonthLabel ${startDate.year}';
  if (startDate.year == endDate.year) return '$startMonthLabel – $endMonthLabel ${startDate.year}';
  return '$startMonthLabel ${startDate.year} – $endMonthLabel ${endDate.year}';
}

String formatHijriDate(DateTime gregorianDate, {int offset = 0}) {
  final adjusted = gregorianDate.add(Duration(days: offset));
  final hijri = gregorianToHijri(adjusted);
  return '${hijri.day} ${hijriMonths[hijri.month - 1]} ${hijri.year}';
}
