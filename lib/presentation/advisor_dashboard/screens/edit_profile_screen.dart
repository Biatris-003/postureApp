import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  final String clinicianId;
  final String initialName;
  final String initialSpecialty;
  final String initialInstitution;
  final String initialEmail;
  final String? initialImageBase64;

  const EditProfileScreen({
    super.key,
    required this.clinicianId,
    required this.initialName,
    required this.initialSpecialty,
    required this.initialInstitution,
    required this.initialEmail,
    this.initialImageBase64,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _specialtyCtrl;
  late final TextEditingController _institutionCtrl;
  late final TextEditingController _emailCtrl;

  bool _isSaving = false;
  String _livePreviewName = '';
  String? _currentImageBase64;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _specialtyCtrl = TextEditingController(text: widget.initialSpecialty);
    _institutionCtrl = TextEditingController(text: widget.initialInstitution);
    _emailCtrl = TextEditingController(text: widget.initialEmail);
    _livePreviewName = widget.initialName;
    _currentImageBase64 = widget.initialImageBase64;

    _nameCtrl.addListener(() {
      setState(() => _livePreviewName = _nameCtrl.text);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _specialtyCtrl.dispose();
    _institutionCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 70,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _currentImageBase64 = base64Encode(bytes));
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final updates = {
        'fullName': _nameCtrl.text.trim(),
        'specialty': _specialtyCtrl.text.trim(),
        'institution': _institutionCtrl.text.trim(),
        'contactEmail': _emailCtrl.text.trim(),
      };
      // Only update image if it changed
      if (_currentImageBase64 != widget.initialImageBase64) {
        updates['profileImageBase64'] = _currentImageBase64 ?? '';
      }
      await FirebaseFirestore.instance
          .collection('clinicians')
          .doc(widget.clinicianId)
          .update(updates);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppToast.show(context,
            message: 'Failed to update profile', isError: true);
      }
    }
  }

  String _initialsOf(String name) {
    final parts = name.trim().split(' ').where((e) => e.isNotEmpty);
    if (parts.isEmpty) return '';
    return parts.map((e) => e[0]).take(2).join().toUpperCase();
  }

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
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Personal Information'),
                  const SizedBox(height: 14),
                  _formCard([
                    _underlineField(controller: _nameCtrl, label: 'Full Name'),
                    _fieldDivider(),
                    _underlineField(
                      controller: _emailCtrl,
                      label: 'Email Address',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ]),
                  const SizedBox(height: 28),
                  _sectionLabel('Professional Details'),
                  const SizedBox(height: 14),
                  _formCard([
                    _underlineField(
                        controller: _specialtyCtrl, label: 'Specialty'),
                    _fieldDivider(),
                    _underlineField(
                        controller: _institutionCtrl, label: 'Institution'),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildSaveBar(),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final initials = _initialsOf(_livePreviewName);

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
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Color(0xFF1B2430), size: 18),
                  ),
                  const Spacer(),
                  const Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: Color(0xFF1B2430),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 44),
                ],
              ),
              const SizedBox(height: 18),
              Center(
                child: Column(
                  children: [

                    // ── Avatar with camera overlay ──
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primaryDeep.withValues(alpha: 0.3),
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.10),
                                  blurRadius: 16,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _currentImageBase64 != null
                                  ? Image.memory(
                                      base64Decode(_currentImageBase64!),
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: AppColors.primaryDeep
                                          .withValues(alpha: 0.08),
                                      child: Center(
                                        child: Text(
                                          initials,
                                          style: const TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1B2430),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),

                          // Camera badge on bottom-right
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryDeep,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 15),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    Text(
                      _livePreviewName.isEmpty ? 'Dr. Unknown' : _livePreviewName,
                      style: const TextStyle(
                        color: Color(0xFF1B2430),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Tap photo to change',
                      style: TextStyle(
                        color: AppColors.textSecondaryLight,
                        fontSize: 11,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Form helpers ───────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondaryLight,
          letterSpacing: 0.8,
        ),
      );

  Widget _formCard(List<Widget> children) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cardLight,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(children: children),
      );

  Widget _fieldDivider() =>
      const Divider(height: 1, color: AppColors.borderLight);

  Widget _underlineField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondaryLight,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryLight,
            ),
            decoration: const InputDecoration(
              isDense: true,
              filled: false,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.borderLight),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: AppColors.primaryDeep, width: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sticky save bar ────────────────────────────────────────

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [AppColors.primaryDeep, AppColors.primaryMid],
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _isSaving ? null : _save,
                child: Center(
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Save Changes',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}