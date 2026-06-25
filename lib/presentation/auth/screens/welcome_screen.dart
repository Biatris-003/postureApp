import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_screen.dart'; // ✅ Import AuthScreen

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  // ── Breathe animation (subtle pulse: 1.0 → 1.07 → 1.0) ──────────────
  late final AnimationController _breatheCtrl;
  late final Animation<double> _breatheAnim;

  // ── Fill animation (image expands to cover full screen) ───────────────
  late final AnimationController _fillCtrl;
  late final Animation<double> _fillAnim;

  // When true, the image covers the full screen and we show no text
  bool _filling = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    // Breathe: 500 ms ease-in-out, plays once forward then reverse
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _breatheAnim = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut),
    );

    // Fill: 900 ms — image scale grows from 1.0 to a value large enough
    // to guarantee every corner is covered regardless of screen size.
    _fillCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fillAnim = Tween<double>(begin: 1.0, end: 30.0).animate(
      CurvedAnimation(parent: _fillCtrl, curve: Curves.easeIn),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // 1. Hold still for 1 second
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    // 2. Breathe out (scale up slightly)
    await _breatheCtrl.forward();
    if (!mounted) return;

    // 3. Breathe in (scale back to 1)
    await _breatheCtrl.reverse();
    if (!mounted) return;

    // 4. Hold for 1 more second
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    // 5. Fill the screen
    setState(() => _filling = true);
    await _fillCtrl.forward();
    if (!mounted) return;

    // 6. Navigate to AuthScreen - no transition animation
    await Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => const AuthScreen(), // ✅ Go to AuthScreen
      ),
    );
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    _fillCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── White page background — always visible ─────────────────────
          const SizedBox.expand(),

          // ── Animated image — centered, expands outward ─────────────────
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_breatheCtrl, _fillCtrl]),
              builder: (context, child) {
                final scale = _filling
                    ? _fillAnim.value
                    : _breatheAnim.value;

                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: Image.asset(
                'assets/images/homePage/back_view.png',
                height: 320,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // ── Text block — fades out as fill begins ──────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedOpacity(
              opacity: _filling ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 0, 30, 60),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Smart Posture',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF35506E),
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Empowering your spine health with AI',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF748094),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}