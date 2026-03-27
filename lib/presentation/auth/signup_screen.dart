import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/auth_providers.dart';
import '../../application/helpers/error_helper.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shinex/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isNotRobot = false;
  bool _isLoading = false;
  
  // Username validation
  bool _isUsernameChecking = false;
  bool? _isUsernameAvailable;
  String? _usernameError;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_isNotRobot) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm you are not a robot')),
      );
      return;
    }

    final username = _usernameController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (_isUsernameAvailable != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid username')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(
            email: email,
            password: password,
            fullName: name,
          );
      
      // After signup, update username in user_profiles
      // Wait a moment for the user record to be created
      await Future.delayed(const Duration(milliseconds: 500));
      
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await Supabase.instance.client
              .from('user_profiles')
              .update({'username': username.toLowerCase()})
              .eq('id', user.id);
        }
      } catch (profileError) {
        // Continue even if profile update fails - user can update later
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created! Please check your email for confirmation.',
            ),
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, message: e.toString(), title: 'Signup Failed');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, message: e.toString(), title: 'Google Sign-In Failed');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (username.isEmpty) {
      setState(() {
        _isUsernameAvailable = null;
        _usernameError = null;
      });
      return;
    }

    // Validate username format (3-8 chars, alphanumeric + underscore)
    if (username.length < 3 || username.length > 8) {
      setState(() {
        _isUsernameAvailable = false;
        _usernameError = 'Username must be 3-8 characters';
      });
      return;
    }

    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(username)) {
      setState(() {
        _isUsernameAvailable = false;
        _usernameError = 'Only letters, numbers, underscore allowed';
      });
      return;
    }

    setState(() {
      _isUsernameChecking = true;
      _usernameError = null;
    });

    try {
      // Try RPC function first (bypasses RLS for anonymous users)
      try {
        final result = await Supabase.instance.client.rpc(
          'is_username_available',
          params: {'p_username': username.toLowerCase()},
        );
        
        setState(() {
          _isUsernameAvailable = result == true;
          _usernameError = result == true ? null : 'Username already taken';
        });
      } catch (rpcError) {
        // Fallback: try alternate function name
        try {
          final result = await Supabase.instance.client.rpc(
            'check_username_availability',
            params: {'p_username': username.toLowerCase()},
          );
          
          setState(() {
            _isUsernameAvailable = result == true;
            _usernameError = result == true ? null : 'Username already taken';
          });
        } catch (e2) {
          // If both fail, assume username is taken (safer - blocks signup)
          setState(() {
            _isUsernameAvailable = false;
            _usernameError = 'Could not verify username. Try again.';
          });
        }
      }
    } catch (e) {
      // If there's an error, assume username is taken (safer - blocks signup)
      setState(() {
        _isUsernameAvailable = false;
        _usernameError = 'Could not verify username. Try again.';
      });
    } finally {
      setState(() => _isUsernameChecking = false);
    }
  }

  bool get _isFormValid {
    final username = _usernameController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    return _isUsernameAvailable == true &&
        name.isNotEmpty &&
        email.isNotEmpty &&
        password.length >= 6 &&
        _isNotRobot;
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
        backgroundColor: const Color(0xFFF8F9FA), // App Bg
        body: Stack(
          children: [
            // Background Gradient
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xFFF8F9FA),
                      Color(0xCCF8F9FA), // 80%
                      Color(0x33F8F9FA), // 20%
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
                        'Create Account',
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
                        'Join DriveGlow for premium fleet care',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // -- Name Field --
                      _buildLabel('FULL NAME'),
                      const SizedBox(height: 8),
                      _buildInput(
                        controller: _nameController,
                        hintText: 'John Doe',
                        prefixIcon: Icons.person_outline,
                      ),
                      const SizedBox(height: 20),

                      // -- Username Field --
                      _buildLabel('USERNAME'),
                      const SizedBox(height: 8),
                      _buildUsernameInput(
                        controller: _usernameController,
                        hintText: 'john01',
                        prefixIcon: Icons.alternate_email,
                        onChanged: _checkUsernameAvailability,
                      ),
                      if (_usernameError != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _usernameError!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // -- Email Field --
                      _buildLabel('EMAIL OR USER ID'),
                      const SizedBox(height: 8),
                      _buildInput(
                        controller: _emailController,
                        hintText: 'name@example.com',
                        prefixIcon: Icons.alternate_email,
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

                      // -- Sign Up Button --
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (_isLoading || !_isFormValid) ? null : _handleSignup,
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
                                  'Sign Up',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // -- Divider --
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: Color(0xFFE5E7EB)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: Color(0xFFE5E7EB)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // -- Google Button --
                      SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _handleGoogleSignIn,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const FaIcon(
                                FontAwesomeIcons.google,
                                size: 20,
                                color: Colors.black,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Continue with Google',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF1A1A1A),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),

                      // -- Footer --
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: GoogleFonts.inter(
                              color: const Color(0xFF6B7280),
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            child: Text(
                              'Login',
                              style: GoogleFonts.inter(
                                color: PremiumTheme.orangePrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
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

  Widget _buildUsernameInput({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    required Function(String) onChanged,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isUsernameAvailable == true
              ? Colors.green
              : _isUsernameAvailable == false
                  ? Colors.red
                  : const Color(0xFFE5E7EB),
        ),
      ),
      child: TextField(
        controller: controller,
        maxLength: 8,
        style: GoogleFonts.inter(color: const Color(0xFF1A1A1A)),
        decoration: InputDecoration(
          hintText: hintText,
          counterText: '',
          hintStyle: GoogleFonts.inter(color: const Color(0xFF9CA3AF)),
          prefixIcon: Icon(
            prefixIcon,
            color: const Color(0xFF9CA3AF),
            size: 20,
          ),
          suffixIcon: _isUsernameChecking
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _isUsernameAvailable == true
                  ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                  : _isUsernameAvailable == false
                      ? const Icon(Icons.cancel, color: Colors.red, size: 20)
                      : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        onChanged: onChanged,
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
}
