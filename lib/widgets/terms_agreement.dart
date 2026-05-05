import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';

class TermsAgreement extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const TermsAgreement({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          height: 1.35,
        );

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: (checked) => onChanged(checked ?? false),
              activeColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Kullanım Koşulları ve Topluluk Kuralları’nı kabul ediyorum. ',
                      style: style,
                    ),
                    GestureDetector(
                      onTap: () => context.push('/kullanim-kosullari'),
                      child: const Text(
                        'Koşulları aç',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Text('  '),
                    GestureDetector(
                      onTap: () => context.push('/gizlilik-politikasi'),
                      child: const Text(
                        'Gizlilik',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
