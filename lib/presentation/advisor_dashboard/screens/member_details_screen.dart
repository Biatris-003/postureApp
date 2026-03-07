import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/advisor_data_service_mock.dart';
import '../../../domain/entities/assigned_member.dart';
import '../../../domain/entities/exercises/exercise.dart';

class MemberDetailsScreen extends ConsumerWidget {
  final AssignedMember member;

  const MemberDetailsScreen({Key? key, required this.member}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch this member's exercises directly from the global mock state
    final mappedExercises = ref.watch(exerciseProvider);
    final List<Exercise> exercises = mappedExercises[member.uid] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('${member.name} Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildOverviewCard(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Assigned Exercises', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.blue),
                  onPressed: () {
                     // Add logic placeholder
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add exercise stub')));
                  },
                )
              ],
            ),
            const SizedBox(height: 12),
            if (exercises.isEmpty) 
               const Center(child: Text("No exercises assigned. Click + to add."))
            else
               ...exercises.map((e) => _buildExerciseTile(context, ref, member.uid, e))
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                 const Icon(Icons.analytics, size: 40, color: Colors.blue),
                 const SizedBox(width: 16),
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const Text('Compliance Rate', style: TextStyle(color: Colors.grey)),
                     Text('${(member.complianceRate * 100).toInt()}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                   ]
                 )
              ],
            ),
            const Divider(height: 32),
            const Text('Patient has been showing gradual improvement but still suffers from forward head posture during afternoon hours. Adjust exercises accordingly.', style: TextStyle(color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseTile(BuildContext context, WidgetRef ref, String uid, Exercise ex) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: ListTile(
        title: Text(ex.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${ex.duration} - ${ex.frequency}'),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Colors.blue),
          onPressed: () => _showEditDialog(context, ref, uid, ex),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, String uid, Exercise ex) {
    final titleCtrl = TextEditingController(text: ex.title);
    final durationCtrl = TextEditingController(text: ex.duration);
    final freqCtrl = TextEditingController(text: ex.frequency);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit ${ex.title}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
               TextField(controller: durationCtrl, decoration: const InputDecoration(labelText: 'Duration (e.g., 5 mins)')),
               TextField(controller: freqCtrl, decoration: const InputDecoration(labelText: 'Frequency (e.g., Daily)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                 final updated = ex.copyWith(
                   title: titleCtrl.text,
                   duration: durationCtrl.text,
                   frequency: freqCtrl.text,
                 );
                 ref.read(exerciseProvider.notifier).updateExercise(uid, updated);
                 Navigator.pop(context);
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exercise updated successfully!')));
              }, 
              child: const Text('Save')
            )
          ],
        );
      }
    );
  }
}
