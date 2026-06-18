import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/auth_service_mock.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  String _selectedRole = 'Member'; // 'Member' (Patient) or 'Advisor' (Clinician)
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  
  // Patient specific
  final _dobController = TextEditingController();
  String _gender = 'Male';
  String _language = 'English';
  
  // Clinician specific
  final _specialtyController = TextEditingController();
  final _institutionController = TextEditingController();

  bool _isLoading = false;

  void _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    Map<String, dynamic> profileData = {
      'fullName': _fullNameController.text,
      'contactEmail': _emailController.text,
    };

    if (_selectedRole == 'Member') {
      profileData.addAll({
        'dateOfBirth': _dobController.text,
        'gender': _gender,
        'preferredLanguage': _language,
      });
    } else {
      profileData.addAll({
        'specialty': _specialtyController.text,
        'institution': _institutionController.text,
      });
    }

    try {
      final user = await ref.read(authServiceProvider).signUp(
        email: _emailController.text,
        password: _passwordController.text,
        role: _selectedRole,
        profileData: profileData,
      );
      ref.read(authStateProvider.notifier).setUser(user);
      
      if (!mounted) return;
      // Close signup screen and login screen to go back to main.dart routing
      Navigator.of(context).pop(); // Pops Signup
      Navigator.of(context).pop(); // Pops Login
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildRoleSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildRoleButton(
              role: 'Member',
              label: 'Patient',
              icon: Icons.person_outline,
            ),
          ),
          Expanded(
            child: _buildRoleButton(
              role: 'Advisor',
              label: 'Clinician',
              icon: Icons.medical_services_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton({
    required String role,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1565C0) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPatient = _selectedRole == 'Member';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${isPatient ? 'Patient' : 'Clinician'} Signup'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1565C0),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create Your Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Join the Smart Posture community today',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              _buildRoleSelector(),
              const SizedBox(height: 24),
              
              // Common Field: Full Name
              _buildTextField(
                controller: _fullNameController,
                label: 'Full Name',
                icon: Icons.person_outline,
                validator: (v) => v!.isEmpty ? 'Please enter your name' : null,
              ),
              
              const SizedBox(height: 16),
              
              // Role Specific Fields
              if (isPatient) ...[
                // Patient: DOB
                _buildTextField(
                  controller: _dobController,
                  label: 'Date of Birth',
                  icon: Icons.cake_outlined,
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  validator: (v) => v!.isEmpty ? 'Please select your birthday' : null,
                ),
                const SizedBox(height: 16),
                
                // Patient: Gender & Language
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        label: 'Gender',
                        value: _gender,
                        items: ['Male', 'Female', 'Other'],
                        onChanged: (v) => setState(() => _gender = v!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdown(
                        label: 'Language',
                        value: _language,
                        items: ['English', 'Arabic', 'Spanish', 'French'],
                        onChanged: (v) => setState(() => _language = v!),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Clinician: Specialty
                _buildTextField(
                  controller: _specialtyController,
                  label: 'Specialty',
                  icon: Icons.workspace_premium_outlined,
                  validator: (v) => v!.isEmpty ? 'Please enter your specialty' : null,
                ),
                const SizedBox(height: 16),
                
                // Clinician: Institution
                _buildTextField(
                  controller: _institutionController,
                  label: 'Institution',
                  icon: Icons.account_balance_outlined,
                  validator: (v) => v!.isEmpty ? 'Please enter your institution' : null,
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Common: Email
              _buildTextField(
                controller: _emailController,
                label: 'Contact Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => !v!.contains('@') ? 'Invalid email' : null,
              ),
              
              const SizedBox(height: 16),
              
              // Common: Password
              _buildTextField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock_outline,
                isPassword: true,
                validator: (v) => v!.length < 6 ? 'Password too short' : null,
              ),
              
              const SizedBox(height: 32),
              
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _signup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFF1565C0), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}
