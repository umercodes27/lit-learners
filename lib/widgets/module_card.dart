import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
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
      Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.ink.withValues(alpha: 0.72),
            fontWeight: FontWeight.w600,
          ),
      textDirection,
    );

    return Semantics(
      button: true,
      label: 'Open ${module.title}',
      child: Material(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.14),
          AppColors.panel,
        ),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withValues(alpha: 0.24)),
        ),
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
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        right: -6,
                        top: -10,
                        child: _DecorativeDot(
                          color: color.withValues(alpha: 0.14),
                          size: 48,
                        ),
                      ),
                      Positioned(
                        left: 8,
                        bottom: 4,
                        child: _DecorativeDot(
                          color: AppColors.honey.withValues(alpha: 0.32),
                          size: 20,
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.16),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            ModuleVisuals.iconFor(module.category),
                            color: color,
                            size: 38,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: Icon(
                          Icons.arrow_outward_rounded,
                          color: color.withValues(alpha: 0.72),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
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
      ),
    );
  }
}

class _DecorativeDot extends StatelessWidget {
  const _DecorativeDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
