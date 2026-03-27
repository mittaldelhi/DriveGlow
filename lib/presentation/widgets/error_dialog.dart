import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? errorCode;
  final String? additionalInfo;
  final VoidCallback? onDismiss;
  final bool isDarkMode;

  const ErrorDialog({
    super.key,
    this.title = 'Error',
    required this.message,
    this.errorCode,
    this.additionalInfo,
    this.onDismiss,
    this.isDarkMode = false,
  });

  static Future<void> show(
    BuildContext context, {
    String title = 'Error',
    required String message,
    String? errorCode,
    String? additionalInfo,
    bool isDarkMode = false,
    VoidCallback? onDismiss,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ErrorDialog(
        title: title,
        message: message,
        errorCode: errorCode,
        additionalInfo: additionalInfo,
        isDarkMode: isDarkMode,
        onDismiss: onDismiss,
      ),
    );
  }

  String _getFormattedError() {
    final buffer = StringBuffer();
    buffer.writeln('=== ERROR DETAILS ===');
    buffer.writeln('Timestamp: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    buffer.writeln('Title: $title');
    if (errorCode != null) buffer.writeln('Error Code: $errorCode');
    buffer.writeln('');
    buffer.writeln('=== ERROR MESSAGE ===');
    buffer.writeln(message);
    if (additionalInfo != null) {
      buffer.writeln('');
      buffer.writeln('=== ADDITIONAL INFO ===');
      buffer.writeln(additionalInfo);
    }
    buffer.writeln('');
    buffer.writeln('=== TROUBLESHOOTING ===');
    buffer.writeln('1. Check your internet connection');
    buffer.writeln('2. Verify your login credentials');
    buffer.writeln('3. Try refreshing the page');
    buffer.writeln('4. Contact support if issue persists');
    
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isWideScreen = screenSize.width > 600;
    
    return Dialog(
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: isWideScreen ? 500 : screenSize.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 450),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onDismiss?.call();
                  },
                  icon: Icon(
                    Icons.close,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode 
                      ? const Color(0xFF2D2D2D) 
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode 
                        ? Colors.grey[700]! 
                        : Colors.grey[300]!,
                  ),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    message,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            if (errorCode != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.tag,
                    size: 14,
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Code: $errorCode',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDismiss?.call();
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Dismiss'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                      side: BorderSide(
                        color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final errorText = _getFormattedError();
                      await Clipboard.setData(ClipboardData(text: errorText));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Error details copied to clipboard'),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Error'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF0541E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
