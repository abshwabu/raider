import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/local/reading_stats_repository.dart';
import '../../../../data/models/daily_reading_stat.dart';
import '../../services/reading_reminder_service.dart';

class ReadingStatsScreen extends ConsumerStatefulWidget {
  const ReadingStatsScreen({super.key});

  @override
  ConsumerState<ReadingStatsScreen> createState() => _ReadingStatsScreenState();
}

class _ReadingStatsScreenState extends ConsumerState<ReadingStatsScreen> {
  bool _isLoading = true;
  ReadingStreakSummary? _summary;
  List<DailyReadingStat> _recentStats = [];
  bool _hourlyReminderEnabled = true;
  bool _hasNotificationPermission = true;

  @override
  void initState() {
    super.initState();
    _loadStatsAndPreferences();
  }

  Future<void> _loadStatsAndPreferences() async {
    try {
      final statsRepo = ref.read(readingStatsRepositoryProvider);
      final reminderService = ref.read(readingReminderServiceProvider);

      final summary = await statsRepo.getStreakSummary();
      final recent = await statsRepo.getRecentStats(days: 7);
      final enabled = await reminderService.isEnabled();
      final hasPerm = await reminderService.hasNotificationPermission();

      if (mounted) {
        setState(() {
          _summary = summary;
          _recentStats = recent;
          _hourlyReminderEnabled = enabled;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Hourly reminder enabled until goal is met'
                : 'Hourly reminder disabled',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showAdjustGoalDialog() async {
    final statsRepo = ref.read(readingStatsRepositoryProvider);
    final currentGoal = _summary?.todayGoalMinutes ?? 30;
    int selectedGoal = currentGoal;

    final goals = [10, 15, 20, 30, 45, 60, 90, 120];

    final chosen = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
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
                          selectedColor: Theme.of(context).colorScheme.primaryContainer,
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
      appBar: AppBar(
        title: const Text('Reading Goals & Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Send Test Notification',
            onPressed: _sendTestReminder,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStatsAndPreferences,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
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
          ],
        ),
      ),
    );
  }

  Widget _buildStreakHeroCard(ThemeData theme, ReadingStreakSummary summary) {
    final hasStreak = summary.currentStreak > 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: hasStreak
              ? [const Color(0xFFF05A28), const Color(0xFFEA3B52)]
              : [Colors.grey.shade800, Colors.grey.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: hasStreak
                ? const Color(0xFFF05A28).withOpacity(0.3)
                : Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 36,
                ),
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
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStreakMiniStat('BEST STREAK', '${summary.longestStreak} days'),
              Container(width: 1, height: 24, color: Colors.white24),
              _buildStreakMiniStat('TOTAL DAYS', '${summary.totalDaysRead} days'),
              Container(width: 1, height: 24, color: Colors.white24),
              _buildStreakMiniStat('STATUS', summary.isTodayGoalMet ? 'Goal Met 🎉' : 'In Progress 📖'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
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
                      color: isMet ? Colors.teal : theme.colorScheme.primary,
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
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$todayMinutes',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isMet ? Colors.teal : theme.colorScheme.primary,
                  ),
                ),
                Text(
                  ' / $goalMinutes mins',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMet
                        ? Colors.teal.withOpacity(0.12)
                        : theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isMet ? 'Goal Achieved 🎉' : '$percent% Completed',
                    style: TextStyle(
                      color: isMet ? Colors.teal : theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressFraction,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isMet ? Colors.teal : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.auto_stories_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  '$todayPages pages read today',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
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
                          color: Colors.grey.shade600,
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
            const SizedBox(height: 10),
            Text(
              'When enabled, Raider automatically checks your reading progress and sends a notification every hour until you reach your daily reading goal. Once completed, reminders stop for the day.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
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
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: recentStats.map((stat) {
                final dt = IsarReadingStatsRepository.parseDate(stat.date);
                final dayLabel = _getDayShortName(dt.weekday);
                final mins = stat.activeSeconds ~/ 60;
                final isGoalAchieved = stat.isGoalMet || (stat.goalMinutes > 0 && mins >= stat.goalMinutes);
                final double barFraction = (mins / (goalMinutes > 0 ? goalMinutes : 30)).clamp(0.0, 1.0);

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
                        color: isGoalAchieved ? Colors.teal : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 16,
                      height: 70,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 16,
                        height: (barFraction * 70).clamp(barFraction > 0 ? 6.0 : 0.0, 70.0),
                        decoration: BoxDecoration(
                          color: isGoalAchieved ? Colors.teal : theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dayLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }).toList(),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
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
