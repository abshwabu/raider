import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/local/reading_stats_repository.dart';
import '../../../../data/models/daily_reading_stat.dart';
import '../../services/reading_reminder_service.dart';

/// Diagonal line pattern painter for the streak hero card overlay.
class _DiagonalPatternPainter extends CustomPainter {
  const _DiagonalPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const spacing = 18.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ReadingStatsScreen extends ConsumerStatefulWidget {
  const ReadingStatsScreen({super.key});

  @override
  ConsumerState<ReadingStatsScreen> createState() => _ReadingStatsScreenState();
}

class _ReadingStatsScreenState extends ConsumerState<ReadingStatsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  ReadingStreakSummary? _summary;
  List<DailyReadingStat> _recentStats = [];
  bool _hourlyReminderEnabled = true;
  int _startHour = 8;
  int _startMinute = 0;
  bool _hasNotificationPermission = true;

  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _loadStatsAndPreferences();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _loadStatsAndPreferences() async {
    try {
      final statsRepo = ref.read(readingStatsRepositoryProvider);
      final reminderService = ref.read(readingReminderServiceProvider);

      final summary = await statsRepo.getStreakSummary();
      final recent = await statsRepo.getRecentStats(days: 7);
      final enabled = await reminderService.isEnabled();
      final startHour = await reminderService.getStartHour();
      final startMinute = await reminderService.getStartMinute();
      final hasPerm = await reminderService.hasNotificationPermission();

      if (mounted) {
        setState(() {
          _summary = summary;
          _recentStats = recent;
          _hourlyReminderEnabled = enabled;
          _startHour = startHour;
          _startMinute = startMinute;
          _hasNotificationPermission = hasPerm;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleHourlyReminder(bool value) async {
    final reminderService = ref.read(readingReminderServiceProvider);
    await reminderService.setEnabled(value);
    setState(() {
      _hourlyReminderEnabled = value;
    });

    if (value && !_hasNotificationPermission) {
      await reminderService.requestNotificationPermission();
      final hasPerm = await reminderService.hasNotificationPermission();
      if (mounted) {
        setState(() => _hasNotificationPermission = hasPerm);
      }
    }

    if (mounted) {
      final timeStr = TimeOfDay(hour: _startHour, minute: _startMinute).format(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Reminders enabled (starting daily at $timeStr)'
                : 'Daily reminders disabled',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _changeStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _startHour, minute: _startMinute),
      helpText: 'SELECT MORNING REMINDER TIME',
    );

    if (picked != null) {
      final reminderService = ref.read(readingReminderServiceProvider);
      await reminderService.setStartTime(
        hour: picked.hour,
        minute: picked.minute,
      );

      if (mounted) {
        setState(() {
          _startHour = picked.hour;
          _startMinute = picked.minute;
        });

        final formatted = picked.format(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminders will start automatically at $formatted every day'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showAdjustGoalDialog() async {
    final statsRepo = ref.read(readingStatsRepositoryProvider);
    final currentGoal = _summary?.todayGoalMinutes ?? 30;
    int selectedGoal = currentGoal;

    const goals = [10, 15, 20, 30, 45, 60, 90, 120];

    final chosen = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final sheetTheme = Theme.of(context);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daily Reading Goal',
                          style: sheetTheme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose how many minutes you want to read each day:',
                      style: sheetTheme.textTheme.bodyMedium?.copyWith(
                            color: sheetTheme.colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: goals.map((mins) {
                        final isSelected = mins == selectedGoal;
                        return ChoiceChip(
                          label: Text('$mins mins'),
                          selected: isSelected,
                          selectedColor: sheetTheme.colorScheme.primaryContainer,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => selectedGoal = mins);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, selectedGoal),
                        child: const Text('Save Daily Goal'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (chosen != null && chosen != currentGoal) {
      await statsRepo.setDailyGoal(chosen);
      final reminderService = ref.read(readingReminderServiceProvider);
      final today = await statsRepo.getOrCreateTodayStat();
      await reminderService.syncGoalStatus(
        isGoalMet: today.isGoalMet,
        activeSeconds: today.activeSeconds,
        goalMinutes: today.goalMinutes,
      );
      statsRepo.notifyStatsChanged();
      await _loadStatsAndPreferences();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Daily reading goal updated to $chosen minutes!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _sendTestReminder() async {
    final reminderService = ref.read(readingReminderServiceProvider);
    final ok = await reminderService.sendTestReminder();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Test reminder notification sent! Check your notification tray.'
                : 'Unable to send notification. Please check system permissions.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatTotalTime(int totalSeconds) {
    if (totalSeconds < 60) return '$totalSeconds sec';
    final mins = totalSeconds ~/ 60;
    if (mins < 60) return '$mins mins';
    final hrs = mins ~/ 60;
    final remMins = mins % 60;
    return '${hrs}h ${remMins}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reading Goals & Stats')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final summary = _summary ??
        const ReadingStreakSummary(
          currentStreak: 0,
          longestStreak: 0,
          totalDaysRead: 0,
          totalReadingSeconds: 0,
          totalPagesRead: 0,
          todaySeconds: 0,
          todayPages: 0,
          todayGoalMinutes: 30,
          isTodayGoalMet: false,
        );

    final todayMinutes = summary.todayMinutes;
    final goalMinutes = summary.todayGoalMinutes;
    final progressFraction = summary.todayProgressFraction;
    final isMet = summary.isTodayGoalMet;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadStatsAndPreferences,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 100,
              floating: true,
              snap: true,
              pinned: true,
              title: const Text('Reading Goals & Stats'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_active_outlined),
                  tooltip: 'Send Test Notification',
                  onPressed: _sendTestReminder,
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 1. Streak Hero Card
                  _buildStreakHeroCard(theme, summary),
                  const SizedBox(height: 16),

                  // 2. Today's Goal Card
                  _buildTodayGoalCard(theme, todayMinutes, goalMinutes, progressFraction, isMet, summary.todayPages),
                  const SizedBox(height: 16),

                  // 3. Hourly Reminder Configuration Card
                  _buildReminderCard(theme),
                  const SizedBox(height: 16),

                  // 4. Weekly Activity Card (Last 7 Days)
                  _buildWeeklyActivityCard(theme, _recentStats, goalMinutes),
                  const SizedBox(height: 16),

                  // 5. All-Time Milestone Stats (2x2 Grid)
                  _buildAllTimeMilestonesCard(theme, summary),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakHeroCard(ThemeData theme, ReadingStreakSummary summary) {
    final hasStreak = summary.currentStreak > 0;
    final noStreakStart = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHigh
        : Colors.grey.shade800;
    final noStreakEnd = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHighest
        : Colors.grey.shade900;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: hasStreak
              ? [const Color(0xFFF05A28), const Color(0xFFEA3B52)]
              : [noStreakStart, noStreakEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: hasStreak
                ? const Color(0xFFF05A28).withValues(alpha: 0.3)
                : theme.shadowColor.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: const _DiagonalPatternPainter(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Fire icon with animated glow
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) {
                        final glowOpacity = 0.15 + (_glowController.value * 0.2);
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            boxShadow: hasStreak
                                ? [
                                    BoxShadow(
                                      color: Colors.orangeAccent.withValues(alpha: glowOpacity),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: const Icon(
                            Icons.local_fire_department_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasStreak
                                ? '${summary.currentStreak} Day Reading Streak!'
                                : 'Start Your Streak Today!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasStreak
                                ? 'Keep reading daily to build a lifelong habit.'
                                : 'Read any book for at least 1 min today to ignite the flame.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: 0.24), height: 1),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStreakMiniStat('BEST STREAK', '${summary.longestStreak} days'),
                    Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.24)),
                    _buildStreakMiniStat('TOTAL DAYS', '${summary.totalDaysRead} days'),
                    Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.24)),
                    _buildStreakMiniStat('STATUS', summary.isTodayGoalMet ? 'Goal Met 🎉' : 'In Progress 📖'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreakMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTodayGoalCard(
    ThemeData theme,
    int todayMinutes,
    int goalMinutes,
    double progressFraction,
    bool isMet,
    int todayPages,
  ) {
    final percent = (progressFraction * 100).toInt();
    final accentColor = isMet ? Colors.teal : theme.colorScheme.primary;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isMet ? Icons.verified_rounded : Icons.track_changes_rounded,
                      color: accentColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Today's Reading Goal",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _showAdjustGoalDialog,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Adjust'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Radial progress indicator
                SizedBox(
                  width: 56,
                  height: 56,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: progressFraction),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedValue, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: animatedValue,
                            strokeWidth: 5,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                            strokeCap: StrokeCap.round,
                          ),
                          Text(
                            '${(animatedValue * 100).toInt()}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: accentColor,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$todayMinutes',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '/ $goalMinutes mins',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isMet ? 'Goal Achieved 🎉' : '$percent% Completed',
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Animated linear progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: progressFraction),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, animatedValue, child) {
                  return LinearProgressIndicator(
                    value: animatedValue,
                    minHeight: 10,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.auto_stories_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  '$todayPages pages read today',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(ThemeData theme) {
    final timeOfDay = TimeOfDay(hour: _startHour, minute: _startMinute);
    final formattedStartTime = timeOfDay.format(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.alarm_on_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hourly Reminder',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Remind every hour until goal is met',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _hourlyReminderEnabled,
                  onChanged: _toggleHourlyReminder,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Morning Start Time Selector Tile
            InkWell(
              onTap: _hourlyReminderEnabled ? _changeStartTime : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _hourlyReminderEnabled
                      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hourlyReminderEnabled
                        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.5)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.wb_sunny_rounded,
                      color: _hourlyReminderEnabled
                          ? Colors.amber.shade700
                          : theme.colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Morning Start Time',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _hourlyReminderEnabled
                                  ? theme.textTheme.bodyMedium?.color
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'Automatic first reminder of the day',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _hourlyReminderEnabled
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formattedStartTime,
                            style: TextStyle(
                              color: _hourlyReminderEnabled
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.surface,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: _hourlyReminderEnabled
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.surface,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            Text(
              'When enabled, Raider automatically starts checking your reading progress at $formattedStartTime every morning and sends reminders every hour until you reach your daily reading goal. Once completed, reminders stop for the day.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _sendTestReminder,
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Send Test Reminder'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (!_hasNotificationPermission)
                  TextButton.icon(
                    onPressed: () async {
                      final reminderService = ref.read(readingReminderServiceProvider);
                      await reminderService.requestNotificationPermission();
                      final hasPerm = await reminderService.hasNotificationPermission();
                      if (mounted) {
                        setState(() => _hasNotificationPermission = hasPerm);
                      }
                    },
                    icon: const Icon(Icons.notifications_active_rounded, size: 16),
                    label: const Text('Allow Notifications'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyActivityCard(
    ThemeData theme,
    List<DailyReadingStat> recentStats,
    int goalMinutes,
  ) {
    final now = DateTime.now();
    final todayDateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Past 7 Days Activity',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Goal: ${goalMinutes}m/day',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 130,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: recentStats.map((stat) {
                  final dt = IsarReadingStatsRepository.parseDate(stat.date);
                  final dayLabel = _getDayShortName(dt.weekday);
                  final mins = stat.activeSeconds ~/ 60;
                  final isGoalAchieved = stat.isGoalMet || (stat.goalMinutes > 0 && mins >= stat.goalMinutes);
                  final double barFraction = (mins / (goalMinutes > 0 ? goalMinutes : 30)).clamp(0.0, 1.0);
                  final isToday = stat.date == todayDateStr;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isGoalAchieved)
                        const Icon(Icons.check_circle_rounded, color: Colors.teal, size: 14)
                      else
                        const SizedBox(height: 14),
                      const SizedBox(height: 4),
                      Text(
                        '${mins}m',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isGoalAchieved ? Colors.teal : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Goal line + animated bar
                      SizedBox(
                        width: isToday ? 22 : 16,
                        height: 70,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            // Background track
                            Container(
                              width: isToday ? 22 : 16,
                              height: 70,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            // Goal line marker
                            Positioned(
                              bottom: 70.0 * (goalMinutes > 0 ? 1.0 : 0.0) - 0.5,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 1,
                                color: theme.colorScheme.outline.withValues(alpha: 0.4),
                              ),
                            ),
                            // Animated fill bar
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: barFraction),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutCubic,
                              builder: (context, animVal, child) {
                                final barHeight = (animVal * 70).clamp(animVal > 0 ? 6.0 : 0.0, 70.0);
                                return Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: isToday ? 22 : 16,
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: isGoalAchieved
                                          ? Colors.teal
                                          : (isToday
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.primary.withValues(alpha: 0.7)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dayLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: isToday
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllTimeMilestonesCard(ThemeData theme, ReadingStreakSummary summary) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All-Time Reading Milestones',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMilestoneTile(
                    theme,
                    icon: Icons.timer_outlined,
                    label: 'Total Read Time',
                    value: _formatTotalTime(summary.totalReadingSeconds),
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMilestoneTile(
                    theme,
                    icon: Icons.auto_stories_rounded,
                    label: 'Total Pages Read',
                    value: '${summary.totalPagesRead}',
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMilestoneTile(
                    theme,
                    icon: Icons.calendar_month_outlined,
                    label: 'Active Days',
                    value: '${summary.totalDaysRead} days',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMilestoneTile(
                    theme,
                    icon: Icons.emoji_events_outlined,
                    label: 'Best Streak',
                    value: '${summary.longestStreak} days',
                    color: Colors.amber.shade800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneTile(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _getDayShortName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }
}
