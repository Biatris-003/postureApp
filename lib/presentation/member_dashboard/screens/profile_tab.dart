import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/auth_service_mock.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).primaryColor, Theme.of(context).colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const CircleAvatar(
                        radius: 55,
                        backgroundImage: AssetImage('assets/images/user_profile.jpg'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?.email ?? 'Sarah Connor',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Premium Member',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDailyGoalCard(context),
                  const SizedBox(height: 32),
                  Text('Hardware Connections', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 16),
                  _buildHardwareCard(context),
                  const SizedBox(height: 32),
                  Text('Account Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 16),
                  _buildSettingsGroup(context, ref),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyGoalCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Daily Goal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              Icon(Icons.local_fire_department_rounded, color: const Color(0xFFF59E0B), size: 32),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('80%', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Theme.of(context).primaryColor)),
                    Text('Posture Score', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: 0.8,
                    minHeight: 14,
                    backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareCard(BuildContext context) {
    final successColor = const Color(0xFF10B981);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
        border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.1), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: successColor.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(Icons.bluetooth_connected_rounded, color: successColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Smart Shirt Sensors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 4),
                Text('Connected • Synced just now', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Column(
            children: [
              Icon(Icons.battery_4_bar_rounded, color: successColor, size: 24),
              const SizedBox(height: 4),
              Text('82%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          _buildSettingsTile(context, icon: Icons.notifications_active_outlined, title: 'Push Notifications', trailing: Switch(value: true, onChanged: (_) {}, activeThumbColor: Theme.of(context).primaryColor)),
          Divider(height: 1, indent: 64, color: Theme.of(context).scaffoldBackgroundColor),
          _buildSettingsTile(context, icon: Icons.person_outline, title: 'Personal Information', trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), size: 28)),
          Divider(height: 1, indent: 64, color: Theme.of(context).scaffoldBackgroundColor),
          _buildSettingsTile(context, icon: Icons.security_outlined, title: 'Privacy & Data', trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), size: 28)),
          Divider(height: 1, indent: 64, color: Theme.of(context).scaffoldBackgroundColor),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 28),
            title: const Text('Log Out', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 16)),
            onTap: () {
              ref.read(authServiceProvider).logout();
              ref.read(authStateProvider.notifier).setUser(null);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context, {required IconData icon, required String title, required Widget trailing}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Theme.of(context).primaryColor),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
      trailing: trailing,
      onTap: () {},
    );
  }
}
