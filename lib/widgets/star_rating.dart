import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class StarRating extends StatelessWidget {
  const StarRating({
    required this.count,
    super.key,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final filled = index < count;
        return Icon(
          filled ? Icons.star : Icons.star_border,
          color: filled ? AppColors.honey : Colors.black38,
          size: 20,
        );
      }),
    );
  }
}
