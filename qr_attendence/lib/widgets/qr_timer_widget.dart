import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/location_service.dart';
import '../services/security_service.dart';
import '../theme/app_colors.dart';

class QRTimerWidget extends StatefulWidget {
  final int totalSeconds;
  final VoidCallback onExpired;

  const QRTimerWidget({
    super.key,
    this.totalSeconds = 20,
    required this.onExpired,
  });

  @override
  State<QRTimerWidget> createState() => QRTimerWidgetState();
}

class QRTimerWidgetState extends State<QRTimerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.totalSeconds),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onExpired();
        restart();
      }
    });

    _controller.forward();
  }

  void restart() {
    if (mounted) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = 1.0 - _controller.value;
          final secondsRemaining = (progress * widget.totalSeconds).ceil();

          Color progressColor;
          if (secondsRemaining > 10) {
            progressColor = AppColors.successDark;
          } else if (secondsRemaining > 5) {
            progressColor = AppColors.warning;
          } else {
            progressColor = AppColors.error;
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: progressColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Anti-Screenshot Dynamic Refresh',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${secondsRemaining}s remaining',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: progressColor,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class DynamicLectureQRWidget extends StatefulWidget {
  final String lectureId;
  final String classId;
  final String subject;
  final String date;
  final String timeSlot;
  final String teacherId;
  final String teacherName;
  final String department;
  final LocationData? locationData;
  final int refreshIntervalSeconds;
  final ValueChanged<String>? onCodeUpdated;

  const DynamicLectureQRWidget({
    super.key,
    required this.lectureId,
    required this.classId,
    required this.subject,
    required this.date,
    required this.timeSlot,
    required this.teacherId,
    required this.teacherName,
    required this.department,
    this.locationData,
    this.refreshIntervalSeconds = 20,
    this.onCodeUpdated,
  });

  @override
  State<DynamicLectureQRWidget> createState() => _DynamicLectureQRWidgetState();
}

class _DynamicLectureQRWidgetState extends State<DynamicLectureQRWidget>
    with SingleTickerProviderStateMixin {
  final _securityService = SecurityService();
  late String _currentPayload;
  int _nonce = 0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _generatePayload();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _generatePayload() {
    _nonce++;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Generate cryptographic token signature
    final signature = _securityService.generateTokenSignature(
      lectureId: widget.lectureId,
      subject: widget.subject,
      date: widget.date,
      timestampMs: nowMs,
      nonce: _nonce,
    );

    final payloadMap = {
      'lectureId': widget.lectureId,
      'classId': widget.classId,
      'subject': widget.subject,
      'date': widget.date,
      'timeSlot': widget.timeSlot,
      'teacherId': widget.teacherId,
      'teacherName': widget.teacherName,
      'department': widget.department,
      'location': widget.locationData?.toMap(),
      'nonce': _nonce,
      'timestamp': nowMs,
      'securitySignature': signature,
    };

    final payloadStr = jsonEncode(payloadMap);
    setState(() {
      _currentPayload = payloadStr;
    });

    widget.onCodeUpdated?.call(payloadStr);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Security Status Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.successLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.successDark,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: _pulseController.value),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              const Text(
                'Anti-Fraud Cryptographic Shield Active',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.successDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // QR Code Container with RepaintBoundary
        RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: QrImageView(
              data: _currentPayload,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.primaryDark,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Dynamic Countdown Timer
        QRTimerWidget(
          totalSeconds: widget.refreshIntervalSeconds,
          onExpired: _generatePayload,
        ),
      ],
    );
  }
}
