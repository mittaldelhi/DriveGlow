import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shinex/theme/app_theme.dart';

class StaffLoginScreen extends ConsumerStatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  ConsumerState<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends ConsumerState<StaffLoginScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isNotRobot = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_isNotRobot) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm you are not a robot')),
      );
      return;
    }

    final input = _loginController.text.trim();
    final password = _passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Employee ID, Username, or Email and Password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String email = input;
      String membershipTier = 'FREE';

      // Check if input contains @ (email) or matches employee_id pattern
      if (!input.contains('@')) {
        // Use RPC function to lookup user (bypasses RLS)
        Map<String, dynamic>? profile;
        try {
          final result = await Supabase.instance.client
              .rpc('lookup_staff_user', params: {'p_login_input': input});
          
          if (result != null && result.isNotEmpty) {
            profile = Map<String, dynamic>.from(result.first);
          }
        } catch (e) {
          throw Exception('Error looking up user: $e');
        }

        if (profile == null) {
          throw Exception('Employee ID or Username "$input" not found. Please check and try again.');
        }

        // Get email from auth.users using the user_id via RPC function
        final userId = profile['id'] as String;
        
        String? emailResult;
        try {
          emailResult = await Supabase.instance.client
              .rpc('get_user_email', params: {'p_user_id': userId});
        } catch (e) {
          throw Exception('Cannot get email. Please try email login instead.');
        }

        if (emailResult == null || emailResult.isEmpty) {
          throw Exception('Email not found for this user');
        }

        email = emailResult;
        membershipTier = (profile['membership_tier'] as String?)?.toUpperCase() ?? 'FREE';
      } else {
        // It's an email - get membership_tier
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null && user.email?.toLowerCase() == input.toLowerCase()) {
          final profile = await Supabase.instance.client
              .from('user_profiles')
              .select('membership_tier')
              .eq('id', user.id)
              .maybeSingle();
          membershipTier = (profile?['membership_tier'] as String?)?.toUpperCase() ?? 'FREE';
        }
      }

      // Sign in with Supabase Auth
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } catch (authError) {
        final errorMsg = authError.toString().toLowerCase();
        if (errorMsg.contains('invalid login credentials') || errorMsg.contains('invalid_credentials')) {
          throw Exception('Invalid password. Please check your password.');
        }
        throw Exception('Login error: ${authError.toString()}');
      }

      // After successful login, verify membership_tier
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('Session error. Please try again.');
      }

      final userProfile = await Supabase.instance.client
          .from('user_profiles')
          .select('membership_tier')
          .eq('id', user.id)
          .maybeSingle();

      membershipTier = (userProfile?['membership_tier'] as String?)?.toUpperCase() ?? 'FREE';

      // Check if user is staff or admin
      if (membershipTier != 'STAFF' && membershipTier != 'ADMIN') {
        // Sign out and show error
        await Supabase.instance.client.auth.signOut();
        throw Exception('This login is for staff only. Please use the regular login.');
      }

      // Success - navigate based on role
      if (!mounted) return;

      // Use RPC to verify admin status (handles stale database tier)
      final isAdmin = await Supabase.instance.client.rpc('is_admin_user');
      
      if (isAdmin == true) {
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        Navigator.pushReplacementNamed(context, '/staff');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF6B7280),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    IconData? suffixIcon,
    bool obscureText = false,
    VoidCallback? onSuffixTap,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: GoogleFonts.inter(color: const Color(0xFF1A1A1A)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(color: const Color(0xFF9CA3AF)),
          prefixIcon: Icon(
            prefixIcon,
            color: const Color(0xFF9CA3AF),
            size: 20,
          ),
          suffixIcon: suffixIcon != null
              ? GestureDetector(
                  onTap: onSuffixTap,
                  child: Icon(
                    suffixIcon,
                    color: const Color(0xFF9CA3AF),
                    size: 20,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xFFF8F9FA),
                      Color(0xCCF8F9FA),
                      Color(0x33F8F9FA),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      // -- Logo --
                      Center(
                        child: Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // -- Title --
                      Text(
                        'Staff Login',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1A1A),
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // -- Subtitle --
                      Text(
                        'Enter your staff credentials',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // -- Login ID Field (Employee ID / Username / Email) --
                      _buildLabel('EMPLOYEE ID / USERNAME / EMAIL'),
                      const SizedBox(height: 8),
                      _buildInput(
                        controller: _loginController,
                        hintText: 'admin01 or username or email@example.com',
                        prefixIcon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 20),

                      // -- Password Field --
                      _buildLabel('PASSWORD'),
                      const SizedBox(height: 8),
                      _buildInput(
                        controller: _passwordController,
                        hintText: '••••••••',
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: _isPasswordVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        obscureText: !_isPasswordVisible,
                        onSuffixTap: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // -- CAPTCHA Placeholder --
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Transform.scale(
                                  scale: 1.2,
                                  child: Checkbox(
                                    value: _isNotRobot,
                                    onChanged: (v) {
                                      setState(() {
                                        _isNotRobot = v ?? false;
                                      });
                                    },
                                    activeColor: PremiumTheme.orangePrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "I'm not a robot",
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF1A1A1A),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.security,
                                  color: Colors.grey,
                                  size: 24,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'PRIVACY • TERMS',
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // -- Sign In Button --
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PremiumTheme.orangePrimary,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: PremiumTheme.orangePrimary.withValues(
                              alpha: 0.3,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Sign In',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // -- Forgot Password --
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/staff-forgot-password'),
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: PremiumTheme.orangePrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // -- Back to Homepage --
                      TextButton(
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.arrow_back, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Back to Homepage',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
