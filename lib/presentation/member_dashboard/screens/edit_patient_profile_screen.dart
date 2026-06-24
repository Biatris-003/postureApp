import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';

class EditPatientProfileScreen extends StatefulWidget {
  final String patientId;
  final String initialName;
  final String initialEmail;
  final String initialGender;
  final String initialDateOfBirth;
  final String initialLanguage;
  final String? initialImageBase64;

  const EditPatientProfileScreen({
    super.key,
    required this.patientId,
    required this.initialName,
    required this.initialEmail,
    required this.initialGender,
    required this.initialDateOfBirth,
    required this.initialLanguage,
    this.initialImageBase64,
  });

  @override
  State<EditPatientProfileScreen> createState() => _EditPatientProfileScreenState();
}

class _EditPatientProfileScreenState extends State<EditPatientProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _languageCtrl;
  String? _gender;
  DateTime? _dob;
  String? _imageBase64;
  bool _isSaving = false;

  static const _genderOptions = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _languageCtrl = TextEditingController(text: widget.initialLanguage);
    _gender = _genderOptions.contains(widget.initialGender) ? widget.initialGender : null;
    _imageBase64 = widget.initialImageBase64;
    if (widget.initialDateOfBirth.isNotEmpty) {
      try {
        _dob = DateTime.parse(widget.initialDateOfBirth);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _languageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() => _imageBase64 = base64Encode(bytes));
    } catch (e) {
      if (mounted) AppToast.show(context, message: 'Could not load image', isError: true);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primaryDeep,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      AppToast.show(context, message: 'Name cannot be empty', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('patients').doc(widget.patientId).update({
        'fullName': _nameCtrl.text.trim(),
        'gender': _gender ?? '',
        'dateOfBirth': _dob != null ? _dob!.toIso8601String().split('T').first : '',
        'preferredLanguage': _languageCtrl.text.trim(),
        if (_imageBase64 != null) 'profileImageBase64': _imageBase64,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppToast.show(context, message: 'Failed to save: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String get _initials {
    final parts = _nameCtrl.text.trim().split(' ').where((e) => e.isNotEmpty).take(2);
    return parts.map((e) => e[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryDeep, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Live preview avatar
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryDeep.withValues(alpha: 0.10),
                        border: Border.all(color: AppColors.primaryDeep.withValues(alpha: 0.20), width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _imageBase64 != null
                          ? Image.memory(
                              base64Decode(_imageBase64!),
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                            )
                          : Center(
                              child: Text(
                                _initials.isEmpty ? '?' : _initials,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDeep,
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primaryDeep,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            _fieldCard(
              child: Column(
                children: [
                  _labeledField(
                    label: 'Full Name',
                    child: TextField(
                      controller: _nameCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: _inputDecoration('Enter your full name'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _labeledField(
                    label: 'Email',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Text(
                        widget.initialEmail.isEmpty ? '—' : widget.initialEmail,
                        style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _labeledField(
                    label: 'Gender',
                    child: DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: _inputDecoration('Select gender'),
                      items: _genderOptions
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (val) => setState(() => _gender = val),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _labeledField(
                    label: 'Date of Birth',
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 17, color: AppColors.primaryDeep),
                            const SizedBox(width: 10),
                            Text(
                              _dob != null
                                  ? '${_dob!.day}/${_dob!.month}/${_dob!.year}'
                                  : 'Select date',
                              style: TextStyle(
                                color: _dob != null
                                    ? AppColors.textPrimaryLight
                                    : AppColors.textSecondaryLight,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _labeledField(
                    label: 'Preferred Language',
                    child: TextField(
                      controller: _languageCtrl,
                      decoration: _inputDecoration('e.g. English, Arabic'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDeep,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Save Changes',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _labeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryDeep, width: 1.5),
      ),
    );
  }
}