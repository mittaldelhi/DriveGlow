import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class TimeSlotPicker extends StatefulWidget {
  final DateTime? selectedDate;
  final String? selectedTime;
  final bool showDatePicker;
  final int maxDaysAhead;
  final Function(DateTime date, String time) onConfirm;

  const TimeSlotPicker({
    super.key,
    this.selectedDate,
    this.selectedTime,
    this.showDatePicker = true,
    this.maxDaysAhead = 7,
    required this.onConfirm,
  });

  @override
  State<TimeSlotPicker> createState() => _TimeSlotPickerState();
}

class _TimeSlotPickerState extends State<TimeSlotPicker> {
  late DateTime _selectedDate;
  String? _selectedTime;

  // Time slots: 9:00 AM to 7:30 PM (30-min intervals)
  static const List<String> timeSlots = [
    '09:00 AM',
    '09:30 AM',
    '10:00 AM',
    '10:30 AM',
    '11:00 AM',
    '11:30 AM',
    '12:00 PM',
    '12:30 PM',
    '01:00 PM',
    '01:30 PM',
    '02:00 PM',
    '02:30 PM',
    '03:00 PM',
    '03:30 PM',
    '04:00 PM',
    '04:30 PM',
    '05:00 PM',
    '05:30 PM',
    '06:00 PM',
    '06:30 PM',
    '07:00 PM',
    '07:30 PM',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now();
    _selectedTime = widget.selectedTime;
  }

  bool get _canGoToPreviousDay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return selected.isAfter(today);
  }

  bool get _canGoToNextDay {
    final now = DateTime.now();
    final maxDate = now.add(Duration(days: widget.maxDaysAhead));
    final today = DateTime(now.year, now.month, now.day);
    final maxAllowed = DateTime(maxDate.year, maxDate.month, maxDate.day);
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return selected.isBefore(maxAllowed);
  }

  void _previousDay() {
    if (_canGoToPreviousDay) {
      setState(() {
        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
        _selectedTime = null;
      });
    }
  }

  void _nextDay() {
    if (_canGoToNextDay) {
      setState(() {
        _selectedDate = _selectedDate.add(const Duration(days: 1));
        _selectedTime = null;
      });
    }
  }

  String _getDateLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    if (selected == today) {
      return 'Today, ${DateFormat('dd MMM yyyy').format(_selectedDate)}';
    } else if (selected == tomorrow) {
      return 'Tomorrow, ${DateFormat('dd MMM yyyy').format(_selectedDate)}';
    } else {
      return DateFormat('EEEE, dd MMM yyyy').format(_selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40),
                Text(
                  'Select Time Slot',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Date selector
          if (widget.showDatePicker)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _canGoToPreviousDay ? _previousDay : null,
                      icon: Icon(
                        Icons.chevron_left,
                        color: _canGoToPreviousDay ? Colors.black : Colors.grey[300],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          _getDateLabel(),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _canGoToNextDay ? _nextDay : null,
                      icon: Icon(
                        Icons.chevron_right,
                        color: _canGoToNextDay ? Colors.black : Colors.grey[300],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Time slots
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: timeSlots.length,
              itemBuilder: (context, index) {
                final slot = timeSlots[index];
                final isSelected = _selectedTime == slot;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTime = slot;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? const Color(0xFFE57A1F) 
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? const Color(0xFFE57A1F) 
                            : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        slot,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Confirm button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _selectedTime != null
                    ? () {
                        widget.onConfirm(_selectedDate, _selectedTime!);
                        Navigator.pop(context);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE57A1F),
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Confirm Time Slot',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
