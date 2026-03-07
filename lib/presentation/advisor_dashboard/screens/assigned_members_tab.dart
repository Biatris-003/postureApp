import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/advisor_data_service_mock.dart';
import '../../../domain/entities/assigned_member.dart';
import 'member_details_screen.dart';

class AssignedMembersTab extends ConsumerWidget {
  const AssignedMembersTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<AssignedMember>>(
        future: ref.read(advisorDashboardProvider).getAssignedMembers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
             return const Center(child: CircularProgressIndicator());
          }
          final members = snapshot.data!;
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final Color statusColor = _getStatusColor(member.status);
              
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.2),
                    child: Text(member.name[0], style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(member.email),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(member.status, style: TextStyle(color: statusColor, fontSize: 12)),
                          ),
                          const Spacer(),
                          Text('Compliance: ${(member.complianceRate * 100).toInt()}%', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                        ],
                      )
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => MemberDetailsScreen(member: member)
                    ));
                  },
                ),
              );
            },
          );
        }
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Improving': return Colors.green;
      case 'Stable': return Colors.blue;
      case 'Needs Attention': return Colors.orange;
      case 'Critical': return Colors.red;
      default: return Colors.grey;
    }
  }
}
