import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/auth_flow_router.dart';
import '../../core/routing/route_names.dart';
import '../../models/parent_account.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/play/play.dart';

/// The first thing a family sees.
///
/// The illustration stays — it is the brand, and it is already artwork for
/// children rather than a stock gradient. Everything sitting on top of it is
/// now built from the play kit, so the very first screen already looks like
/// the app a child ends up in.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  ParentAccount? _parent;
  bool _isCheckingSession = true;

  /// One controller for the whole screen.
  ///
  /// Everything that moves here — the koala, the badge, the sparkles, the
  /// button — reads from this single clock. A controller per element is what
  /// makes a screen like this stutter on a cheap phone.
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSession());
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final auth = context.read<AuthViewModel>();
    await auth.loadCurrentParent();
    if (!mounted) return;

    setState(() {
      _parent = auth.parent;
      _isCheckingSession = false;
    });
  }

  Future<void> _continue() async {
    final parent = _parent;
    if (parent == null) {
      Navigator.of(context).pushReplacementNamed(RouteNames.login);
      return;
    }

    await AuthFlowRouter.routeAfterAuth(context: context, parent: parent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/splash/little_learners_splash.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          if (!PlayMotion.reduced(context))
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _life,
                  builder: (context, _) => CustomPaint(
                    painter: _SparklePainter(progress: _life.value),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 650;
                final calm = PlayMotion.reduced(context);
                final topSpace =
                    constraints.maxHeight * (compact ? 0.25 : 0.27);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    children: [
                      SizedBox(height: topSpace),
                      PopIn(
                        index: 0,
                        child: _Drift(
                          clock: _life,
                          calm: calm,
                          // A slow rock, like a shop sign in a breeze.
                          rotate: 0.018,
                          rise: 3,
                          child: _BrandBadge(compact: compact),
                        ),
                      ),
                      SizedBox(height: compact ? 10 : 14),
                      PopIn(
                        index: 1,
                        child: _Drift(
                          clock: _life,
                          calm: calm,
                          phase: 0.35,
                          rise: 4,
                          child: _Tagline(compact: compact),
                        ),
                      ),
                      SizedBox(height: compact ? 12 : 18),
                      PopIn(
                        index: 2,
                        child: _Drift(
                          clock: _life,
                          calm: calm,
                          phase: 0.6,
                          rise: 8,
                          rotate: 0.03,
                          child: _SplashKoala(compact: compact),
                        ),
                      ),
                      const Spacer(),
                      FractionallySizedBox(
                        widthFactor: compact ? 0.9 : 0.8,
                        child: _Breathe(
                          clock: _life,
                          calm: calm || _isCheckingSession,
                          child: PlayButton(
                            key: const ValueKey('splash-continue-button'),
                            icon: Icons.arrow_forward_rounded,
                            // The label stays put while the session check runs.
                            // Swapping it for "One moment..." made the first
                            // word a family sees flicker for no reason.
                            label: _parent == null
                              ? 'Get started'
                              : 'Continue learning',
                            color: PlayColors.sunshine,
                            textColor: PlayColors.ink,
                            // Not `big`: the Column has fixed spacing and a
                            // Spacer, so a 96px button overflows it on a short
                            // screen. 72px is still well up from the 58px this
                            // used to be.
                            onPressed: _isCheckingSession ? null : _continue,
                          ),
                        ),
                      ),
                      SizedBox(
                        height:
                            constraints.maxHeight * (compact ? 0.06 : 0.095),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The koala, in the same white disc it wears on the auth screens.
class _SplashKoala extends StatelessWidget {
  const _SplashKoala({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 86.0 : 112.0;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: PlayColors.ink.withValues(alpha: 0.22),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/koala/koala_guide_portrait.png',
        height: size * 0.86,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// "Play, learn and grow together", on its own slab so it reads against
/// whatever part of the illustration lands behind it.
class _Tagline extends StatelessWidget {
  const _Tagline({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: PlayColors.card,
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
      child: Text(
        'Play, learn and grow together',
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Fredoka',
          color: PlayColors.strawberry,
          fontSize: compact ? 17 : 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Little Learners',
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: EdgeInsets.symmetric(
          horizontal: 26,
          vertical: compact ? 14 : 18,
        ),
        decoration: BoxDecoration(
          color: PlayColors.lime,
          // 34px, like every other surface in the app. The 8px corners here
          // were the giveaway that this screen predated the play kit.
          borderRadius: BorderRadius.circular(PlayMotion.radiusLarge),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: PlayColors.ink.withValues(alpha: 0.24),
              offset: const Offset(0, 7),
              blurRadius: 0,
            ),
          ],
        ),
        child: ExcludeSemantics(
          child: Text(
            'LITTLE\nLEARNERS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Fredoka',
              color: PlayColors.ink,
              fontSize: compact ? 30 : 36,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// A slow float and rock, driven by the screen's shared clock.
///
/// Layout is untouched — this is a [Transform], so nothing above or below it
/// moves. That matters here: the splash Column has fixed spacing and a Spacer,
/// and anything that changed height would put it back over the edge on a
/// short phone.
class _Drift extends StatelessWidget {
  const _Drift({
    required this.clock,
    required this.child,
    required this.calm,
    this.phase = 0,
    this.rise = 6,
    this.rotate = 0,
  });

  final Animation<double> clock;
  final Widget child;

  /// Reduced motion, or nothing worth moving for yet.
  final bool calm;

  /// Offsets this element on the shared clock, so the screen breathes rather
  /// than pulsing in unison.
  final double phase;

  /// How far it floats, in logical pixels.
  final double rise;

  /// How far it rocks, in radians.
  final double rotate;

  @override
  Widget build(BuildContext context) {
    if (calm) return child;

    return AnimatedBuilder(
      animation: clock,
      child: child,
      builder: (context, child) {
        final t = (clock.value + phase) * math.pi * 2;
        return Transform.translate(
          offset: Offset(0, math.sin(t) * rise),
          child: Transform.rotate(
            angle: math.sin(t * 0.5) * rotate,
            child: child,
          ),
        );
      },
    );
  }
}

/// A gentle swell on the one thing there is to press.
class _Breathe extends StatelessWidget {
  const _Breathe({
    required this.clock,
    required this.child,
    required this.calm,
  });

  final Animation<double> clock;
  final Widget child;
  final bool calm;

  @override
  Widget build(BuildContext context) {
    if (calm) return child;

    return AnimatedBuilder(
      animation: clock,
      child: child,
      builder: (context, child) {
        final t = clock.value * math.pi * 2;
        // Small on purpose. A button that pumps is a button that nags.
        return Transform.scale(scale: 1 + math.sin(t) * 0.02, child: child);
      },
    );
  }
}

/// Sparkles over the illustration, twinkling out of step with each other.
///
/// Fixed positions from a fixed seed, so they sit in the same places every
/// time rather than jittering around on each frame.
class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.progress});

  final double progress;

  static const _count = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(20260904);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < _count; i++) {
      final cx = random.nextDouble() * size.width;
      // Kept to the top two thirds, clear of the badge, the koala and the
      // button.
      final cy = random.nextDouble() * size.height * 0.62;
      final radius = 3.0 + random.nextDouble() * 5;
      final phase = random.nextDouble();

      final wave = math.sin((progress + phase) * math.pi * 2);
      final opacity = (0.15 + 0.55 * ((wave + 1) / 2)).clamp(0.0, 1.0);
      final scale = 0.65 + 0.35 * ((wave + 1) / 2);

      paint.color = Colors.white.withValues(alpha: opacity);
      _drawSparkle(canvas, Offset(cx, cy), radius * scale, paint);
    }
  }

  /// A four-point star: two tapered diamonds crossed. Reads as a twinkle at a
  /// few pixels across, where a circle just reads as a dot.
  void _drawSparkle(Canvas canvas, Offset centre, double radius, Paint paint) {
    final waist = radius * 0.26;
    final path = Path()
      ..moveTo(centre.dx, centre.dy - radius)
      ..quadraticBezierTo(
          centre.dx + waist, centre.dy - waist, centre.dx + radius, centre.dy)
      ..quadraticBezierTo(
          centre.dx + waist, centre.dy + waist, centre.dx, centre.dy + radius)
      ..quadraticBezierTo(
          centre.dx - waist, centre.dy + waist, centre.dx - radius, centre.dy)
      ..quadraticBezierTo(
          centre.dx - waist, centre.dy - waist, centre.dx, centre.dy - radius)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
