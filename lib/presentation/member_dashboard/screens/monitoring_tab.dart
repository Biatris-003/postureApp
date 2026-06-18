import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/session_provider.dart';

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
  // Tracks whether the pop has already fired for the current streak's
  // moment of surpassing the previous best.
  bool _streakPopFired = false;

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
      // Check if the live streak just surpassed the frozen best.
      final session = ref.read(sessionProvider);
      if (session.currentStreakStart != null && !_streakPopFired) {
        final live = DateTime.now()
            .difference(session.currentStreakStart!)
            .inSeconds;
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

    // Reset pop flag each time a new upright streak begins.
    ref.listen<SessionState>(sessionProvider, (prev, next) {
      if (prev?.currentStreakStart == null && next.currentStreakStart != null) {
        _streakPopFired = false;
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: switch (session.status) {
          SessionStatus.idle => _buildIdle(context),
          SessionStatus.starting => _buildStarting(context),
          SessionStatus.active => _buildActive(context, session),
        },
      ),
    );
  }

  // ─── Idle ────────────────────────────────────────────────────────────────

  Widget _buildIdle(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sensors,
              size: 80,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.35),
            ),
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
              'Make sure all four WitMotion sensors are turned on and within Bluetooth range.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    ref.read(sessionProvider.notifier).startSession(),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text(
                  'Start Session',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
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

  // ─── Starting ────────────────────────────────────────────────────────────

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
            Text(
              'Setting up...',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Connecting to sensors and loading model...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 48),
            TextButton(
              onPressed: () => ref.read(sessionProvider.notifier).stopSession(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Active ──────────────────────────────────────────────────────────────

  Widget _buildActive(BuildContext context, SessionState session) {
    final percentages = session.posturePercentages;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSessionHeader(context, session.elapsed),
          const SizedBox(height: 28),
          _buildPostureCard(context, session),
          const SizedBox(height: 28),
          _buildScoreCard(context, session.sessionScore),
          const SizedBox(height: 12),
          _buildStreakCard(context, session),
          const SizedBox(height: 28),
          if (percentages.isNotEmpty) ...[
            _buildBreakdown(context, percentages),
            const SizedBox(height: 28),
          ],
          _buildEndButton(context),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSessionHeader(BuildContext context, Duration elapsed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Live Session',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
              const SizedBox(width: 6),
              Text(
                _formatDuration(elapsed),
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostureCard(
      BuildContext context, SessionState session) {
    final posture = session.lastPosture ?? 2;
    final postureName = postureNames[posture] ?? 'Unknown';
    final color = postureColors[posture] ?? Theme.of(context).primaryColor;
    final probs = session.lastProbabilities;

    final double strength;
    if (posture == 2) {
      strength = (session.lastConfidence ?? 0.0).clamp(0.0, 1.0);
    } else {
      final uprightProb = (probs != null && probs.length > 1) ? probs[1] : 1.0;
      strength = (1.0 - uprightProb).clamp(0.0, 1.0);
    }

    final glowColor = posture == 2
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    // Percentage is the posture color, turns red if bad and deviation > 50%.
    final pctColor = (posture != 2 && strength > 0.5)
        ? const Color(0xFFEF4444)
        : color;

    final strengthPct = (strength * 100).round();

    // Split two-word names onto two lines.
    final displayName = postureName.replaceFirst(' ', '\n');

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.22),
          border: Border.all(
            color: glowColor.withValues(alpha: 0.25 + strength * 0.65),
            width: 2.5 + strength * 3.5,
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: strength * 0.45),
              blurRadius: 12 + strength * 48,
              spreadRadius: strength * 16,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              displayName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.3,
                height: 1.15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              '$strengthPct%',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: pctColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Returns the value to display: live count if currently surpassing best,
  // otherwise the frozen best.
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

  Widget _buildStreakCard(BuildContext context, SessionState session) {
    final displayed = _getStreakDisplay(session);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Best Upright Streak',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          AnimatedBuilder(
            animation: _streakPopAnim,
            builder: (context, child) =>
                Transform.scale(scale: _streakPopAnim.value, child: child),
            child: Text(
              _formatStreak(displayed),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF3B82F6),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...sorted.map((e) => _buildPostureBar(
              context,
              e.key,
              e.value,
              percentages[e.key]!,
            )),
      ],
    );
  }

  Widget _buildPostureBar(
      BuildContext context, int postureId, String name, double pct) {
    final color = postureColors[postureId] ?? Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13)),
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(BuildContext context, double score) {
    final Color scoreColor;
    final String scoreLabel;
    if (score >= 70) {
      scoreColor = const Color(0xFF10B981);
      scoreLabel = 'Great';
    } else if (score >= 40) {
      scoreColor = const Color(0xFFF59E0B);
      scoreLabel = 'Fair';
    } else {
      scoreColor = const Color(0xFFEF4444);
      scoreLabel = 'Poor';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Session Score',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: scoreColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                scoreLabel,
                style: TextStyle(
                    color: scoreColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEndButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _endSession(context),
        icon: const Icon(Icons.stop_rounded),
        label: const Text(
          'End Session',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEF4444),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  void _endSession(BuildContext context) {
    final data = ref.read(sessionProvider.notifier).stopSession();
    final dur = _formatDuration(data.duration);
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
