import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/routing/route_names.dart';
import '../../widgets/play/play.dart';

/// The first six seconds of Little Learners.
///
/// A koala skates in, the name lands block by block, and a star rolls along a
/// loading track. Then it hands over to the welcome screen.
///
/// Everything on it is on one clock, and everything except the koala is
/// drawn rather than animated by widgets — a scrolling road, drifting clouds,
/// sparkles. That keeps a screen this busy cheap enough for the phones this
/// app is actually for.
///
/// A tap skips it. That also unlocks web audio a screen earlier than the
/// welcome button would.
class IntroSplashPage extends StatefulWidget {
  const IntroSplashPage({super.key});

  /// How long a family looks at this before the app moves on.
  static const hold = Duration(seconds: 6);

  @override
  State<IntroSplashPage> createState() => _IntroSplashPageState();
}

class _IntroSplashPageState extends State<IntroSplashPage>
    with TickerProviderStateMixin {
  /// The world clock: the road, the clouds, the sparkles.
  late final AnimationController _world = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  /// The arrival: the koala skating on, the name landing, the tagline
  /// popping. Deliberately not tied to [IntroSplashPage.hold] — stretching
  /// the choreography to fill six seconds would make the entrance sluggish,
  /// which is the opposite of the point. It lands in well under a second and
  /// then the scene simply lives.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  /// The loading bar, which does run the full hold. It is the one thing on
  /// screen making a promise, so it has to keep it: when the star reaches the
  /// end, the app moves on.
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: IntroSplashPage.hold,
  )..forward();

  Timer? _handover;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _handover = Timer(IntroSplashPage.hold, _goToWelcome);
  }

  @override
  void dispose() {
    _handover?.cancel();
    _world.dispose();
    _entrance.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _goToWelcome() {
    if (_leaving || !mounted) return;
    _leaving = true;
    Navigator.of(context).pushReplacementNamed(RouteNames.splash);
  }

  @override
  Widget build(BuildContext context) {
    final calm = PlayMotion.reduced(context);
    if (calm && _world.isAnimating) _world.stop();

    return Scaffold(
      backgroundColor: PlayColors.sky,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _goToWelcome,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _world,
                builder: (context, _) => CustomPaint(
                  painter: _SkyPainter(t: calm ? 0 : _world.value),
                  size: Size.infinite,
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 660;

                  return Column(
                    children: [
                      SizedBox(height: constraints.maxHeight * 0.07),
                      _Wordmark(entrance: _entrance, compact: compact),
                      SizedBox(height: compact ? 6 : 12),
                      _Tagline(entrance: _entrance),
                      Expanded(
                        child: _Skater(
                          entrance: _entrance,
                          world: _world,
                          calm: calm,
                        ),
                      ),
                      SizedBox(height: compact ? 10 : 18),
                      _LoadingTrack(progress: _progress),
                      SizedBox(height: constraints.maxHeight * 0.06),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The koala, on a board, on a road that moves under it.
///
/// The road is drawn inside this widget rather than against the screen, and
/// both it and the artwork are measured from the same bottom edge. That is
/// what keeps the wheels on the tarmac at every screen size — pinning the road
/// to a fraction of the screen instead left the koala hovering about forty
/// pixels above it on a tall phone.
///
/// The artwork is an animated GIF, not a Lottie. The Lottie of this same clip
/// was 441 vector paths redrawn every frame, and on the client's browser it
/// arrived half-drawn and then stalled. A GIF is decoded a frame at a time by
/// the platform's own image codec: far cheaper, and one less thing between the
/// file and the screen. The cost is resolution — the source is 150x132 — so
/// [artHeight] caps how far it is ever stretched.
class _Skater extends StatelessWidget {
  const _Skater({
    required this.entrance,
    required this.world,
    required this.calm,
  });

  final Animation<double> entrance;
  final Animation<double> world;
  final bool calm;

  /// How deep the tarmac is, measured up from the bottom of this box.
  static const roadHeight = 76.0;

  /// The source GIF's own proportions.
  static const aspect = 150 / 132;

  /// Ceiling on the drawn height, and so on the upscale: at 300 the picture is
  /// stretched about 2.3x, which a flat cartoon carries and a photograph would
  /// not.
  static const artHeight = 300.0;

  /// The GIF's canvas is slightly taller than its ink — the lowest pixel of
  /// the wheels sits this fraction of the height above the bottom edge.
  /// Measured off the file rather than guessed, which is what lets the wheels
  /// land on the road at any size.
  static const inkBottomFraction = 0.083;

  /// How far the wheels bite into the tarmac. A few pixels of overlap reads as
  /// contact; a perfect tangent reads as hovering.
  static const bite = 6.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: world,
            builder: (context, _) => CustomPaint(
              painter: _GroundPainter(
                t: calm ? 0 : world.value,
                roadHeight: roadHeight,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            var height = math.min(artHeight, constraints.maxHeight - 16);
            final widest = constraints.maxWidth - 24;
            if (height * aspect > widest) height = widest / aspect;
            height = height.clamp(120.0, artHeight);

            // Sit the artwork so its lowest ink lands on the road surface.
            final lift = math.max(
              0.0,
              roadHeight - height * inkBottomFraction - bite,
            );

            return Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: lift),
                child: AnimatedBuilder(
                  animation: Listenable.merge([entrance, world]),
                  child: SizedBox(
                    width: height * aspect,
                    height: height,
                    child: _art(),
                  ),
                  builder: (context, child) {
                    // Skates in from the left over the first four tenths of a
                    // second, then settles into a gentle bob as if the road
                    // were uneven.
                    final arrive = Curves.easeOutCubic.transform(
                      (entrance.value / 0.28).clamp(0.0, 1.0),
                    );
                    final bob = calm
                        ? 0.0
                        : math.sin(world.value * math.pi * 6) * 3 * arrive;

                    return Transform.translate(
                      offset: Offset(-320 * (1 - arrive), bob),
                      child: Transform.rotate(
                        // Leans forward on the way in, straightens on arrival.
                        angle: -0.16 * (1 - arrive),
                        child: child,
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _art() {
    const still = Image(
      image: AssetImage('assets/animations/koala-skate-still.png'),
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.medium,
    );

    // Reduced motion gets the still. A GIF has no controller to pause, and an
    // endless loop is the exact thing that setting asks us not to draw.
    if (calm) return still;

    return Image.asset(
      'assets/animations/koala-skate.gif',
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      // The source is small, so it is always being enlarged. Bilinear keeps
      // that soft instead of blocky.
      filterQuality: FilterQuality.medium,
      // 800-odd KB has to arrive before the first frame can. Until it does,
      // show the still — it is the GIF's own frame zero, so the swap is
      // invisible and the screen is never empty.
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return still;
      },
      // A picture that will not load must not take the app's first screen
      // with it. The name still lands and the timer still moves on.
      errorBuilder: (context, error, stack) => const SizedBox.shrink(),
    );
  }
}

/// LITTLE LEARNERS, as two blocks that drop in and bounce.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.entrance, required this.compact});

  final Animation<double> entrance;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WordBlock(
          text: 'LITTLE',
          color: PlayColors.sunshine,
          textColor: PlayColors.ink,
          rotation: -0.04,
          delay: 0.04,
          entrance: entrance,
          fontSize: compact ? 40 : 50,
        ),
        SizedBox(height: compact ? 6 : 10),
        _WordBlock(
          text: 'LEARNERS',
          color: PlayColors.strawberry,
          textColor: Colors.white,
          rotation: 0.03,
          delay: 0.14,
          entrance: entrance,
          fontSize: compact ? 34 : 43,
        ),
      ],
    );
  }
}

class _WordBlock extends StatelessWidget {
  const _WordBlock({
    required this.text,
    required this.color,
    required this.textColor,
    required this.rotation,
    required this.delay,
    required this.entrance,
    required this.fontSize,
  });

  final String text;
  final Color color;
  final Color textColor;
  final double rotation;
  final double delay;
  final Animation<double> entrance;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final block = Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.42, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(PlayMotion.radiusLarge),
        border: Border.all(color: Colors.white, width: 5),
        boxShadow: [
          BoxShadow(
            color: PlayColors.ink.withValues(alpha: 0.26),
            offset: const Offset(0, 7),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: fontSize,
          height: 1.05,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: textColor,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: entrance,
      child: block,
      builder: (context, child) {
        // Drops from above and overshoots, the way a wooden block lands.
        final t = Curves.elasticOut.transform(
          ((entrance.value - delay) / 0.36).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -70 * (1 - t)),
            child: Transform.rotate(angle: rotation * t, child: child),
          ),
        );
      },
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline({required this.entrance});

  final Animation<double> entrance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: entrance,
      builder: (context, _) {
        final t = Curves.easeOutBack.transform(
          ((entrance.value - 0.26) / 0.3).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.7 + 0.3 * t,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: PlayColors.ink.withValues(alpha: 0.16),
                    offset: const Offset(0, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: const Text(
                'Play, learn and grow together',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: PlayColors.grape,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The loading bar, with a star rolling along the front of the fill.
///
/// Tied to the same three seconds the screen lasts, so it is telling the
/// truth: when the star reaches the end, the app moves on.
class _LoadingTrack extends StatelessWidget {
  const _LoadingTrack({required this.progress});

  final Animation<double> progress;

  static const _height = 22.0;
  static const _star = 40.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 42),
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final filled = progress.value.clamp(0.0, 1.0);

          return Column(
            children: [
              SizedBox(
                height: _star,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: (_star - _height) / 2,
                          child: Container(
                            height: _height,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.42),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: (_star - _height) / 2,
                          child: Container(
                            height: _height,
                            width: (width * filled).clamp(0.0, width),
                            decoration: BoxDecoration(
                              color: PlayColors.sunshine,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        Positioned(
                          left: (width * filled - _star / 2)
                              .clamp(-_star / 4, width - _star / 2),
                          top: 0,
                          child: Transform.rotate(
                            // Rolls as it travels, like a wheel.
                            angle: filled * math.pi * 4,
                            child: Container(
                              width: _star,
                              height: _star,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: PlayColors.ink
                                        .withValues(alpha: 0.22),
                                    offset: const Offset(0, 3),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.star_rounded,
                                size: 26,
                                color: PlayColors.sunshine,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Getting ready...',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Sky, sun, drifting clouds and sparkles. Everything above the hills.
class _SkyPainter extends CustomPainter {
  const _SkyPainter({required this.t});

  /// Loops 0 to 1. Everything that moves is a function of it.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSun(canvas, size);
    _paintSparkles(canvas, size);
    _paintClouds(canvas, size);
  }

  void _paintSun(Canvas canvas, Size size) {
    final centre = Offset(size.width * 0.85, size.height * 0.09);

    // Rays turn slowly. It is the only thing in the sky that gives the screen
    // any sense of time passing.
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(t * math.pi / 4);
    final ray = Paint()..color = PlayColors.sunshine.withValues(alpha: 0.42);
    for (var i = 0; i < 8; i++) {
      canvas.rotate(math.pi / 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(34, -4, 22, 8),
          const Radius.circular(4),
        ),
        ray,
      );
    }
    canvas.restore();

    canvas.drawCircle(centre, 30, Paint()..color = PlayColors.sunshine);
    canvas.drawCircle(
      centre,
      30,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  void _paintSparkles(Canvas canvas, Size size) {
    final random = math.Random(9052026);
    final paint = Paint();
    for (var i = 0; i < 16; i++) {
      final cx = random.nextDouble() * size.width;
      final cy = random.nextDouble() * size.height * 0.55;
      final phase = random.nextDouble();
      final wave = math.sin((t + phase) * math.pi * 2);
      paint.color = Colors.white.withValues(
        alpha: (0.18 + 0.5 * ((wave + 1) / 2)).clamp(0.0, 1.0),
      );
      final r = (2.5 + random.nextDouble() * 3) * (0.7 + 0.3 * wave.abs());
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  void _paintClouds(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.92);
    // Three clouds at different depths, each wrapping around the screen so
    // the sky never runs out.
    const clouds = <(double, double, double, double)>[
      (0.16, 0.13, 1.0, 0.30),
      (0.60, 0.24, 0.72, 0.46),
      (0.88, 0.07, 0.85, 0.20),
    ];

    for (final (startX, y, scale, speed) in clouds) {
      final x = ((startX - t * speed) % 1.4 - 0.2) * size.width;
      _paintCloud(canvas, Offset(x, size.height * y), 34 * scale, paint);
    }
  }

  void _paintCloud(Canvas canvas, Offset at, double r, Paint paint) {
    canvas.drawCircle(at, r, paint);
    canvas.drawCircle(at.translate(r * 0.85, r * 0.18), r * 0.75, paint);
    canvas.drawCircle(at.translate(-r * 0.85, r * 0.22), r * 0.66, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(at.dx - r * 1.5, at.dy + r * 0.1, r * 3, r * 0.9),
        Radius.circular(r * 0.45),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) => oldDelegate.t != t;
}

/// Hills and the road, drawn in the skater's own box so the wheels land on
/// the tarmac rather than near it.
class _GroundPainter extends CustomPainter {
  const _GroundPainter({required this.t, required this.roadHeight});

  final double t;
  final double roadHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final roadTop = size.height - roadHeight;

    void hill(double offset, double height, Color color, double speed) {
      final path = Path()..moveTo(-size.width, roadTop);
      final shift = (t * speed * size.width) % (size.width / 2);
      for (var x = -size.width; x <= size.width * 2; x += size.width / 2) {
        path.quadraticBezierTo(
          x + size.width / 4 - shift + offset,
          roadTop - height,
          x + size.width / 2 - shift + offset,
          roadTop,
        );
      }
      path
        ..lineTo(size.width * 2, size.height)
        ..lineTo(-size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    hill(0, 84, PlayColors.grass.withValues(alpha: 0.5), 0.10);
    hill(size.width * 0.22, 54, PlayColors.grass, 0.18);

    // The tarmac.
    canvas.drawRect(
      Rect.fromLTRB(0, roadTop, size.width, size.height),
      Paint()..color = PlayColors.ink.withValues(alpha: 0.86),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, roadTop, size.width, 6),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );

    // Dashes running to the left, which is what sells the skating.
    final dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke;
    const spacing = 68.0;
    final shift = (t * spacing * 4) % spacing;
    final y = roadTop + roadHeight * 0.55;
    for (var x = -spacing; x < size.width + spacing; x += spacing) {
      final start = x - shift;
      canvas.drawLine(Offset(start, y), Offset(start + 34, y), dash);
    }
  }

  @override
  bool shouldRepaint(covariant _GroundPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.roadHeight != roadHeight;
}
