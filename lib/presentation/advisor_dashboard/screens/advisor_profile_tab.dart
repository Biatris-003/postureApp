import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/auth_service_mock.dart';

class AdvisorProfileTab extends ConsumerWidget {
  const AdvisorProfileTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blue,
              child: Icon(Icons.medical_services, size: 50, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            user?.email ?? 'Unknown Advisor',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Posture & Ergonomics Advisor',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 48),
          const Text('Account Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildSettingsTile(icon: Icons.notifications, title: 'Alerts & Notifications', trailing: Switch(value: true, onChanged: (_) {})),
          _buildSettingsTile(icon: Icons.group, title: 'Assigned Patients', trailing: const Text('3 Active', style: TextStyle(color: Colors.green))),
          _buildSettingsTile(icon: Icons.security, title: 'Privacy & Data', trailing: const Icon(Icons.chevron_right)),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Log Out', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              ref.read(authServiceProvider).logout();
              ref.read(authStateProvider.notifier).setUser(null);
            },
          )
        ],
      ),
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, required Widget trailing}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        trailing: trailing,
        onTap: () {},
      ),
    );
  }
}
