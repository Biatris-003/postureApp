import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/session_provider.dart';

const Map<int, String> postureImages = {
  1: 'assets/images/monitoring/backward.png',
  2: 'assets/images/monitoring/upright.png',
  3: 'assets/images/monitoring/slouching.png',
  4: 'assets/images/monitoring/forward.png',
  5: 'assets/images/monitoring/right.png',
  6: 'assets/images/monitoring/left.png',
};

class MonitoringTab extends ConsumerStatefulWidget {
  const MonitoringTab({super.key});

  @override
  ConsumerState<MonitoringTab> createState() => _MonitoringTabState();
}

class _MonitoringTabState extends ConsumerState<MonitoringTab>
    with SingleTickerProviderStateMixin {
  Timer? _clockTimer;
  late AnimationController _streakPopController;
  late Animation<double> _streakPopAnim;
  bool _streakPopFired = false;

  static const Color kGreen = Color(0xFF10B981);
  static const Color kRed   = Color(0xFFEF4444);
  static const Color kAmber = Color(0xFFF59E0B);
  static const Color kBlue  = Color(0xFF3B82F6);

  @override
  void initState() {
    super.initState();
    _streakPopController = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );
    _streakPopAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 65,
      ),
    ]).animate(_streakPopController);

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final session = ref.read(sessionProvider);
      if (session.currentStreakStart != null && !_streakPopFired) {
        final live =
            DateTime.now().difference(session.currentStreakStart!).inSeconds;
        if (live > session.bestStreakSeconds && session.bestStreakSeconds > 0) {
          _streakPopFired = true;
          _streakPopController.forward(from: 0);
        }
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _streakPopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    ref.listen<SessionState>(sessionProvider, (prev, next) {
      if (prev?.currentStreakStart == null && next.currentStreakStart != null) {
        _streakPopFired = false;
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: switch (session.status) {
          SessionStatus.idle     => _buildIdle(context),
          SessionStatus.starting => _buildStarting(context),
          SessionStatus.active   => _buildActive(context, session),
        },
      ),
    );
  }

  // ─── Idle ─────────────────────────────────────────────────────────────────

  Widget _buildIdle(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sensors, size: 80,
                color: Theme.of(context).primaryColor.withValues(alpha: 0.4)),
            const SizedBox(height: 24),
            Text(
              'Start a Session',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Make sure all four WitMotion sensors are turned on '
              'and within Bluetooth range.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                  height: 1.5),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    ref.read(sessionProvider.notifier).startSession(),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Session',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Starting ─────────────────────────────────────────────────────────────

  Widget _buildStarting(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 32),
            Text('Setting up...',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Connecting to sensors and loading model...',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 48),
            TextButton(
              onPressed: () =>
                  ref.read(sessionProvider.notifier).stopSession(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Active ───────────────────────────────────────────────────────────────

  Widget _buildActive(BuildContext context, SessionState session) {
    final percentages = session.posturePercentages;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── App-consistent header (same style as My Progress) ─────────
          _buildHeader(context, session.elapsed),

          // ── Content on white/light background ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPostureCard(context, session),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child:
                            _buildScoreCard(context, session.sessionScore)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStreakCard(context, session)),
                  ],
                ),
                if (percentages.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildBreakdown(context, percentages),
                ],
                const SizedBox(height: 20),
                _buildEndButton(context),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header — matches the "My Progress" top bar exactly ───────────────────
  // Same light blue-grey gradient, same curved bottom, same height & padding.

  Widget _buildHeader(BuildContext context, Duration elapsed) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryDeep,
            AppColors.primaryMid,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monitoring Session',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track your posture in real time',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, color: kGreen, size: 8),
                const SizedBox(width: 6),
                Text(
                  _formatDuration(elapsed),
                  style: const TextStyle(
                    color: kGreen,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Posture card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildPostureCard(BuildContext context, SessionState session) {
    final posture        = session.lastPosture ?? 2;
    final postureName    = postureNames[posture] ?? 'Unknown';
    final color          = postureColors[posture] ?? Theme.of(context).primaryColor;
    final probs          = session.lastProbabilities;
    final bool isUpright = posture == 2;

    final double strength;
    if (isUpright) {
      strength = (session.lastConfidence ?? 0.0).clamp(0.0, 1.0);
    } else {
      final uprightProb =
          (probs != null && probs.length > 1) ? probs[1] : 1.0;
      strength = (1.0 - uprightProb).clamp(0.0, 1.0);
    }

    final strengthPct       = (strength * 100).round();
    final Color ringColor   = isUpright ? kGreen : kRed;
    final String alignLabel = isUpright ? 'Good Alignment' : 'Poor Alignment';
    final String? imagePath = postureImages[posture];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Posture',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      postureName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: color,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$strengthPct%',
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: color,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.circle, size: 9, color: ringColor),
                        const SizedBox(width: 5),
                        Text(
                          alignLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: ringColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ringColor, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: ringColor.withValues(alpha: 0.28),
                      blurRadius: 14,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: imagePath != null
                      ? Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.2),
                            child: const Icon(Icons.person,
                                color: Colors.white54, size: 40),
                          ),
                        )
                      : Container(
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.2)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // â”€â”€ Score card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildScoreCard(BuildContext context, double score) {
    final Color scoreColor;
    final String scoreLabel;
    if (score >= 70) {
      scoreColor = kGreen;
      scoreLabel = 'Good';
    } else if (score >= 40) {
      scoreColor = kAmber;
      scoreLabel = 'Fair';
    } else {
      scoreColor = kRed;
      scoreLabel = 'Poor';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Score',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    score.toStringAsFixed(0),
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: scoreColor,
                        height: 1.0),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    scoreLabel,
                    style: TextStyle(
                        color: scoreColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Icon(Icons.star_rounded,
                  color: scoreColor.withValues(alpha: 0.75), size: 32),
            ],
          ),
        ],
      ),
    );
  }

  // â”€â”€ Streak card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildStreakCard(BuildContext context, SessionState session) {
    final displayed  = _getStreakDisplay(session);
    final bool isNewBest = session.currentStreakStart != null &&
        DateTime.now()
                .difference(session.currentStreakStart!)
                .inSeconds >
            session.bestStreakSeconds;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Best Upright Streak',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedBuilder(
                    animation: _streakPopAnim,
                    builder: (context, child) => Transform.scale(
                        scale: _streakPopAnim.value, child: child),
                    child: Text(
                      _formatStreak(displayed),
                      style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: kBlue,
                          height: 1.0),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayed == 0 ? 'Keep going!' : 'Personal best',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.45),
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Icon(
                Icons.local_fire_department_rounded,
                color: isNewBest
                    ? kAmber
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2),
                size: 32,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // â”€â”€ Breakdown â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildBreakdown(
      BuildContext context, Map<int, double> percentages) {
    final sorted = postureNames.entries
        .where((e) => percentages.containsKey(e.key))
        .toList()
      ..sort((a, b) =>
          (percentages[b.key] ?? 0).compareTo(percentages[a.key] ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Session Breakdown',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        ...sorted.map((e) => _buildPostureRow(
              context, e.key, e.value, percentages[e.key]!)),
      ],
    );
  }

  Widget _buildPostureRow(
      BuildContext context, int postureId, String name, double pct) {
    final color =
        postureColors[postureId] ?? Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.8))),
                    Text('${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // ── End button ────────────────────────────────────────────────────────────

  Widget _buildEndButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _endSession(context),
        icon: const Icon(Icons.stop_rounded),
        label: const Text('End Session',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: kRed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  int _getStreakDisplay(SessionState session) {
    final start = session.currentStreakStart;
    if (start != null) {
      final live = DateTime.now().difference(start).inSeconds;
      if (live > session.bestStreakSeconds) return live;
    }
    return session.bestStreakSeconds;
  }

  String _formatStreak(int seconds) {
    if (seconds == 0) return '0s';
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }

  void _endSession(BuildContext context) {
    final data  = ref.read(sessionProvider.notifier).stopSession();
    final dur   = _formatDuration(data.duration);
    final score = data.sessionScore.toStringAsFixed(0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Session ended · $dur · Score $score'),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (d.inHours > 0) {
      return '${d.inHours.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
