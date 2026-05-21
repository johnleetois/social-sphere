import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IntroScreen — animated lamp pull-cord get-started screen
// Colors derived from the Social Sphere logo: cyan #00CFFF, purple #8B3CFF,
// pink #FF52A2 on dark navy #0A0A1A.
// ─────────────────────────────────────────────────────────────────────────────

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  // Idle ambient glow pulse
  late final AnimationController _glowController;

  double _pullOffset = 0.0;
  bool _isActivated = false;
  bool _eyesClosed = false;

  static const double _maxPull = 120.0;
  static const double _activationThreshold = 82.0;

  // ── Theme colours ──────────────────────────────────────────────────────────
  static const Color _cyan = Color(0xFF00CFFF);
  static const Color _purple = Color(0xFF8B3CFF);
  static const Color _pink = Color(0xFFFF52A2);
  static const Color _darkBg = Color(0xFF0A0A1A);
  static const Color _deepPurple = Color(0xFF1A0A3A);

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _scheduleBlink();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  // ── Blink loop ─────────────────────────────────────────────────────────────
  void _scheduleBlink() async {
    await Future.delayed(
        Duration(milliseconds: 2200 + Random().nextInt(3000)));
    if (!mounted || _isActivated) return;
    setState(() => _eyesClosed = true);
    await Future.delayed(const Duration(milliseconds: 110));
    if (!mounted) return;
    setState(() => _eyesClosed = false);
    _scheduleBlink();
  }

  // ── Drag handlers ──────────────────────────────────────────────────────────
  void _onDragUpdate(DragUpdateDetails d) {
    if (_isActivated) return;
    setState(() {
      _pullOffset = (_pullOffset + d.delta.dy).clamp(0.0, _maxPull);
    });
  }

  void _onDragEnd(DragEndDetails _) async {
    if (_isActivated) return;
    if (_pullOffset >= _activationThreshold) {
      await _activate();
    } else {
      _springBack();
    }
  }

  // Elastic spring-back when cord is released without enough pull
  void _springBack() async {
    final start = _pullOffset;
    const steps = 28;
    for (int i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted || _isActivated) return;
      final t = i / steps;
      final decay = pow(2.0, -9.0 * t).toDouble();
      final oscillation = cos(t * pi * 4.5);
      final elastic = 1.0 - decay * oscillation;
      setState(() => _pullOffset = (start * (1.0 - elastic)).clamp(0.0, _maxPull));
    }
    if (mounted) setState(() => _pullOffset = 0.0);
  }

  // Full pull → navigate to login
  Future<void> _activate() async {
    setState(() => _isActivated = true);
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, anim, secondaryAnimation, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  double get _pullProgress => (_pullOffset / _maxPull).clamp(0.0, 1.0);

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: AnimatedBuilder(
        animation: _glowController,
        builder: (context, _) => Stack(
          children: [
            _buildBackground(),
            SafeArea(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    final ambient = _isActivated
        ? 0.9
        : 0.12 + _glowController.value * 0.12 + _pullProgress * 0.6;

    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.25),
          radius: 1.35,
          colors: [_deepPurple, _darkBg],
        ),
      ),
      child: Stack(
        children: [
          // Soft ambient light cone behind the lamp
          Align(
            alignment: const Alignment(0, -0.15),
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color.fromRGBO(0, 207, 255, ambient * 0.28),
                    Color.fromRGBO(139, 60, 255, ambient * 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Subtle floor glow
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color.fromRGBO(139, 60, 255, ambient * 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        const SizedBox(height: 48),

        // ── App brand ────────────────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.asset(
            'assets/logo.png',
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [_cyan, _purple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.bubble_chart_rounded,
                  color: Colors.white, size: 36),
            ),
          ),
        ),

        const SizedBox(height: 14),

        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [_cyan, _purple, _pink],
          ).createShader(b),
          child: const Text(
            "Social Sphere",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),

        const SizedBox(height: 4),

        Text(
          "Connect. Share. Belong.",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.38),
            fontSize: 12,
            letterSpacing: 2.2,
          ),
        ),

        const Spacer(flex: 1),

        // ── Lamp + cord (gesture zone) ────────────────────────────────────
        Center(
          child: GestureDetector(
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: _buildLamp(),
          ),
        ),

        const SizedBox(height: 28),

        // ── Pull hint ─────────────────────────────────────────────────────
        AnimatedOpacity(
          opacity: _isActivated ? 0.0 : (1.0 - _pullProgress * 0.7),
          duration: const Duration(milliseconds: 200),
          child: Column(
            children: [
              // Bouncing arrow
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeInOut,
                builder: (_, v, child) => Transform.translate(
                  offset: Offset(0, sin(v * pi * 2) * 4),
                  child: child,
                ),
                onEnd: () => setState(() {}), // retrigger
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _purple.withValues(alpha: 0.65),
                  size: 26,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "pull the lamp cord",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.30),
                  fontSize: 11,
                  letterSpacing: 2.8,
                ),
              ),
            ],
          ),
        ),

        const Spacer(flex: 1),
      ],
    );
  }

  // ── Lamp widget ────────────────────────────────────────────────────────────
  Widget _buildLamp() {
    final glow = _isActivated
        ? 1.0
        : 0.18 + _glowController.value * 0.14 + _pullProgress * 0.68;

    // Layout (top→bottom):
    //   shade        : 0   → 105  (h=105)
    //   light cone   : 90  → 230  (h=140, overlaps)
    //   pole         : 100 → 285  (h=185)
    //   base         : 282 → 302  (h=20)
    //   cord         : starts at 66, extends down by _pullOffset
    const double lampH = 310.0;
    final double totalH = lampH + _pullOffset + 18;

    return SizedBox(
      width: 210,
      height: totalH,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // ── Light cone ──────────────────────────────────────────────────
          Positioned(
            top: 90,
            left: 10,
            child: CustomPaint(
              size: const Size(190, 195),
              painter: _LightConePainter(glowStrength: glow),
            ),
          ),

          // ── Shade ───────────────────────────────────────────────────────
          Positioned(
            top: 0,
            child: _buildShade(glow),
          ),

          // ── Pole ────────────────────────────────────────────────────────
          Positioned(
            top: 100,
            left: 102,
            child: Container(
              width: 6,
              height: 184,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF1E1040),
                    Color(0xFF3A2A7A),
                    Color(0xFF1E1040),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _purple.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),

          // ── Base ────────────────────────────────────────────────────────
          Positioned(
            top: 284,
            child: Container(
              width: 124,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF2A1A5A),
                    Color(0xFF1A0A3A),
                    Color(0xFF2A1A5A),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _purple.withValues(alpha: 0.35),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          // ── Pull cord ───────────────────────────────────────────────────
          Positioned(
            top: 66,
            left: 136,
            child: _buildCord(),
          ),
        ],
      ),
    );
  }

  Widget _buildShade(double glow) {
    final eyeColor = Color.lerp(const Color(0xFF3A2A7A), _cyan, glow)!;

    return SizedBox(
      width: 150,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow halo
          Container(
            width: 150,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(0, 207, 255, glow * 0.55),
                  blurRadius: 42,
                  spreadRadius: 8,
                ),
                BoxShadow(
                  color: Color.fromRGBO(139, 60, 255, glow * 0.32),
                  blurRadius: 24,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),

          // Shade body
          CustomPaint(
            size: const Size(134, 98),
            painter: _LampShadePainter(glowStrength: glow),
          ),

          // ── Cute face ──────────────────────────────────────────────────
          Positioned(
            bottom: 12,
            child: _buildFace(eyeColor, glow),
          ),
        ],
      ),
    );
  }

  Widget _buildFace(Color eyeColor, double glow) {
    // Eyes + smile laid horizontally
    return SizedBox(
      width: 68,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left eye
          Positioned(left: 6, top: 2, child: _buildEye(eyeColor)),
          // Right eye
          Positioned(right: 6, top: 2, child: _buildEye(eyeColor)),
          // Smile
          Positioned(
            bottom: 0,
            child: CustomPaint(
              size: const Size(22, 9),
              painter: _SmilePainter(
                color: Color.lerp(_cyan, _pink, glow * 0.7)!,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEye(Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      width: 9,
      height: _eyesClosed ? 1.5 : 9,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.85),
            blurRadius: 9,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildCord() {
    final cordColor = Color.lerp(const Color(0xFF5A3A9A), _pink, _pullProgress)!;
    final cordLength = 28.0 + _pullOffset;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cord rope
        Container(
          width: 3,
          height: cordLength,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [const Color(0xFF4A2A8A), cordColor],
            ),
            boxShadow: [
              BoxShadow(
                color: cordColor.withValues(alpha: 0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        // Pull knob
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cordColor,
            boxShadow: [
              BoxShadow(
                color: cordColor.withValues(alpha: 0.75),
                blurRadius: 12,
                spreadRadius: 3,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom painters
// ─────────────────────────────────────────────────────────────────────────────

class _LampShadePainter extends CustomPainter {
  final double glowStrength;
  const _LampShadePainter({required this.glowStrength});

  @override
  void paint(Canvas canvas, Size size) {
    // Shade body (trapezoid with curved bottom)
    final path = Path()
      ..moveTo(size.width * 0.20, 0)
      ..lineTo(size.width * 0.80, 0)
      ..lineTo(size.width, size.height * 0.86)
      ..quadraticBezierTo(
          size.width * 0.5, size.height + 4, 0, size.height * 0.86)
      ..close();

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(
              const Color(0xFF1E1040), const Color(0xFF00CFFF), glowStrength * 0.75)!,
          Color.lerp(
              const Color(0xFF2A1A5A), const Color(0xFF8B3CFF), glowStrength * 0.55)!,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, bodyPaint);

    // Inner bright highlight
    if (glowStrength > 0.08) {
      final hlPaint = Paint()
        ..color = Color.fromRGBO(0, 207, 255, glowStrength * 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      final hlPath = Path()
        ..moveTo(size.width * 0.28, size.height * 0.08)
        ..lineTo(size.width * 0.72, size.height * 0.08)
        ..lineTo(size.width * 0.68, size.height * 0.54)
        ..lineTo(size.width * 0.32, size.height * 0.54)
        ..close();
      canvas.drawPath(hlPath, hlPaint);
    }

    // Outline rim
    final rimPaint = Paint()
      ..color = Color.fromRGBO(0, 207, 255, 0.12 + glowStrength * 0.48)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, rimPaint);

    // Top mounting bar
    final barPaint = Paint()
      ..color = const Color(0xFF8B3CFF).withValues(alpha: 0.65)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.20, 2.5),
      Offset(size.width * 0.80, 2.5),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(_LampShadePainter old) =>
      old.glowStrength != glowStrength;
}

class _LightConePainter extends CustomPainter {
  final double glowStrength;
  const _LightConePainter({required this.glowStrength});

  @override
  void paint(Canvas canvas, Size size) {
    if (glowStrength < 0.05) return;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.fromRGBO(0, 207, 255, glowStrength * 0.20),
          Color.fromRGBO(139, 60, 255, glowStrength * 0.07),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(size.width * 0.34, 0)
      ..lineTo(size.width * 0.66, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LightConePainter old) =>
      old.glowStrength != glowStrength;
}

class _SmilePainter extends CustomPainter {
  final Color color;
  const _SmilePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(size.width / 2, size.height, size.width, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SmilePainter old) => old.color != color;
}
