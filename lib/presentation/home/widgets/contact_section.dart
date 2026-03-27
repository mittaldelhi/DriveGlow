import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shinex/theme/app_theme.dart';

class ContactSection extends StatelessWidget {
  final String? phone;
  final String? address;
  final String? email;
  final String? openHours;
  
  const ContactSection({
    super.key,
    this.phone,
    this.address,
    this.email,
    this.openHours,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Us',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          // Contact Info Cards
          _buildContactCard(
            icon: Icons.location_on_rounded,
            title: 'Address',
            content: address ?? 'Drive Glow studio, Besides Hari Ram Hospital, Bhiwadi, Rajasthan, India 301019',
            color: Colors.red,
          ),
          const SizedBox(height: 12),
          _buildContactCard(
            icon: Icons.phone_rounded,
            title: 'Phone',
            content: phone ?? '+91 9999081105',
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildContactCard(
            icon: Icons.email_rounded,
            title: 'Email',
            content: email ?? 'contact@driveglow.com',
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildContactCard(
            icon: Icons.access_time_rounded,
            title: 'Open Hours',
            content: openHours ?? 'Mon-Sat: 9:00 AM - 7:00 PM',
            color: Colors.orange,
          ),
          const SizedBox(height: 24),
          // Social Media Icons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSocialIcon(Icons.facebook_rounded, Colors.blue),
              const SizedBox(width: 16),
              _buildSocialIcon(Icons.camera_alt_rounded, Colors.pink),
              const SizedBox(width: 16),
              _buildSocialIcon(Icons.chat_rounded, Colors.green),
              const SizedBox(width: 16),
              _buildSocialIcon(Icons.phone_rounded, Colors.teal),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
