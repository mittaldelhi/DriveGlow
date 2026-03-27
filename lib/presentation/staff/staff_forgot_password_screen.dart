import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shinex/theme/app_theme.dart';

import '../../application/helpers/error_helper.dart';

class StaffForgotPasswordScreen extends StatefulWidget {
  const StaffForgotPasswordScreen({super.key});

  @override
  State<StaffForgotPasswordScreen> createState() => _StaffForgotPasswordScreenState();
}

class _StaffForgotPasswordScreenState extends State<StaffForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _staffIdController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _loading = false;
  bool _requestSent = false;

  Future<void> _submitRequest() async {
    if (_emailController.text.trim().isEmpty || _staffIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Staff ID and Email')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final staffId = _staffIdController.text.trim();

      // Use RPC function to lookup user
      final result = await Supabase.instance.client
          .rpc('lookup_staff_user', params: {'p_login_input': staffId});

      if (result == null || result.isEmpty) {
        throw Exception('Invalid Staff ID.');
      }

      final staffRow = Map<String, dynamic>.from(result.first);
      final staffUserId = staffRow['id'] as String;

      // Get email from auth.users via RPC
      final registeredEmail = await Supabase.instance.client
          .rpc('get_user_email', params: {'p_user_id': staffUserId}) ?? '';

      final inputEmail = _emailController.text.trim().toLowerCase();

      if (registeredEmail.toLowerCase() != inputEmail) {
        throw Exception('Email does not match our records.');
      }

      final existingRequest = await Supabase.instance.client
          .from('staff_requests')
          .select()
          .eq('staff_user_id', staffUserId)
          .eq('status', 'pending')
          .maybeSingle();

      if (existingRequest != null) {
        throw Exception('A request is already pending. Please wait for admin response.');
      }

      await Supabase.instance.client
          .from('staff_requests')
          .insert({
            'staff_user_id': staffUserId,
            'request_type': 'password_reset',
            'description': _descriptionController.text.trim().isEmpty 
                ? 'Password reset requested' 
                : _descriptionController.text.trim(),
            'status': 'pending',
          });

      setState(() => _requestSent = true);
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _staffIdController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_requestSent) {
      return Scaffold(
        backgroundColor: PremiumTheme.surfaceBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.hourglass_empty, size: 50, color: Colors.orange),
                ),
                const SizedBox(height: 24),
                Text('Request Submitted', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: PremiumTheme.darkBg)),
                const SizedBox(height: 12),
                Text(
                  'Your password reset request has been sent to admin. Admin will set a new password and contact you.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: PremiumTheme.greyText),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: PremiumTheme.orangePrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('Back to Login', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: PremiumTheme.surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(color: PremiumTheme.orangePrimary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.lock_reset, size: 40, color: PremiumTheme.orangePrimary),
                ),
              ),
              const SizedBox(height: 24),
              Text('Password Reset Request', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: PremiumTheme.darkBg)),
              const SizedBox(height: 8),
              Text(
                'Enter your Staff ID and email. Admin will set a new password for you.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: PremiumTheme.greyText),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _staffIdController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(labelText: 'Staff ID', hintText: 'Enter your employee ID', prefixIcon: const Icon(Icons.badge_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'Email', hintText: 'Enter your registered email', prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(labelText: 'Description (Optional)', hintText: 'Any additional info for admin', prefixIcon: const Icon(Icons.notes), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(backgroundColor: PremiumTheme.orangePrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  child: _loading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Submit Request', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
