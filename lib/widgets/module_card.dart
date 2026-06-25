import 'package:flutter/material.dart';

import '../core/utils/learning_text_direction.dart';
import '../core/utils/module_visuals.dart';
import '../models/learning_module.dart';

class ModuleCard extends StatelessWidget {
  const ModuleCard({
    required this.module,
    required this.onTap,
    super.key,
  });

  final LearningModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = ModuleVisuals.colorFor(module.category);
    final textDirection = LearningTextDirection.forModule(module);
    final titleStyle = LearningTextDirection.styleFor(
      Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
      textDirection,
    );
    final bodyStyle = LearningTextDirection.styleFor(
      Theme.of(context).textTheme.bodySmall,
      textDirection,
    );

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: textDirection == TextDirection.rtl
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    ModuleVisuals.iconFor(module.category),
                    color: color,
                    size: 28,
                  ),
                ),
              ),
              const Spacer(),
              Directionality(
                textDirection: textDirection,
                child: Text(
                  module.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: LearningTextDirection.alignFor(textDirection),
                  style: titleStyle,
                ),
              ),
              const SizedBox(height: 4),
              Directionality(
                textDirection: textDirection,
                child: Text(
                  module.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: LearningTextDirection.alignFor(textDirection),
                  style: bodyStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
