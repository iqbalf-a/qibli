import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'constants/theme.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/calendar_screen.dart';
import 'screens/prayer_screen.dart';
import 'screens/qibla_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await NotificationService.init();
  await NotificationService.requestPermission();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const QibliApp(),
    ),
  );
}

class QibliApp extends StatelessWidget {
  const QibliApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final appTheme = themeProvider.theme;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: appTheme.isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: appTheme.isDark ? Brightness.dark : Brightness.light,
    ));

    return MaterialApp(
      title: 'Qibli',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: appTheme.isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: appTheme.bg1,
        colorScheme: ColorScheme(
          brightness: appTheme.isDark ? Brightness.dark : Brightness.light,
          primary: appTheme.accent,
          onPrimary: appTheme.bg0,
          secondary: appTheme.accentSoft,
          onSecondary: appTheme.bg0,
          error: Colors.red,
          onError: Colors.white,
          surface: appTheme.bg1,
          onSurface: appTheme.text,
        ),
        textTheme: GoogleFonts.interTextTheme().copyWith(
          bodyLarge: GoogleFonts.inter(color: appTheme.text),
          bodyMedium: GoogleFonts.inter(color: appTheme.text),
          bodySmall: GoogleFonts.inter(color: appTheme.textMute),
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    PrayerScreen(),
    QiblaScreen(),
    CalendarScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<ThemeProvider>().theme;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _QibliTabBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        appTheme: appTheme,
      ),
    );
  }
}

class _QibliTabBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  final AppTheme appTheme;

  const _QibliTabBar({
    required this.currentIndex,
    required this.onTap,
    required this.appTheme,
  });

  @override
  Widget build(BuildContext context) {
    final tabItems = [
      _TabItem(
        icon: currentIndex == 0 ? Icons.nightlight_round : Icons.nightlight_outlined,
        label: 'Prayer',
        index: 0,
      ),
      _TabItem(
        icon: currentIndex == 1 ? Icons.explore : Icons.explore_outlined,
        label: 'Qibla',
        index: 1,
      ),
      _TabItem(
        icon: currentIndex == 2 ? Icons.calendar_month : Icons.calendar_month_outlined,
        label: 'Calendar',
        index: 2,
      ),
      _TabItem(
        icon: currentIndex == 3 ? Icons.settings : Icons.settings_outlined,
        label: 'Settings',
        index: 3,
      ),
    ];

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: appTheme.bg0,
        border: Border(top: BorderSide(color: appTheme.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: tabItems.map((tabItem) {
            final isActive = tabItem.index == currentIndex;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(tabItem.index),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tabItem.icon,
                      size: 20,
                      color: isActive ? appTheme.accent : appTheme.textMute,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tabItem.label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isActive ? appTheme.accent : appTheme.textMute,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isActive ? 3 : 0,
                      height: isActive ? 3 : 0,
                      decoration: BoxDecoration(
                        color: appTheme.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  final int index;
  const _TabItem({required this.icon, required this.label, required this.index});
}
