import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_clock.dart';
import '../services/app_localization.dart';
import '../theme/app_theme.dart';

class LiveClock extends StatefulWidget {
  const LiveClock({super.key});
  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> with WidgetsBindingObserver {
  late final Timer _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = AppClock.now();
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(Icons.schedule_outlined, size: 16, color: AppColors.textMuted),
        Text(
          '${AppClock.date(now)} · ${AppClock.time(now)}',
          style: AppTextTheme.caption.copyWith(
            fontFeatures: [const FontFeature.tabularFigures()],
          ),
        ),
        LocalizedText('Giờ Việt Nam (GMT+7)', style: AppTextTheme.caption),
      ],
    );
  }
}
