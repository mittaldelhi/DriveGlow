import 'package:flutter/material.dart';
import '../../presentation/widgets/error_dialog.dart';

void showErrorDialog(
  BuildContext context, {
  String title = 'Error',
  required String message,
  String? errorCode,
  String? additionalInfo,
  VoidCallback? onDismiss,
}) {
  ErrorDialog.show(
    context,
    title: title,
    message: message,
    errorCode: errorCode,
    additionalInfo: additionalInfo,
    onDismiss: onDismiss,
  );
}

void showErrorSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 4),
  Color? backgroundColor,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor ?? Colors.red[700],
      behavior: SnackBarBehavior.floating,
      duration: duration,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}

void showSuccessSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.green[700],
      behavior: SnackBarBehavior.floating,
      duration: duration,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}

String formatErrorForCopy(String error, {String? context, String? operation}) {
  final buffer = StringBuffer();
  buffer.writeln('=== DRIVEGLOW ERROR REPORT ===');
  buffer.writeln('Date: ${DateTime.now().toIso8601String()}');
  if (context != null) buffer.writeln('Context: $context');
  if (operation != null) buffer.writeln('Operation: $operation');
  buffer.writeln('');
  buffer.writeln('=== ERROR MESSAGE ===');
  buffer.writeln(error);
  buffer.writeln('');
  buffer.writeln('=== STEPS TO REPRODUCE ===');
  buffer.writeln('1. ');
  buffer.writeln('2. ');
  buffer.writeln('3. ');
  buffer.writeln('');
  buffer.writeln('=== EXPECTED BEHAVIOR ===');
  buffer.writeln('');
  buffer.writeln('=== ACTUAL BEHAVIOR ===');
  buffer.writeln('');
  return buffer.toString();
}
