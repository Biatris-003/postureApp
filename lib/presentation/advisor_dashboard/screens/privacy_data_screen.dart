import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class PrivacyDataScreen extends StatefulWidget {
  const PrivacyDataScreen({super.key});

  @override
  State<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends State<PrivacyDataScreen> {
  int? _expandedIndex = 0;

  static const _sections = [
    _PrivacySection(
      icon: Icons.storage_outlined,
      title: 'Data Collection',
      body:
          'We collect posture data, session recordings, and exercise '
          'compliance data to provide you and your patients with accurate '
          'health insights.',
    ),
    _PrivacySection(
      icon: Icons.cloud_outlined,
      title: 'Data Storage',
      body:
          'All data is securely stored using Firebase and encrypted in '
          'transit. Patient data is only accessible to their assigned '
          'clinician.',
    ),
    _PrivacySection(
      icon: Icons.share_outlined,
      title: 'Data Sharing',
      body:
          'Patient data is never shared with third parties. Reports are '
          'only accessible to the patient and their assigned doctor.',
    ),
    _PrivacySection(
      icon: Icons.fact_check_outlined,
      title: 'Your Rights',
      body:
          'You may request deletion of your account and all associated '
          'data at any time by contacting support.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Policy Details'),
                  const SizedBox(height: 14),
                  ...List.generate(_sections.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildAccordionTile(i, _sections[i]),
                    );
                  }),
                  const SizedBox(height: 8),
                  _buildContactNote(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 28),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Color(0xFF1B2430), size: 18),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 6),

              // ── Bigger shield icon container ──
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryDeep.withValues(alpha: 0.08),
                  border: Border.all(
                    color: AppColors.primaryDeep.withValues(alpha: 0.20),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF1B2430),
                  size: 42,
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                'Your Privacy Matters',
                style: TextStyle(
                  color: Color(0xFF1B2430),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'How we collect, store, and protect your data',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondaryLight,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  _trustBadge(Icons.lock_outline, 'Encrypted'),
                  _trustBadge(Icons.verified_user_outlined, 'Access Controlled'),
                  _trustBadge(Icons.dns_outlined, 'Firebase Secured'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trustBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primaryDeep.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryDeep.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primaryDeep),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1B2430),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondaryLight,
          letterSpacing: 0.8,
        ),
      );

  Widget _buildAccordionTile(int index, _PrivacySection section) {
    final isExpanded = _expandedIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpanded
              ? AppColors.primaryDeep.withValues(alpha: 0.25)
              : AppColors.borderLight,
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: AppColors.primaryDeep.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () =>
                setState(() => _expandedIndex = isExpanded ? null : index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDeep.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(section.icon,
                        size: 19, color: AppColors.primaryDeep),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      section.title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(Icons.keyboard_arrow_down,
                        color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 52),
                  Expanded(
                    child: Text(
                      section.body,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildContactNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryDeep.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.mail_outline, size: 18, color: AppColors.primaryDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Need to exercise your data rights? Reach out to your '
              'platform administrator or support contact.',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacySection {
  final IconData icon;
  final String title;
  final String body;

  const _PrivacySection({
    required this.icon,
    required this.title,
    required this.body,
  });
}
