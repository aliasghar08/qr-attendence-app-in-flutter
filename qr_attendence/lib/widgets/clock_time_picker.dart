import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ClockTimePickerCard extends StatefulWidget {
  final TimeOfDay initialStartTime;
  final int initialDurationMinutes;
  final ValueChanged<String> onTimeSlotChanged;

  const ClockTimePickerCard({
    super.key,
    required this.initialStartTime,
    this.initialDurationMinutes = 60,
    required this.onTimeSlotChanged,
  });

  @override
  State<ClockTimePickerCard> createState() => _ClockTimePickerCardState();
}

class _ClockTimePickerCardState extends State<ClockTimePickerCard> {
  late TimeOfDay _startTime;
  late int _durationMinutes;
  bool _isCustomEndTime = false;
  TimeOfDay? _customEndTime;

  final List<int> _presetDurations = [30, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _startTime = widget.initialStartTime;
    _durationMinutes = widget.initialDurationMinutes;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyChange();
    });
  }

  TimeOfDay get _endTime {
    if (_isCustomEndTime && _customEndTime != null) {
      return _customEndTime!;
    }
    final int startTotalMinutes = _startTime.hour * 60 + _startTime.minute;
    final int endTotalMinutes = (startTotalMinutes + _durationMinutes) % (24 * 60);
    return TimeOfDay(
      hour: endTotalMinutes ~/ 60,
      minute: endTotalMinutes % 60,
    );
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final int hour12 = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final String minute = tod.minute.toString().padLeft(2, '0');
    final String period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour12.toString().padLeft(2, '0')}:$minute $period';
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes mins';
    final int hours = minutes ~/ 60;
    final int remainingMins = minutes % 60;
    if (remainingMins == 0) {
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    }
    return '$hours hr $remainingMins min';
  }

  int _calculateDurationBetween(TimeOfDay start, TimeOfDay end) {
    int startMins = start.hour * 60 + start.minute;
    int endMins = end.hour * 60 + end.minute;
    if (endMins < startMins) {
      endMins += 24 * 60;
    }
    return endMins - startMins;
  }

  void _notifyChange() {
    final startStr = _formatTimeOfDay(_startTime);
    final endStr = _formatTimeOfDay(_endTime);
    final dur = _isCustomEndTime && _customEndTime != null
        ? _calculateDurationBetween(_startTime, _customEndTime!)
        : _durationMinutes;
    final formattedSlot = '$startStr - $endStr (${_formatDuration(dur)})';
    widget.onTimeSlotChanged(formattedSlot);
  }

  Future<void> _pickStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'SELECT LECTURE START TIME',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _startTime = picked;
      });
      _notifyChange();
    }
  }

  Future<void> _pickCustomEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      helpText: 'SELECT LECTURE END TIME',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _isCustomEndTime = true;
        _customEndTime = picked;
      });
      _notifyChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentDuration = _isCustomEndTime && _customEndTime != null
        ? _calculateDurationBetween(_startTime, _customEndTime!)
        : _durationMinutes;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.access_time_filled_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Lecture Time & Duration',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondarySurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.secondaryLight),
                ),
                child: Text(
                  _formatDuration(currentDuration),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Start and End Time interactive selector cards
          Row(
            children: [
              // Start Time
              Expanded(
                child: InkWell(
                  onTap: _pickStartTime,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.play_circle_outline_rounded,
                                size: 14, color: AppColors.textSecondary),
                            SizedBox(width: 4),
                            Text(
                              'Starts at',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _formatTimeOfDay(_startTime),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.schedule_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded,
                    color: AppColors.textMuted, size: 18),
              ),
              // End Time
              Expanded(
                child: InkWell(
                  onTap: _pickCustomEndTime,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isCustomEndTime ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.stop_circle_outlined,
                                size: 14, color: AppColors.textSecondary),
                            SizedBox(width: 4),
                            Text(
                              'Ends at',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _formatTimeOfDay(_endTime),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.edit_calendar_rounded,
                              size: 16,
                              color: AppColors.secondaryDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Duration presets chips
          const Text(
            'Quick Duration Presets:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._presetDurations.map((mins) {
                  final isSelected = !_isCustomEndTime && _durationMinutes == mins;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_formatDuration(mins)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _isCustomEndTime = false;
                            _durationMinutes = mins;
                          });
                          _notifyChange();
                        }
                      },
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.background,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                    ),
                  );
                }),
                ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 14),
                      SizedBox(width: 4),
                      Text('Custom End'),
                    ],
                  ),
                  selected: _isCustomEndTime,
                  onSelected: (selected) {
                    _pickCustomEndTime();
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.background,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _isCustomEndTime ? FontWeight.w700 : FontWeight.w500,
                    color: _isCustomEndTime ? Colors.white : AppColors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: _isCustomEndTime ? AppColors.primary : AppColors.border,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
