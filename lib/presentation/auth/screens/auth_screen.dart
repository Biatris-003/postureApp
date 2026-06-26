import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/auth_service_mock.dart';
// ✅ Correct imports for dashboard screens
import '../../member_dashboard/screens/member_dashboard_screen.dart';
import '../../advisor_dashboard/screens/advisor_dashboard_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;
  
  // ✅ Role selection
  String _selectedRole = 'Member'; // 'Member' for Patient, 'Advisor' for Doctor

  // Login controllers
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Signup controllers
  final _signupFormKey = GlobalKey<FormState>();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupConfirmPasswordController = TextEditingController();
  final _signupUsernameController = TextEditingController();

  static const Color _primaryBlue = Color(0xFF35506E);

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    _signupUsernameController.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ref.read(authServiceProvider).login(
            _loginEmailController.text.trim(),
            _loginPasswordController.text,
          );

      ref.read(authStateProvider.notifier).setUser(user);

      if (!mounted) return;

      // ✅ Navigate based on role
      if (user.role == 'Advisor') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const AdvisorDashboardScreen(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MemberDashboardScreen(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _parseErrorMessage(e.toString());
        _isLoading = false;
      });
    }
  }

  void _signup() async {
    if (!_signupFormKey.currentState!.validate()) return;

    if (_signupPasswordController.text != _signupConfirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ✅ Use the selected role instead of hardcoded 'Member'
      final user = await ref.read(authServiceProvider).signUp(
            email: _signupEmailController.text.trim(),
            password: _signupPasswordController.text,
            role: _selectedRole, // ✅ Uses selected role
            profileData: {
              'fullName': _signupUsernameController.text.trim(),
              'contactEmail': _signupEmailController.text.trim(),
            },
          );

      ref.read(authStateProvider.notifier).setUser(user);

      if (!mounted) return;

      // ✅ Navigate based on role
      if (user.role == 'Advisor') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const AdvisorDashboardScreen(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MemberDashboardScreen(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _parseErrorMessage(e.toString());
        _isLoading = false;
      });
    }
  }

  String _parseErrorMessage(String error) {
    if (error.contains('user-not-found')) {
      return 'Email not found. Please check or sign up.';
    } else if (error.contains('wrong-password')) {
      return 'Incorrect password.';
    } else if (error.contains('invalid-email')) {
      return 'Invalid email format.';
    } else if (error.contains('email-already-in-use')) {
      return 'Email already in use. Please login.';
    }
    return 'Something went wrong. Try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryBlue,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Logo ──
                      Image.asset(
                        'assets/images/homePage/back_view.png',
                        height: 120,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: _primaryBlue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.health_and_safety,
                              size: 44,
                              color: _primaryBlue,
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Posture AI',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _primaryBlue,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Improve your posture, improve your life',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ── Segmented Control ──
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _tabButton(
                                title: 'Login',
                                selected: _isLogin,
                                onTap: () {
                                  setState(() {
                                    _isLogin = true;
                                    _errorMessage = null;
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: _tabButton(
                                title: 'Sign Up',
                                selected: !_isLogin,
                                onTap: () {
                                  setState(() {
                                    _isLogin = false;
                                    _errorMessage = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ── Error Message ──
                      if (_errorMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.shade200,
                            ),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // ── Animated Form Switcher ──
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.1),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: _isLogin
                            ? _buildModernLoginForm()
                            : _buildModernSignupForm(),
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

  Widget _tabButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: selected
                  ? _primaryBlue
                  : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  // ── Modern Login Form ──
  Widget _buildModernLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        children: [
          _buildModernField(
            controller: _loginEmailController,
            label: 'Email Address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => v!.isEmpty || !v.contains('@')
                ? 'Invalid email'
                : null,
          ),
          const SizedBox(height: 16),
          _buildModernField(
            controller: _loginPasswordController,
            label: 'Password',
            icon: Icons.lock_outline,
            isPassword: true,
            validator: (v) => v!.isEmpty ? 'Enter password' : null,
          ),
          const SizedBox(height: 12),

          // ── Forgot Password ──
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  color: _primaryBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Login Button ──
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: _primaryBlue,
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Modern Signup Form ──
  Widget _buildModernSignupForm() {
    return Form(
      key: _signupFormKey,
      child: Column(
        children: [
          _buildModernField(
            controller: _signupUsernameController,
            label: 'Username',
            icon: Icons.person_outline,
            validator: (v) => v!.isEmpty ? 'Enter your username' : null,
          ),
          const SizedBox(height: 16),
          _buildModernField(
            controller: _signupEmailController,
            label: 'Email Address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => v!.isEmpty || !v.contains('@')
                ? 'Invalid email'
                : null,
          ),
          const SizedBox(height: 16),
          _buildModernField(
            controller: _signupPasswordController,
            label: 'Password',
            icon: Icons.lock_outline,
            isPassword: true,
            validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
          ),
          const SizedBox(height: 16),
          _buildModernField(
            controller: _signupConfirmPasswordController,
            label: 'Confirm Password',
            icon: Icons.lock_outline,
            isPassword: true,
            validator: (v) => v!.isEmpty ? 'Confirm your password' : null,
          ),
          const SizedBox(height: 24),

          // ✅ ROLE SELECTION - Professional segmented control style
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Register as',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _roleButton(
                        title: 'Patient',
                        selected: _selectedRole == 'Member',
                        onTap: () {
                          setState(() {
                            _selectedRole = 'Member';
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: _roleButton(
                        title: 'Doctor',
                        selected: _selectedRole == 'Advisor',
                        onTap: () {
                          setState(() {
                            _selectedRole = 'Advisor';
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Signup Button ──
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: _primaryBlue,
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _signup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Create Account',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ✅ Role button widget - matches the tab style
  Widget _roleButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: selected
                  ? _primaryBlue
                  : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  // ── Modern Field with icon ──
  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _primaryBlue),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: _primaryBlue,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}