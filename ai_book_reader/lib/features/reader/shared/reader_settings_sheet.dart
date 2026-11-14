import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'reader_preferences.dart';

void showReaderSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const ReaderSettingsSheet(),
  );
}

class ReaderSettingsSheet extends ConsumerStatefulWidget {
  const ReaderSettingsSheet({super.key});

  @override
  ConsumerState<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends ConsumerState<ReaderSettingsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(readerPreferencesProvider);
    final notifier = ref.read(readerPreferencesProvider.notifier);
    final theme = Theme.of(context);
    final currentThemeMode = prefs.themeMode;

    return Container(
      decoration: BoxDecoration(
        color: currentThemeMode.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: currentThemeMode.borderColor, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: currentThemeMode.textColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reading Appearance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: currentThemeMode.textColor,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  foregroundColor: currentThemeMode.accentColor,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => notifier.resetToDefaults(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: currentThemeMode.backgroundColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: currentThemeMode.borderColor),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: currentThemeMode.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: currentThemeMode.accentColor.withValues(alpha: 0.5)),
              ),
              labelColor: currentThemeMode.accentColor,
              unselectedLabelColor: currentThemeMode.textColor.withValues(alpha: 0.7),
              tabs: const [
                Tab(
                  icon: Icon(Icons.palette_outlined, size: 18),
                  text: 'Themes',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: Icon(Icons.text_fields_rounded, size: 18),
                  text: 'Typography',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab content
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildThemesTab(prefs, notifier),
                _buildTypographyTab(prefs, notifier, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemesTab(
      ReaderPreferences prefs, ReaderPreferencesNotifier notifier) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COLOR PALETTES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: prefs.themeMode.textColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ReaderThemeMode.values.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.1,
            ),
            itemBuilder: (context, index) {
              final mode = ReaderThemeMode.values[index];
              final isSelected = mode == prefs.themeMode;

              return InkWell(
                onTap: () => notifier.updateTheme(mode),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: mode.backgroundColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? mode.accentColor : mode.borderColor,
                      width: isSelected ? 2.5 : 1.2,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: mode.accentColor.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: mode.cardColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: mode.borderColor),
                        ),
                        child: Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: mode.accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              mode.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: mode.textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              mode.description,
                              style: TextStyle(
                                fontSize: 10,
                                color: mode.textColor.withValues(alpha: 0.65),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: mode.accentColor,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Live preview card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: prefs.themeMode.backgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: prefs.themeMode.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reading Preview',
                  style: prefs.getTextStyle(
                    overrideFontSize: 14,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'The quick brown fox jumps over the lazy dog. Raider empowers you with intelligence, focus, and speed.',
                  style: prefs.getTextStyle(
                    overrideFontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypographyTab(
    ReaderPreferences prefs,
    ReaderPreferencesNotifier notifier,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Font Family
          Text(
            'FONT FAMILY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: prefs.themeMode.textColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: ReaderFontFamily.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final font = ReaderFontFamily.values[index];
                final isSelected = font == prefs.fontFamily;
                final previewStyle = prefs
                    .copyWith(fontFamily: font)
                    .getTextStyle(overrideFontSize: 13);

                return InkWell(
                  onTap: () => notifier.updateFont(font),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 120,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? prefs.themeMode.accentColor.withValues(alpha: 0.15)
                          : prefs.themeMode.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? prefs.themeMode.accentColor
                            : prefs.themeMode.borderColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          font.name,
                          style: previewStyle.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? prefs.themeMode.accentColor
                                : prefs.themeMode.textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          font.label,
                          style: TextStyle(
                            fontSize: 9,
                            color: prefs.themeMode.textColor.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // Font Size Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FONT SIZE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: prefs.themeMode.textColor.withValues(alpha: 0.6),
                ),
              ),
              Text(
                '${prefs.fontSize.toInt()} pt',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: prefs.themeMode.accentColor,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                color: prefs.themeMode.textColor.withValues(alpha: 0.7),
                onPressed: prefs.fontSize > 12.0
                    ? () => notifier.updateFontSize(prefs.fontSize - 1.0)
                    : null,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: prefs.themeMode.accentColor,
                    thumbColor: prefs.themeMode.accentColor,
                    inactiveTrackColor:
                        prefs.themeMode.borderColor.withValues(alpha: 0.6),
                  ),
                  child: Slider(
                    value: prefs.fontSize,
                    min: 12.0,
                    max: 34.0,
                    divisions: 22,
                    label: '${prefs.fontSize.toInt()} pt',
                    onChanged: (val) => notifier.updateFontSize(val),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                color: prefs.themeMode.textColor.withValues(alpha: 0.7),
                onPressed: prefs.fontSize < 34.0
                    ? () => notifier.updateFontSize(prefs.fontSize + 1.0)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Line Spacing
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LINE SPACING',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: prefs.themeMode.textColor.withValues(alpha: 0.6),
                ),
              ),
              Text(
                '${prefs.lineHeight.toStringAsFixed(1)}x',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: prefs.themeMode.accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildChoiceChip(
                label: 'Tight (1.3)',
                selected: (prefs.lineHeight - 1.3).abs() < 0.05,
                prefs: prefs,
                onTap: () => notifier.updateLineHeight(1.3),
              ),
              const SizedBox(width: 8),
              _buildChoiceChip(
                label: 'Normal (1.6)',
                selected: (prefs.lineHeight - 1.6).abs() < 0.05,
                prefs: prefs,
                onTap: () => notifier.updateLineHeight(1.6),
              ),
              const SizedBox(width: 8),
              _buildChoiceChip(
                label: 'Relaxed (1.9)',
                selected: (prefs.lineHeight - 1.9).abs() < 0.05,
                prefs: prefs,
                onTap: () => notifier.updateLineHeight(1.9),
              ),
              const SizedBox(width: 8),
              _buildChoiceChip(
                label: 'Spacious (2.2)',
                selected: (prefs.lineHeight - 2.2).abs() < 0.05,
                prefs: prefs,
                onTap: () => notifier.updateLineHeight(2.2),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Font Weight & Text Alignment Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weight
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEIGHT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: prefs.themeMode.textColor.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildChoiceChip(
                          label: 'Normal',
                          selected: prefs.fontWeightIndex == 0,
                          prefs: prefs,
                          onTap: () => notifier.updateFontWeightIndex(0),
                        ),
                        const SizedBox(width: 6),
                        _buildChoiceChip(
                          label: 'Medium',
                          selected: prefs.fontWeightIndex == 1,
                          prefs: prefs,
                          onTap: () => notifier.updateFontWeightIndex(1),
                        ),
                        const SizedBox(width: 6),
                        _buildChoiceChip(
                          label: 'Bold',
                          selected: prefs.fontWeightIndex == 3,
                          prefs: prefs,
                          onTap: () => notifier.updateFontWeightIndex(3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Alignment
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ALIGNMENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: prefs.themeMode.textColor.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildIconButton(
                          icon: Icons.format_align_left_rounded,
                          tooltip: 'Left Aligned',
                          selected: !prefs.isJustified,
                          prefs: prefs,
                          onTap: () {
                            if (prefs.isJustified) notifier.toggleJustified();
                          },
                        ),
                        const SizedBox(width: 6),
                        _buildIconButton(
                          icon: Icons.format_align_justify_rounded,
                          tooltip: 'Justified',
                          selected: prefs.isJustified,
                          prefs: prefs,
                          onTap: () {
                            if (!prefs.isJustified) notifier.toggleJustified();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Margins / Padding
          Text(
            'PAGE MARGINS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: prefs.themeMode.textColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildChoiceChip(
                label: 'Compact (12px)',
                selected: (prefs.horizontalPadding - 12.0).abs() < 1.0,
                prefs: prefs,
                onTap: () => notifier.updatePadding(12.0),
              ),
              const SizedBox(width: 8),
              _buildChoiceChip(
                label: 'Standard (20px)',
                selected: (prefs.horizontalPadding - 20.0).abs() < 1.0,
                prefs: prefs,
                onTap: () => notifier.updatePadding(20.0),
              ),
              const SizedBox(width: 8),
              _buildChoiceChip(
                label: 'Relaxed (32px)',
                selected: (prefs.horizontalPadding - 32.0).abs() < 1.0,
                prefs: prefs,
                onTap: () => notifier.updatePadding(32.0),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required ReaderPreferences prefs,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? prefs.themeMode.accentColor.withValues(alpha: 0.15)
                : prefs.themeMode.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? prefs.themeMode.accentColor
                  : prefs.themeMode.borderColor,
              width: selected ? 1.8 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected
                  ? prefs.themeMode.accentColor
                  : prefs.themeMode.textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required bool selected,
    required ReaderPreferences prefs,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? prefs.themeMode.accentColor.withValues(alpha: 0.15)
                : prefs.themeMode.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? prefs.themeMode.accentColor
                  : prefs.themeMode.borderColor,
              width: selected ? 1.8 : 1.0,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected
                ? prefs.themeMode.accentColor
                : prefs.themeMode.textColor,
          ),
        ),
      ),
    );
  }
}
