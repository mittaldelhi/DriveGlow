import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shinex/theme/app_theme.dart';

class StaffLoginV2Screen extends ConsumerStatefulWidget {
  const StaffLoginV2Screen({super.key});

  @override
  ConsumerState<StaffLoginV2Screen> createState() => _StaffLoginV2ScreenState();
}

class _StaffLoginV2ScreenState extends ConsumerState<StaffLoginV2Screen> {
  final _employeeIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isNotRobot = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _employeeIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_isNotRobot) {
      setState(() => _errorMessage = 'Please confirm you are not a robot');
      return;
    }

    final employeeId = _employeeIdController.text.trim();
    final password = _passwordController.text.trim();

    if (employeeId.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter Employee ID and Password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Call the login verification function
      dynamic result;
      try {
        result = await Supabase.instance.client
            .rpc('verify_staff_login', params: {
          'p_employee_id': employeeId,
          'p_password': password
        });
      } catch (rpcError) {
        throw Exception('RPC Error: $rpcError');
      }

      if (result == null || result.isEmpty) {
        throw Exception('Invalid Employee ID or Password');
      }

      // Parse the result
      Map<String, dynamic> staffData;
      try {
        staffData = Map<String, dynamic>.from(result.first);
      } catch (parseError) {
        throw Exception('Failed to parse login result: $parseError');
      }

      final staffId = staffData['id'] as String;
      final staffCategory = staffData['staff_category'] as String;
      final mustChangePassword = staffData['must_change_password'] as bool? ?? true;
      final fullName = staffData['full_name'] as String? ?? '';
      final username = staffData['username'] as String? ?? '';

      await _storeStaffSession(staffId, employeeId, username, staffCategory, fullName);

      if (mustChangePassword) {
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/staff-change-password',
            arguments: {'staffId': staffId, 'fullName': fullName},
          );
        }
        return;
      }

      _redirectToPanel(staffCategory);

    } catch (e) {
      String errorMsg = e.toString();
      // Show more detailed error for debugging
      if (errorMsg.contains('42702') || errorMsg.contains('ambiguous')) {
        errorMsg = 'Database error: Column reference ambiguous. Please contact admin.\n\nError: $errorMsg';
      } else if (errorMsg.contains('locked')) {
        errorMsg = 'Account temporarily locked. Please try again in 30 minutes.';
      } else if (errorMsg.contains('Invalid') || errorMsg.contains('invalid')) {
        errorMsg = 'Invalid Employee ID or Password';
      } else {
        // Show full error for debugging
        errorMsg = 'Login failed. Please try again.\n\nError: $errorMsg';
      }
      setState(() => _errorMessage = errorMsg);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _storeStaffSession(String staffId, String employeeId, String username, String category, String fullName) async {
    try {
      await Supabase.instance.client.from('staff_sessions').upsert({
        'staff_id': staffId,
        'employee_id': employeeId,
        'username': username,
        'staff_category': category,
        'full_name': fullName,
        'logged_in_at': DateTime.now().toIso8601String(),
      }, onConflict: 'staff_id');
    } catch (e) {
      // Session storage error is not critical - continue with login
      debugPrint('Session storage warning: $e');
    }
  }

  void _redirectToPanel(String category) {
    if (!mounted) return;
    
    switch (category.toUpperCase()) {
      case 'ADMIN':
        Navigator.pushReplacementNamed(context, '/admin/dashboard');
        break;
      case 'MANAGER':
      case 'SUPERVISOR':
        Navigator.pushReplacementNamed(context, '/staff/panel');
        break;
      default:
        Navigator.pushReplacementNamed(context, '/staff/panel');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              _buildLogo(),
              const SizedBox(height: 40),
              _buildLoginForm(),
              const SizedBox(height: 24),
              _buildForgotPassword(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF0541E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.badge_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Staff Login',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your employee credentials',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _buildInputField(
              controller: _employeeIdController,
              label: 'Employee ID',
              hint: 'Enter your employee ID',
              prefixIcon: Icons.badge_outlined,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            _buildPasswordField(),
            const SizedBox(height: 20),
            _buildRobotCheck(),
            const SizedBox(height: 20),
            _buildLoginButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputAction? textInputAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          textInputAction: textInputAction,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(prefixIcon, color: Colors.grey[500]),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF0541E), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _login(),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[500]),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey[500],
              ),
              onPressed: () {
                setState(() => _isPasswordVisible = !_isPasswordVisible);
              },
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF0541E), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildRobotCheck() {
    return InkWell(
      onTap: () {
        setState(() => _isNotRobot = !_isNotRobot);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isNotRobot ? const Color(0xFFF0541E) : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _isNotRobot ? const Color(0xFFF0541E) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _isNotRobot ? const Color(0xFFF0541E) : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: _isNotRobot
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'I\'m not a robot',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  Text(
                    'Confirm you are a staff member',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Icon(Icons.security, color: Colors.grey[400], size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _login,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF0541E),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              'Login',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }

  Widget _buildForgotPassword() {
    return Center(
      child: TextButton(
        onPressed: () {
          Navigator.pushNamed(context, '/staff-forgot-password');
        },
        child: Text(
          'Forgot Password?',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFF0541E),
          ),
        ),
      ),
    );
  }
}
