import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../constants/theme.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const double _makkahLatitude  = 21.4225;
const double _makkahLongitude = 39.8262;
const double _alignmentThresholdDegrees = 3.0;

// ─── Math helpers ─────────────────────────────────────────────────────────────

double _getQiblaBearing(double userLatitude, double userLongitude) {
  final lat1Rad = userLatitude * math.pi / 180;
  final lat2Rad = _makkahLatitude * math.pi / 180;
  final deltaLongRad = (_makkahLongitude - userLongitude) * math.pi / 180;
  final yComponent = math.sin(deltaLongRad) * math.cos(lat2Rad);
  final xComponent = math.cos(lat1Rad) * math.sin(lat2Rad) -
      math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(deltaLongRad);
  return (math.atan2(yComponent, xComponent) * 180 / math.pi + 360) % 360;
}

double _getDistanceToMakkahKm(double userLatitude, double userLongitude) {
  const earthRadiusKm = 6371.0;
  final deltaLatRad = (_makkahLatitude - userLatitude) * math.pi / 180;
  final deltaLongRad = (_makkahLongitude - userLongitude) * math.pi / 180;
  final sinHalfLat = math.sin(deltaLatRad / 2);
  final sinHalfLong = math.sin(deltaLongRad / 2);
  final haversine = sinHalfLat * sinHalfLat +
      math.cos(userLatitude * math.pi / 180) *
          math.cos(_makkahLatitude * math.pi / 180) *
          sinHalfLong *
          sinHalfLong;
  return (earthRadiusKm * 2 * math.asin(math.sqrt(haversine))).roundToDouble();
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen>
    with TickerProviderStateMixin {
  double? _latitude;
  double? _longitude;
  String _cityName = 'Locating...';

  // Gyroscope-smoothed dial rotation (accumulated)
  double _dialRotationDegrees = 0;
  double _lerpAngleDegrees = 0;
  double _filteredGyroZ = 0;
  double? _headingTarget;

  // Displayed heading text (updated at 20Hz)
  int _displayedHeadingDegrees = 0;

  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  Timer? _headingTextTimer;
  Ticker? _animationTicker;
  DateTime? _lastTickTime;

  bool _manualLocationMounted = false;

  // Aligned glow animation
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;
  bool _prevIsAligned = false;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _glowAnim = _glowCtrl;
    _startSensors();
    _fetchLocation();
    _headingTextTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final rounded = _lerpAngleDegrees.round();
      if (rounded != _displayedHeadingDegrees && mounted) {
        setState(() => _displayedHeadingDegrees = rounded);
      }
      // Update glow when alignment state changes
      if (_latitude != null && _longitude != null) {
        final qibla = _getQiblaBearing(_latitude!, _longitude!);
        final diff = ((qibla - _lerpAngleDegrees + 540) % 360) - 180;
        final nowAligned = diff.abs() <= _alignmentThresholdDegrees;
        if (nowAligned != _prevIsAligned) {
          _prevIsAligned = nowAligned;
          if (nowAligned) {
            _glowCtrl.forward();
          } else {
            _glowCtrl.reverse();
          }
        }
      }
    });
    _animationTicker = createTicker(_onAnimationTick)..start();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _compassSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _headingTextTimer?.cancel();
    _animationTicker?.dispose();
    super.dispose();
  }

  void _startSensors() {
    // Magnetometer compass heading
    _compassSubscription = FlutterCompass.events?.listen((compassEvent) {
      final heading = compassEvent.heading ?? compassEvent.headingForCameraMode;
      if (heading != null) _headingTarget = heading;
    });

    // Gyroscope for smooth 60fps interpolation
    _gyroscopeSubscription = gyroscopeEventStream().listen((gyroscopeEvent) {
      _rawGyroZ = gyroscopeEvent.z;
    });
  }

  double _rawGyroZ = 0;

  void _onAnimationTick(Duration elapsed) {
    final now = DateTime.now();
    final deltaSeconds = _lastTickTime != null
        ? now.difference(_lastTickTime!).inMicroseconds / 1e6
        : 0.016;
    _lastTickTime = now;

    // Adaptive EMA filter: heavy when slow (alpha=0.7), light when fast (alpha=0.3)
    final gyroSpeed = _filteredGyroZ.abs();
    final emaAlpha = (0.7 - gyroSpeed * 0.4).clamp(0.3, 0.7);
    _filteredGyroZ = emaAlpha * _filteredGyroZ + (1 - emaAlpha) * _rawGyroZ;

    final gyroDeltaDegrees = -_filteredGyroZ * (180 / math.pi) * deltaSeconds;

    double correctionDegrees = 0;
    final target = _headingTarget;
    if (target != null) {
      double drift = target - _lerpAngleDegrees;
      // Normalize to [-180, 180]
      while (drift > 180) { drift -= 360; }
      while (drift < -180) { drift += 360; }

      if (drift.abs() > 30) {
        // Large drift: snap immediately
        correctionDegrees = drift;
      } else if (_filteredGyroZ.abs() < 0.02) {
        // Small drift, phone nearly still: proportional correction
        final correctionRate = (drift.abs() * 4).clamp(0, 120);
        correctionDegrees = (correctionRate * deltaSeconds).clamp(-drift.abs(), drift.abs()) *
            (drift >= 0 ? 1 : -1);
      }
    }

    final totalDeltaDegrees = gyroDeltaDegrees + correctionDegrees;
    _lerpAngleDegrees = ((_lerpAngleDegrees + totalDeltaDegrees) + 360) % 360;
    _dialRotationDegrees -= totalDeltaDegrees;
  }

  Future<void> _fetchLocation() async {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();

    if (settings.manualLocation != null) {
      final loc = settings.manualLocation!;
      if (mounted) {
        setState(() {
          _latitude = loc.lat;
          _longitude = loc.lng;
          _cityName = '${loc.city}, ${loc.country}';
        });
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _cityName = 'Set location in Settings');
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
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
          setState(() => _cityName = '$area, ${place.isoCountryCode ?? ''}');
        }
      } catch (_) {}
    } catch (_) {
      if (mounted) setState(() => _cityName = 'Enable location services');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<ThemeProvider>().theme;
    final settings = context.watch<SettingsProvider>();

    // Sync manual location changes
    final manualLoc = settings.manualLocation;
    if (!_manualLocationMounted) {
      _manualLocationMounted = true;
    } else if (manualLoc != null &&
        (_latitude != manualLoc.lat || _longitude != manualLoc.lng)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _latitude = manualLoc.lat;
          _longitude = manualLoc.lng;
          _cityName = '${manualLoc.city}, ${manualLoc.country}';
        });
      });
    }

    final double? qiblaBearing = (_latitude != null && _longitude != null)
        ? _getQiblaBearing(_latitude!, _longitude!)
        : null;
    final double? distanceKm = (_latitude != null && _longitude != null)
        ? _getDistanceToMakkahKm(_latitude!, _longitude!)
        : null;

    final double? bearingDiff = qiblaBearing != null
        ? ((qiblaBearing - _lerpAngleDegrees + 540) % 360) - 180
        : null;
    final bool isAligned = bearingDiff != null && bearingDiff.abs() <= _alignmentThresholdDegrees;

    final latitudeLabel = _latitude != null
        ? '${_latitude!.abs().toStringAsFixed(1)}°${_latitude! >= 0 ? 'N' : 'S'}'
        : '';

    final compassSize = (MediaQuery.of(context).size.width - 48).clamp(0.0, 320.0);

    return Scaffold(
      backgroundColor: appTheme.bg1,
      body: Stack(
        children: [
          // Aligned glow: gradient fade from top (65% height)
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: FadeTransition(
                opacity: _glowAnim,
                child: FractionallySizedBox(
                  heightFactor: 0.65,
                  widthFactor: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [appTheme.accentGlow, Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Qibla',
                    style: GoogleFonts.inter(
                        fontSize: 20, fontWeight: FontWeight.w700, color: appTheme.text),
                  ),
                  Text(
                    latitudeLabel.isNotEmpty
                        ? '${_cityName.toUpperCase()} · $latitudeLabel'
                        : _cityName.toUpperCase(),
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w500,
                        color: appTheme.accent, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),

            // Info panel
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: [
                  Text(
                    isAligned ? 'ALIGNED TO KAABA' : 'ROTATE TO ALIGN',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: appTheme.accent, letterSpacing: 2,
                    ),
                  ),
                  Text(
                    '$_displayedHeadingDegrees°',
                    style: GoogleFonts.nunito(
                      fontSize: 72, fontWeight: FontWeight.w600,
                      color: appTheme.accent, height: 1.1,
                    ),
                  ),
                  Text(
                    qiblaBearing != null
                        ? 'QIBLA · ${qiblaBearing.round()}°'
                        : 'QIBLA · --',
                    style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: appTheme.textMute, letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            // Compass
            _CompassDial(
              compassSize: compassSize,
              dialRotation: _dialRotationDegrees,
              qiblaBearing: qiblaBearing,
              isAligned: isAligned,
              appTheme: appTheme,
            ),

            // Bottom section
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl, vertical: 14),
                    decoration: BoxDecoration(
                      color: appTheme.bg2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isAligned ? appTheme.accent : appTheme.line,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CubeIcon(
                          size: 15,
                          color: isAligned ? appTheme.accent : appTheme.textDim,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          bearingDiff == null
                              ? 'LOCATING...'
                              : isAligned
                                  ? 'FACING THE KAABA'
                                  : 'TURN ${bearingDiff > 0 ? 'RIGHT' : 'LEFT'} ${bearingDiff.abs().round()}°',
                          style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w500,
                            color: isAligned ? appTheme.accent : appTheme.textDim,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    distanceKm != null
                        ? '${distanceKm.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')} KM TO MAKKAH'
                        : '-- KM TO MAKKAH',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: appTheme.textMute, letterSpacing: 0.5,
                    ),
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
}

// ─── Compass dial widget ──────────────────────────────────────────────────────

class _CompassDial extends StatelessWidget {
  final double compassSize;
  final double dialRotation;
  final double? qiblaBearing;
  final bool isAligned;
  final AppTheme appTheme;

  const _CompassDial({
    required this.compassSize,
    required this.dialRotation,
    required this.qiblaBearing,
    required this.isAligned,
    required this.appTheme,
  });

  @override
  Widget build(BuildContext context) {
    final outerRadius = compassSize / 2;

    return SizedBox(
      width: compassSize,
      height: compassSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radial gradient background (CustomPaint)
          CustomPaint(
            size: Size(compassSize, compassSize),
            painter: _CompassBackgroundPainter(
              gradientColors: appTheme.compassGradient,
              borderColor: appTheme.lineStrong,
            ),
          ),

          // Inner decorative ring
          Container(
            width: outerRadius * 1.3,
            height: outerRadius * 1.3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: appTheme.lineStrong, width: 1),
            ),
          ),

          // Rotating dial (tick marks, degree labels, cardinals, kaaba indicator)
          Transform.rotate(
            angle: dialRotation * math.pi / 180,
            child: CustomPaint(
              size: Size(compassSize, compassSize),
              painter: _DialPainter(
                outerRadius: outerRadius,
                appTheme: appTheme,
                qiblaBearing: qiblaBearing,
              ),
            ),
          ),

          // Fixed triangle pointer at top
          Positioned(
            top: 0,
            child: CustomPaint(
              size: const Size(14, 12),
              painter: _TrianglePainter(color: appTheme.accent),
            ),
          ),

          // Fixed diamond needle — cross-fade accent ↔ accentSoft on align
          Positioned(
            top: outerRadius * 0.20,
            child: Stack(
              children: [
                AnimatedOpacity(
                  opacity: isAligned ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 700),
                  child: CustomPaint(
                    size: Size(20, outerRadius * 0.67),
                    painter: _DiamondNeedlePainter(color: appTheme.accent),
                  ),
                ),
                AnimatedOpacity(
                  opacity: isAligned ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 700),
                  child: CustomPaint(
                    size: Size(20, outerRadius * 0.67),
                    painter: _DiamondNeedlePainter(color: appTheme.accentSoft),
                  ),
                ),
              ],
            ),
          ),

          // Center dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: appTheme.bg1,
              border: Border.all(color: appTheme.accent, width: 2),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom painters ──────────────────────────────────────────────────────────

class _CompassBackgroundPainter extends CustomPainter {
  final List<Color> gradientColors;
  final Color borderColor;
  const _CompassBackgroundPainter({
    required this.gradientColors,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final gradientPaint = Paint()
      ..shader = RadialGradient(
        colors: gradientColors,
        stops: const [0.0, 0.20, 0.78, 0.90, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, gradientPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 0.75, borderPaint);
  }

  @override
  bool shouldRepaint(_CompassBackgroundPainter oldDelegate) =>
      oldDelegate.gradientColors != gradientColors;
}

class _DialPainter extends CustomPainter {
  final double outerRadius;
  final AppTheme appTheme;
  final double? qiblaBearing;

  const _DialPainter({
    required this.outerRadius,
    required this.appTheme,
    required this.qiblaBearing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw tick marks every 5 degrees
    for (int tickIndex = 0; tickIndex < 72; tickIndex++) {
      final angleDegrees = tickIndex * 5.0;
      final angleRadians = angleDegrees * math.pi / 180;
      final isMajorTick = angleDegrees % 30 == 0;

      final tickLength = isMajorTick ? 14.0 : 7.0;
      final tickMarginTop = 4.0;
      final tickOpacity = isMajorTick ? 0.7 : 0.35;

      final startOffset = Offset(
        center.dx + (outerRadius - tickMarginTop) * math.sin(angleRadians),
        center.dy - (outerRadius - tickMarginTop) * math.cos(angleRadians),
      );
      final endOffset = Offset(
        center.dx + (outerRadius - tickMarginTop - tickLength) * math.sin(angleRadians),
        center.dy - (outerRadius - tickMarginTop - tickLength) * math.cos(angleRadians),
      );

      final tickPaint = Paint()
        ..color = (isMajorTick ? appTheme.textDim : appTheme.textMute)
            .withValues(alpha: tickOpacity)
        ..strokeWidth = 1.5;
      canvas.drawLine(startOffset, endOffset, tickPaint);
    }

    // Draw degree labels every 30 degrees (skip cardinal positions)
    const cardinalDegrees = [0, 90, 180, 270];
    for (int labelIndex = 0; labelIndex < 12; labelIndex++) {
      final angleDegrees = labelIndex * 30.0;
      if (cardinalDegrees.contains(angleDegrees.toInt())) continue;

      final angleRadians = angleDegrees * math.pi / 180;
      final labelRadius = outerRadius * 0.87;
      final labelCenter = Offset(
        center.dx + labelRadius * math.sin(angleRadians),
        center.dy - labelRadius * math.cos(angleRadians),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: angleDegrees.toInt().toString(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: appTheme.textMute.withValues(alpha: 0.6),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(labelCenter.dx, labelCenter.dy);
      canvas.rotate(angleRadians);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    // Draw cardinal letters N/E/S/W
    const cardinalLabels = ['N', 'E', 'S', 'W'];
    const cardinalAngles = [0.0, 90.0, 180.0, 270.0];
    for (int cardinalIndex = 0; cardinalIndex < 4; cardinalIndex++) {
      final angleDegrees = cardinalAngles[cardinalIndex];
      final angleRadians = angleDegrees * math.pi / 180;
      final labelRadius = outerRadius * 0.87;
      final labelCenter = Offset(
        center.dx + labelRadius * math.sin(angleRadians),
        center.dy - labelRadius * math.cos(angleRadians),
      );

      final isNorth = cardinalIndex == 0;
      final textPainter = TextPainter(
        text: TextSpan(
          text: cardinalLabels[cardinalIndex],
          style: TextStyle(
            fontSize: isNorth ? 14 : 14,
            fontWeight: isNorth ? FontWeight.w700 : FontWeight.w500,
            color: isNorth ? appTheme.accent : appTheme.textDim,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(labelCenter.dx, labelCenter.dy);
      canvas.rotate(angleRadians);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    // Draw Kaaba indicator at qibla bearing
    if (qiblaBearing != null) {
      final bearingRadians = qiblaBearing! * math.pi / 180;
      final kaabaRadius = outerRadius * 0.06;
      final kaabaCenter = Offset(
        center.dx + (outerRadius - kaabaRadius - 2) * math.sin(bearingRadians),
        center.dy - (outerRadius - kaabaRadius - 2) * math.cos(bearingRadians),
      );

      final circlePaint = Paint()
        ..color = appTheme.bg3
        ..style = PaintingStyle.fill;
      canvas.drawCircle(kaabaCenter, kaabaRadius, circlePaint);

      final circleBorderPaint = Paint()
        ..color = appTheme.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(kaabaCenter, kaabaRadius, circleBorderPaint);

      // Cube-outline symbol for Kaaba (isometric hex + 3 inner edges)
      final s = kaabaRadius * 0.52;
      final h = s * 0.88;
      final tM = Offset(kaabaCenter.dx, kaabaCenter.dy - h);
      final tL = Offset(kaabaCenter.dx - s, kaabaCenter.dy - h * 0.28);
      final tR = Offset(kaabaCenter.dx + s, kaabaCenter.dy - h * 0.28);
      final bL = Offset(kaabaCenter.dx - s, kaabaCenter.dy + h * 0.28);
      final bR = Offset(kaabaCenter.dx + s, kaabaCenter.dy + h * 0.28);
      final bM = Offset(kaabaCenter.dx, kaabaCenter.dy + h);
      final cubePaint = Paint()
        ..color = appTheme.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(
        Path()
          ..moveTo(tM.dx, tM.dy)
          ..lineTo(tR.dx, tR.dy)
          ..lineTo(bR.dx, bR.dy)
          ..lineTo(bM.dx, bM.dy)
          ..lineTo(bL.dx, bL.dy)
          ..lineTo(tL.dx, tL.dy)
          ..close(),
        cubePaint,
      );
      canvas.drawLine(tM, kaabaCenter, cubePaint);
      canvas.drawLine(bL, kaabaCenter, cubePaint);
      canvas.drawLine(bR, kaabaCenter, cubePaint);
    }
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) =>
      oldDelegate.qiblaBearing != qiblaBearing ||
      oldDelegate.appTheme.key != appTheme.key;
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) => oldDelegate.color != color;
}

class _DiamondNeedlePainter extends CustomPainter {
  final Color color;
  const _DiamondNeedlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final halfWidth = size.width / 2;
    final topHeight = size.height * 0.4;
    final path = Path()
      ..moveTo(halfWidth, 0)
      ..lineTo(size.width, topHeight)
      ..lineTo(halfWidth, size.height)
      ..lineTo(0, topHeight)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DiamondNeedlePainter oldDelegate) => oldDelegate.color != color;
}

class _CubeIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _CubeIcon({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CubeIconPainter(color: color),
    );
  }
}

class _CubeIconPainter extends CustomPainter {
  final Color color;
  const _CubeIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width * 0.42;
    final h = s * 0.88;

    final tM = Offset(cx, cy - h);
    final tL = Offset(cx - s, cy - h * 0.28);
    final tR = Offset(cx + s, cy - h * 0.28);
    final bL = Offset(cx - s, cy + h * 0.28);
    final bR = Offset(cx + s, cy + h * 0.28);
    final bM = Offset(cx, cy + h);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(
      Path()
        ..moveTo(tM.dx, tM.dy)
        ..lineTo(tR.dx, tR.dy)
        ..lineTo(bR.dx, bR.dy)
        ..lineTo(bM.dx, bM.dy)
        ..lineTo(bL.dx, bL.dy)
        ..lineTo(tL.dx, tL.dy)
        ..close(),
      paint,
    );
    canvas.drawLine(tM, Offset(cx, cy), paint);
    canvas.drawLine(bL, Offset(cx, cy), paint);
    canvas.drawLine(bR, Offset(cx, cy), paint);
  }

  @override
  bool shouldRepaint(_CubeIconPainter old) => old.color != color;
}
