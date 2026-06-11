import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/prediction_socket_service.dart';

class PredictionDebugScreen extends ConsumerWidget {
  const PredictionDebugScreen({super.key});

  static const routeName = '/prediction-debug';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final predictionAsync = ref.watch(predictionStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prediction Debug (Temporary)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: predictionAsync.when(
          data: (prediction) => _DebugContent(
            connectionStatus: 'Connected',
            prediction: prediction,
          ),
          loading: () => const _StatusOnlyContent(
            connectionStatus: 'Connecting / Waiting for data',
          ),
          error: (error, _) => _StatusOnlyContent(
            connectionStatus: 'Disconnected / Error',
            errorMessage: error.toString(),
          ),
        ),
      ),
    );
  }
}

class _DebugContent extends StatelessWidget {
  const _DebugContent({
    required this.connectionStatus,
    required this.prediction,
  });

  final String connectionStatus;
  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _InfoRow(label: 'Connection status', value: connectionStatus),
        const SizedBox(height: 12),
        _InfoRow(label: 'Timestamp', value: prediction.timestamp),
        const SizedBox(height: 12),
        _InfoRow(label: 'Posture', value: prediction.posture.toString()),
        const SizedBox(height: 12),
        _InfoRow(
          label: 'Confidence',
          value: '${prediction.confidence.toStringAsFixed(1)}%',
        ),
        const SizedBox(height: 12),
        _InfoRow(label: 'Source', value: prediction.source),
      ],
    );
  }
}

class _StatusOnlyContent extends StatelessWidget {
  const _StatusOnlyContent({
    required this.connectionStatus,
    this.errorMessage,
  });

  final String connectionStatus;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _InfoRow(label: 'Connection status', value: connectionStatus),
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          _InfoRow(label: 'Error', value: errorMessage!),
        ],
        const SizedBox(height: 20),
        const Text(
          'Waiting for realtime prediction messages from the Python TCP backend.',
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(value),
        ],
      ),
    );
  }
}
