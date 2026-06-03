import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants/theme.dart';
import '../providers/theme_provider.dart';
import '../utils/hijri_utils.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  final DateTime _today = DateTime.now();
  late final HijriDate _todayHijri;

  String _mode = 'gregorian'; // 'gregorian' | 'hijri'

  late int _gregorianYear;
  late int _gregorianMonth;
  late int _hijriYear;
  late int _hijriMonth;

  CalendarCell? _selectedCell;

  // Slide animation
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _todayHijri = gregorianToHijri(_today);
    _gregorianYear  = _today.year;
    _gregorianMonth = _today.month;
    _hijriYear  = _todayHijri.year;
    _hijriMonth = _todayHijri.month;

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _animateSlide(double direction) {
    _slideController.value = 0;
    _slideAnimation = Tween<double>(
      begin: direction * 420,
      end: 0,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _slideController.forward();
  }

  void _previousMonth() {
    setState(() {
      if (_mode == 'hijri') {
        if (_hijriMonth == 1) {
          _hijriYear--;
          _hijriMonth = 12;
        } else {
          _hijriMonth--;
        }
      } else {
        if (_gregorianMonth == 1) {
          _gregorianYear--;
          _gregorianMonth = 12;
        } else {
          _gregorianMonth--;
        }
      }
    });
    _animateSlide(-1);
  }

  void _nextMonth() {
    setState(() {
      if (_mode == 'hijri') {
        if (_hijriMonth == 12) {
          _hijriYear++;
          _hijriMonth = 1;
        } else {
          _hijriMonth++;
        }
      } else {
        if (_gregorianMonth == 12) {
          _gregorianYear++;
          _gregorianMonth = 1;
        } else {
          _gregorianMonth++;
        }
      }
    });
    _animateSlide(1);
  }

  void _goToToday() {
    final currentPosition = _mode == 'hijri'
        ? _hijriYear * 12 + _hijriMonth
        : _gregorianYear * 12 + _gregorianMonth;
    final todayPosition = _mode == 'hijri'
        ? _todayHijri.year * 12 + _todayHijri.month
        : _today.year * 12 + _today.month;
    setState(() {
      _gregorianYear  = _today.year;
      _gregorianMonth = _today.month;
      _hijriYear  = _todayHijri.year;
      _hijriMonth = _todayHijri.month;
      _selectedCell = null;
    });
    _animateSlide(currentPosition < todayPosition ? 1 : -1);
  }

  bool get _isOffMonth => _mode == 'hijri'
      ? _hijriYear != _todayHijri.year || _hijriMonth != _todayHijri.month
      : _gregorianYear != _today.year || _gregorianMonth != _today.month;

  List<CalendarCell?> get _cells => _mode == 'hijri'
      ? buildHijriGrid(_hijriYear, _hijriMonth)
      : buildGregorianGrid(_gregorianYear, _gregorianMonth);

  String get _monthTitle => _mode == 'hijri'
      ? '${hijriMonths[_hijriMonth - 1]} $_hijriYear'
      : '${gregMonths[_gregorianMonth - 1]} $_gregorianYear';

  String get _monthSubtitle => _mode == 'hijri'
      ? hijriMonthRange(_hijriYear, _hijriMonth)
      : _gregorianMonthHijriRange();

  String _gregorianMonthHijriRange() {
    final startHijri = gregorianToHijri(DateTime(_gregorianYear, _gregorianMonth, 1));
    final lastDay = DateTime(_gregorianYear, _gregorianMonth + 1, 0).day;
    final endHijri = gregorianToHijri(DateTime(_gregorianYear, _gregorianMonth, lastDay));
    if (startHijri.month == endHijri.month) {
      return '${hijriMonths[startHijri.month - 1]} ${startHijri.year}';
    }
    return '${hijriMonths[startHijri.month - 1]} – ${hijriMonths[endHijri.month - 1]} ${endHijri.year}';
  }

  List<({HolidayInfo holiday, DateTime gregorianDate})> get _monthHolidays {
    final result = <({HolidayInfo holiday, DateTime gregorianDate})>[];
    if (_mode == 'hijri') {
      for (final holiday in islamicHolidays) {
        if (holiday.hijriMonth == _hijriMonth) {
          result.add((
            holiday: holiday,
            gregorianDate: hijriToGregorian(_hijriYear, holiday.hijriMonth, holiday.hijriDay),
          ));
        }
      }
    } else {
      final totalDays = DateTime(_gregorianYear, _gregorianMonth + 1, 0).day;
      for (var day = 1; day <= totalDays; day++) {
        final date = DateTime(_gregorianYear, _gregorianMonth, day);
        final hijri = gregorianToHijri(date);
        final holiday = getHoliday(hijri.month, hijri.day);
        if (holiday != null) result.add((holiday: holiday, gregorianDate: date));
      }
    }
    return result;
  }

  List<({NotableDay notable, DateTime gregorianDate})> get _monthNotable {
    const ayyamAlBid = 'Ayyam al-Bid';
    const ayyamAlBidDesc = 'Recommended fast';
    final result = <({NotableDay notable, DateTime gregorianDate})>[];
    if (_mode == 'hijri') {
      for (final notable in islamicNotableDays) {
        if (notable.hijriMonth == _hijriMonth) {
          result.add((
            notable: notable,
            gregorianDate: hijriToGregorian(_hijriYear, notable.hijriMonth, notable.hijriDay),
          ));
        }
      }
      final totalDays = daysInHijriMonth(_hijriYear, _hijriMonth);
      for (final ayyamDay in [13, 14, 15]) {
        if (ayyamDay <= totalDays) {
          final existing = getNotableDay(_hijriMonth, ayyamDay);
          if (existing == null) {
            result.add((
              notable: NotableDay(
                hijriMonth: _hijriMonth, hijriDay: ayyamDay,
                name: ayyamAlBid, desc: ayyamAlBidDesc,
              ),
              gregorianDate: hijriToGregorian(_hijriYear, _hijriMonth, ayyamDay),
            ));
          }
        }
      }
      result.sort((first, second) => first.notable.hijriDay.compareTo(second.notable.hijriDay));
    } else {
      final totalDays = DateTime(_gregorianYear, _gregorianMonth + 1, 0).day;
      for (var day = 1; day <= totalDays; day++) {
        final date = DateTime(_gregorianYear, _gregorianMonth, day);
        final hijri = gregorianToHijri(date);
        final notable = getNotableDay(hijri.month, hijri.day);
        if (notable != null) {
          result.add((notable: notable, gregorianDate: date));
        } else if (hijri.day >= 13 && hijri.day <= 15) {
          result.add((
            notable: NotableDay(
              hijriMonth: hijri.month, hijriDay: hijri.day,
              name: ayyamAlBid, desc: ayyamAlBidDesc,
            ),
            gregorianDate: date,
          ));
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<ThemeProvider>().theme;

    return Scaffold(
      backgroundColor: appTheme.bg1,
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            if (details.primaryVelocity! < -200) {
              _nextMonth();
            } else if (details.primaryVelocity! > 200) {
              _previousMonth();
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(appTheme),
                _buildMonthCard(appTheme),
                if (_selectedCell != null) _buildDetailCard(appTheme),
                if (_monthHolidays.isNotEmpty) _buildHolidaySection(appTheme),
                if (_monthNotable.isNotEmpty) _buildNotableSection(appTheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header with mode toggle ──────────────────────────────────────────────

  Widget _buildHeader(AppTheme appTheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Calendar',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: appTheme.text),
          ),
          Container(
            decoration: BoxDecoration(
              color: appTheme.toggleTrackBg,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModeToggleButton(
                  label: 'Gregorian',
                  isActive: _mode == 'gregorian',
                  appTheme: appTheme,
                  onTap: () => setState(() => _mode = 'gregorian'),
                ),
                _ModeToggleButton(
                  label: 'Hijri',
                  isActive: _mode == 'hijri',
                  appTheme: appTheme,
                  onTap: () => setState(() => _mode = 'hijri'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Month card ───────────────────────────────────────────────────────────

  Widget _buildMonthCard(AppTheme appTheme) {
    final cells = _cells;
    final rows = <List<CalendarCell?>>[];
    for (var startIndex = 0; startIndex < cells.length; startIndex += 7) {
      rows.add(cells.sublist(startIndex, (startIndex + 7).clamp(0, cells.length)));
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: appTheme.calendarCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appTheme.line),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Text(
            _mode == 'hijri' ? 'HIJRI MONTH' : 'GREGORIAN MONTH',
            style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w500,
              color: appTheme.textMute, letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Month navigation
          Row(
            children: [
              _NavButton(
                icon: Icons.chevron_left,
                appTheme: appTheme,
                onTap: _previousMonth,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _monthTitle,
                      style: GoogleFonts.nunito(
                        fontSize: 22, fontWeight: FontWeight.w700,
                        color: appTheme.text,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _monthSubtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: appTheme.textMute,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_isOffMonth) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _goToToday,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            border: Border.all(color: appTheme.lineStrong),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'TODAY',
                            style: GoogleFonts.inter(
                              fontSize: 10, fontWeight: FontWeight.w500,
                              color: appTheme.textMute, letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _NavButton(
                icon: Icons.chevron_right,
                appTheme: appTheme,
                onTap: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Animated grid
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) => Transform.translate(
              offset: Offset(_slideAnimation.value, 0),
              child: child,
            ),
            child: Column(
              children: [
                // Day-of-week header
                Row(
                  children: List.generate(7, (dayIndex) => Expanded(
                    child: Text(
                      ['S', 'M', 'T', 'W', 'T', 'F', 'S'][dayIndex],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: dayIndex == 5 ? appTheme.accentSoft : appTheme.textMute,
                        // Friday = index 5
                      ),
                    ),
                  )),
                ),
                const SizedBox(height: 4),

                // Calendar grid rows
                ...rows.map((row) => Row(
                  children: List.generate(7, (columnIndex) {
                    final cell = columnIndex < row.length ? row[columnIndex] : null;
                    if (cell == null) return const Expanded(child: SizedBox(height: 52));

                    final isToday = cell.gregorianDate.year == _today.year &&
                        cell.gregorianDate.month == _today.month &&
                        cell.gregorianDate.day == _today.day;
                    final isSelected = _selectedCell != null &&
                        cell.gregorianDate.year == _selectedCell!.gregorianDate.year &&
                        cell.gregorianDate.month == _selectedCell!.gregorianDate.month &&
                        cell.gregorianDate.day == _selectedCell!.gregorianDate.day;
                    final isFriday = cell.gregorianDate.weekday == DateTime.friday;

                    Color primaryColor;
                    if (isToday || isSelected) {
                      primaryColor = appTheme.accentSoft;
                    } else if (cell.holiday != null) {
                      primaryColor = appTheme.accent;
                    } else if (isFriday) {
                      primaryColor = appTheme.accentSoft;
                    } else {
                      primaryColor = appTheme.text;
                    }

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedCell = isSelected ? null : cell;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Center(
                            child: Container(
                              width: 36,
                              height: 46,
                              alignment: Alignment.topCenter,
                              padding: const EdgeInsets.only(top: 7),
                              decoration: BoxDecoration(
                                color: isToday
                                    ? appTheme.accentDeep
                                    : isSelected
                                        ? appTheme.bg3
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected && !isToday
                                    ? Border.all(color: appTheme.lineStrong)
                                    : null,
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.topCenter,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        '${cell.primaryNumber}',
                                        style: GoogleFonts.nunito(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: primaryColor,
                                          height: 1.2,
                                        ),
                                      ),
                                      Text(
                                        cell.subLabel,
                                        style: GoogleFonts.inter(
                                          fontSize: 8,
                                          color: (isToday || isSelected)
                                              ? appTheme.accentSoft.withValues(alpha: 0.7)
                                              : appTheme.textMute,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (cell.holiday != null)
                                    Positioned(
                                      bottom: -2,
                                      child: Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: (isToday || isSelected)
                                              ? appTheme.accentSoft
                                              : appTheme.accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                )),

                // Legend
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: appTheme.line)),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: 6,
                    children: [
                      _LegendItem(
                        label: 'Today',
                        appTheme: appTheme,
                        child: Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: appTheme.accentDeep,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      _LegendItem(
                        label: 'Holiday',
                        appTheme: appTheme,
                        child: Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(
                            color: appTheme.accent, shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'F',
                            style: GoogleFonts.inter(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: appTheme.accentSoft,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '= Friday',
                            style: GoogleFonts.inter(
                              fontSize: 10, fontWeight: FontWeight.w500,
                              color: appTheme.textMute,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Selected date detail card ────────────────────────────────────────────

  Widget _buildDetailCard(AppTheme appTheme) {
    final cell = _selectedCell!;
    const dowNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dowLabel = dowNames[cell.gregorianDate.weekday];
    final gregorianLabel =
        '$dowLabel, ${cell.gregorianDate.day} ${gregMonths[cell.gregorianDate.month - 1]} ${cell.gregorianDate.year}';
    final hijriLabel =
        '${cell.hijriDate.day} ${hijriMonths[cell.hijriDate.month - 1]} ${cell.hijriDate.year} H';

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: appTheme.calendarCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appTheme.lineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(gregorianLabel,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: appTheme.text)),
          const SizedBox(height: 2),
          Text(hijriLabel,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: appTheme.textMute)),
          if (cell.holiday != null) ...[
            const SizedBox(height: 6),
            Text(cell.holiday!.name,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: appTheme.accent)),
          ],
          if (cell.notable != null) ...[
            const SizedBox(height: 4),
            Text(
              '${cell.notable!.name} · ${cell.notable!.desc}',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: appTheme.accentSoft),
            ),
          ],
          if (cell.isAyyamAlBid && cell.notable == null) ...[
            const SizedBox(height: 4),
            Text(
              'Ayyam al-Bid · Recommended fast',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: appTheme.accentSoft),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Holiday section ──────────────────────────────────────────────────────

  Widget _buildHolidaySection(AppTheme appTheme) {
    final monthLabel = _mode == 'hijri'
        ? hijriMonths[_hijriMonth - 1]
        : gregMonths[_gregorianMonth - 1];

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PUBLIC HOLIDAYS',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: appTheme.accent, letterSpacing: 1)),
              Text(monthLabel,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: appTheme.textMute)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ..._monthHolidays.map((entry) {
            final holiday = entry.holiday;
            final gregorianDate = entry.gregorianDate;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: appTheme.line)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(color: appTheme.accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(holiday.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: appTheme.text)),
                        if (holiday.desc.isNotEmpty)
                          Text(holiday.desc,
                              style: GoogleFonts.inter(fontSize: 10, color: appTheme.textMute)),
                      ],
                    ),
                  ),
                  Text(
                    '${holiday.hijriDay} ${hijriMonths[holiday.hijriMonth - 1]}  ·  ${gregShort[gregorianDate.month - 1]} ${gregorianDate.day}',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: appTheme.textMute),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Notable days section ─────────────────────────────────────────────────

  Widget _buildNotableSection(AppTheme appTheme) {
    final monthLabel = _mode == 'hijri'
        ? hijriMonths[_hijriMonth - 1]
        : gregMonths[_gregorianMonth - 1];

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NOTABLE DAYS',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: appTheme.accentSoft, letterSpacing: 1)),
              Text(monthLabel,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: appTheme.textMute)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ..._monthNotable.map((entry) {
            final notable = entry.notable;
            final gregorianDate = entry.gregorianDate;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: appTheme.line)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(color: appTheme.accentSoft, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notable.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: appTheme.text)),
                        Text(notable.desc,
                            style: GoogleFonts.inter(fontSize: 10, color: appTheme.textMute)),
                      ],
                    ),
                  ),
                  Text(
                    '${notable.hijriDay} ${hijriMonths[notable.hijriMonth - 1]}  ·  ${gregShort[gregorianDate.month - 1]} ${gregorianDate.day}',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: appTheme.textMute),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Small reusable widgets ───────────────────────────────────────────────────

class _ModeToggleButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final AppTheme appTheme;
  final VoidCallback onTap;
  const _ModeToggleButton({
    required this.label,
    required this.isActive,
    required this.appTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? appTheme.toggleThumbBg : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 3, offset: const Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w500,
            color: isActive ? appTheme.accent : appTheme.textMute,
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final AppTheme appTheme;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.appTheme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: appTheme.navBtnBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: appTheme.textDim),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Widget child;
  final String label;
  final AppTheme appTheme;
  const _LegendItem({required this.child, required this.label, required this.appTheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: appTheme.textMute)),
      ],
    );
  }
}
