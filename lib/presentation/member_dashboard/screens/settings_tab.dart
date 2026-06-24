import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/user_settings_provider.dart';
import '../../../services/session_provider.dart';
import '../../../services/ble/ble_receiver.dart';
import '../../../services/ble/ble_monitor_provider.dart';
import '../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sensor info model — populated from the persistent BleMonitorNotifier which
// reads real battery levels and connection status from the BLE sensors at all
// times (both during and outside of active sessions).
// ─────────────────────────────────────────────────────────────────────────────
class _SensorInfo {
  final String mac;
  final String label;
  final String location;
  final int batteryPct;
  final bool connected;
  final bool enabled;

  const _SensorInfo({
    required this.mac,
    required this.label,
    required this.location,
    required this.batteryPct,
    required this.connected,
    required this.enabled,
  });
}

// Muted amber used in place of a bright/neon warning tone, consistent with
// the rest of the app's restrained palette (see member_details_screen).
const _amber = Color(0xFFB8860B);

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────
class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab>
    with SingleTickerProviderStateMixin {
  bool _isTogglingSession = false;

  // Pulsing animation for the power button
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  List<_SensorInfo> _getSensors(
      BleMonitorState monitor, Map<String, bool> enabledMap) {
    return kSensorIdMap.entries.map((e) {
      final mac = e.key;
      final label = e.value;
      final locations = {
        'C7': 'Cervical (Neck)',
        'T4': 'Upper Thoracic',
        'T12': 'Lower Thoracic',
        'L5': 'Lumbar (Lower Back)',
      };

      final isEnabled = enabledMap[mac] ?? true;
      final isConnected = monitor.connections[mac] ?? false;
      final battery = monitor.batteryLevels[mac] ?? 0;

      return _SensorInfo(
        mac: mac,
        label: label,
        location: locations[label] ?? label,
        batteryPct: battery,
        connected: isEnabled && isConnected,
        enabled: isEnabled,
      );
    }).toList();
  }

  // ── Color helpers ──────────────────────────────────────────────────────────
  Color _batteryColor(int pct) {
    if (pct >= 60) return AppColors.success;
    if (pct >= 30) return _amber;
    return AppColors.danger;
  }

  IconData _batteryIcon(int pct) {
    if (pct >= 80) return Icons.battery_full_rounded;
    if (pct >= 60) return Icons.battery_5_bar_rounded;
    if (pct >= 40) return Icons.battery_3_bar_rounded;
    if (pct >= 20) return Icons.battery_2_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  // ── Session toggle ─────────────────────────────────────────────────────────
  Future<void> _toggleSession(SessionState session) async {
    if (_isTogglingSession) return;
    setState(() => _isTogglingSession = true);

    try {
      if (session.status == SessionStatus.idle) {
        await ref.read(sessionProvider.notifier).startSession();
        _pulseCtrl.repeat(reverse: true);
      } else {
        ref.read(sessionProvider.notifier).stopSession();
        _pulseCtrl.stop();
        _pulseCtrl.reset();
      }
    } finally {
      if (mounted) setState(() => _isTogglingSession = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final monitor = ref.watch(bleMonitorProvider);
    final enabledMap = ref.watch(enabledSensorsProvider);
    final sensors = _getSensors(monitor, enabledMap);
    final isActive = session.status != SessionStatus.idle;
    final isStarting = session.status == SessionStatus.starting;

    // Watch settings from Firestore-backed provider
    final settingsAsync = ref.watch(userSettingsProvider);
    final settings = settingsAsync.when(
      data: (s) => s,
      loading: () => const UserSettings(),
      error: (err, st) => const UserSettings(),
    );

    // Sync pulse animation with session state
    if (isActive && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!isActive && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.primaryDeep,
            elevation: 0,
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.headerGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.settings_rounded,
                                color: AppColors.ink, size: 26),
                            const SizedBox(width: 10),
                            const Text(
                              'Settings',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage your system & sensors',
                          style: TextStyle(
                            color: AppColors.primaryDeep.withValues(alpha: 0.75),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Power Card ─────────────────────────────────────────
                  _buildPowerCard(context, session, isActive, isStarting),
                  const SizedBox(height: 28),

                  // ── Section title ──────────────────────────────────────
                  _sectionTitle('Sensor Status'),
                  const SizedBox(height: 12),
                  _buildSensorPanel(sensors),
                  const SizedBox(height: 28),

                  // ── Alerts section ─────────────────────────────────────
                  _sectionTitle('Alerts & Feedback'),
                  const SizedBox(height: 12),
                  _buildAlertsCard(settings),
                  const SizedBox(height: 28),

                  // ── Alert threshold ────────────────────────────────────
                  _sectionTitle('Alert Threshold'),
                  const SizedBox(height: 12),
                  _buildThresholdCard(settings),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Power Card
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPowerCard(
    BuildContext context,
    SessionState session,
    bool isActive,
    bool isStarting,
  ) {
    final statusColor = isActive ? AppColors.success : AppColors.textSecondaryLight;

    final statusLabel = isStarting
        ? 'Connecting to sensors...'
        : isActive
            ? 'System is running'
            : 'System is offline';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (isActive ? AppColors.success : Colors.black).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: (isActive ? AppColors.success : AppColors.borderLight).withValues(
              alpha: isActive ? 0.3 : 1),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Status indicator dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    statusLabel,
                    key: ValueKey(statusLabel),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Power button
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) {
                return GestureDetector(
                  onTap: _isTogglingSession ? null : () => _toggleSession(session),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulse ring
                      if (isActive)
                        Container(
                          width: 130 * _pulseAnim.value,
                          height: 130 * _pulseAnim.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success.withValues(alpha: 0.08 * _pulseAnim.value),
                          ),
                        ),
                      // Inner ring
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? AppColors.success.withValues(alpha: 0.12)
                              : AppColors.primaryDeep.withValues(alpha: 0.05),
                          border: Border.all(
                            color: isActive
                                ? AppColors.success.withValues(alpha: 0.5)
                                : AppColors.borderLight,
                            width: 2,
                          ),
                        ),
                      ),
                      // Button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isActive
                                ? [AppColors.success, const Color(0xFF2E5E4C)]
                                : [
                                    AppColors.primaryDeep.withValues(alpha: 0.18),
                                    AppColors.primaryDeep.withValues(alpha: 0.10),
                                  ],
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: AppColors.success.withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ]
                              : [],
                        ),
                        child: _isTogglingSession
                            ? const SizedBox(
                                width: 32,
                                height: 32,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.power_settings_new_rounded,
                                size: 40,
                                color: isActive
                                    ? Colors.white
                                    : AppColors.primaryDeep.withValues(alpha: 0.45),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isActive ? 'Tap to turn OFF' : 'Tap to turn ON',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryLight,
              letterSpacing: 0.3,
            ),
          ),

          if (isActive) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  _SessionElapsedWidget(session: session),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sensor Panel
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSensorPanel(List<_SensorInfo> sensors) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < sensors.length; i++) ...[
            _buildSensorTile(sensors[i]),
            if (i < sensors.length - 1)
              const Divider(height: 1, indent: 72, color: AppColors.borderLight),
          ]
        ],
      ),
    );
  }

  Widget _buildSensorTile(_SensorInfo sensor) {
    final battery = sensor.batteryPct;
    final isEnabled = sensor.enabled;
    final connected = sensor.connected;

    // battery details styling
    final showBattery = isEnabled && connected;
    final bColor = showBattery ? _batteryColor(battery) : AppColors.textSecondaryLight;
    final bIcon = showBattery ? _batteryIcon(battery) : Icons.battery_unknown_rounded;

    final statusText = !isEnabled
        ? 'Disabled'
        : connected
            ? 'Connected'
            : 'Offline';

    final statusColor = !isEnabled
        ? AppColors.textSecondaryLight
        : connected
            ? AppColors.success
            : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Sensor icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (connected ? AppColors.primaryDeep : AppColors.textSecondaryLight)
                  .withValues(alpha: isEnabled ? 0.10 : 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                sensor.label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: connected
                      ? AppColors.primaryDeep
                      : AppColors.textSecondaryLight.withValues(alpha: isEnabled ? 0.7 : 0.4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Label & location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sensor.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimaryLight.withValues(alpha: isEnabled ? 1.0 : 0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sensor.location,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight.withValues(alpha: isEnabled ? 1.0 : 0.6),
                  ),
                ),
              ],
            ),
          ),

          // Switch to enable/disable
          Switch(
            value: isEnabled,
            activeThumbColor: AppColors.primaryDeep,
            onChanged: (val) {
              ref.read(enabledSensorsProvider.notifier).toggleSensor(sensor.mac);
            },
          ),
          const SizedBox(width: 14),

          // Battery + status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(bIcon, size: 18, color: bColor),
                  const SizedBox(width: 4),
                  Text(
                    showBattery ? '$battery%' : 'N/A',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: bColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Alerts Card
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAlertsCard(UserSettings settings) {
    return _buildToggleCard([
      _ToggleItem(
        icon: Icons.notifications_active_outlined,
        title: 'Posture Alerts',
        subtitle: 'Notify when bad posture is detected',
        value: settings.postureAlerts,
        onChanged: (v) => ref.read(userSettingsProvider.notifier).setPostureAlerts(v),
      ),
      _ToggleItem(
        icon: Icons.vibration_rounded,
        title: 'Vibration Feedback',
        subtitle: 'Haptic pulse when posture worsens',
        value: settings.vibrationFeedback,
        onChanged: (v) => ref.read(userSettingsProvider.notifier).setVibrationFeedback(v),
      ),
      _ToggleItem(
        icon: Icons.summarize_outlined,
        title: 'Daily Summary',
        subtitle: 'Evening report of your posture day',
        value: settings.dailySummary,
        onChanged: (v) => ref.read(userSettingsProvider.notifier).setDailySummary(v),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Alert Threshold Card
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildThresholdCard(UserSettings settings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryDeep.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timer_outlined, color: AppColors.primaryDeep, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alert after bad posture for',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const Text(
                      'Minimum duration before alerting you',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                  ],
                ),
              ),
              Text(
                '${settings.alertThresholdMinutes} min',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primaryDeep,
              inactiveTrackColor: AppColors.primaryDeep.withValues(alpha: 0.15),
              thumbColor: AppColors.primaryDeep,
              overlayColor: AppColors.primaryDeep.withValues(alpha: 0.1),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              trackHeight: 5,
            ),
            child: Slider(
              value: settings.alertThresholdMinutes.toDouble(),
              min: 1,
              max: 15,
              divisions: 14,
              onChanged: (v) =>
                  ref.read(userSettingsProvider.notifier).setAlertThreshold(v.round()),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 min',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w600)),
              Text('15 min',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // App Preferences Card
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPreferencesCard(UserSettings settings) {
    return _buildToggleCard([
      _ToggleItem(
        icon: Icons.dark_mode_outlined,
        title: 'Dark Mode',
        subtitle: 'Force dark theme regardless of system',
        value: settings.darkModeOverride,
        onChanged: (v) => ref.read(userSettingsProvider.notifier).setDarkModeOverride(v),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared builders
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildToggleCard(List<_ToggleItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _buildToggleTile(items[i]),
            if (i < items.length - 1)
              const Divider(height: 1, indent: 72, color: AppColors.borderLight),
          ]
        ],
      ),
    );
  }

  Widget _buildToggleTile(_ToggleItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.primaryDeep.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: AppColors.primaryDeep, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: item.value,
            onChanged: item.onChanged,
            activeThumbColor: AppColors.primaryDeep,
            activeTrackColor: AppColors.primaryDeep.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimaryLight,
        letterSpacing: -0.2,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small widget that shows the elapsed session time and ticks every second
// ─────────────────────────────────────────────────────────────────────────────
class _SessionElapsedWidget extends StatefulWidget {
  final SessionState session;
  const _SessionElapsedWidget({required this.session});

  @override
  State<_SessionElapsedWidget> createState() => _SessionElapsedWidgetState();
}

class _SessionElapsedWidgetState extends State<_SessionElapsedWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (d.inHours > 0) {
      return '${d.inHours.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Session: ${_fmt(widget.session.elapsed)}',
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.success,
        fontFamily: 'monospace',
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data class for toggle tiles
// ─────────────────────────────────────────────────────────────────────────────
class _ToggleItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
}