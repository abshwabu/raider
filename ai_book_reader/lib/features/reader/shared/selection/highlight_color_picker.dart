import 'package:flutter/material.dart';
import '../../../../data/models/annotation.dart';
import 'annotation_colors.dart';

Future<AnnotationColor?> showHighlightColorPicker(BuildContext context) {
  return showModalBottomSheet<AnnotationColor>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Highlight color',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AnnotationColor.values.map((color) {
                return InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => Navigator.of(context).pop(color),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.swatchColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(color.label, style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    },
  );
}
