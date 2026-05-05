import 'package:flutter/material.dart';

import '../core/theme.dart';

class ModerationSheetResult {
  final String reason;
  final bool blockAuthor;

  const ModerationSheetResult({
    required this.reason,
    required this.blockAuthor,
  });
}

Future<ModerationSheetResult?> showReportBlockSheet({
  required BuildContext context,
  required String targetLabel,
  bool allowBlock = true,
}) {
  const reasons = [
    'Sakıncalı veya saldırgan içerik',
    'Taciz veya kötüye kullanım',
    'Nefret söylemi',
    'Spam veya yanıltıcı içerik',
    'Diğer',
  ];
  var selectedReason = reasons.first;
  var blockAuthor = allowBlock;

  return showModalBottomSheet<ModerationSheetResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$targetLabel için işlem',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Şikayetler 24 saat içinde incelenir. Engellediğin kullanıcının içerikleri akışından hemen kaldırılır.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedReason,
                decoration: const InputDecoration(labelText: 'Şikayet nedeni'),
                items: reasons
                    .map(
                      (reason) => DropdownMenuItem(
                        value: reason,
                        child: Text(reason),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setSheetState(() => selectedReason = value);
                  }
                },
              ),
              if (allowBlock) ...[
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: blockAuthor,
                  onChanged: (value) =>
                      setSheetState(() => blockAuthor = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Kullanıcıyı engelle'),
                  subtitle: const Text(
                    'Bu kullanıcının içerikleri senden gizlenir ve geliştiriciye bildirilir.',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pop(
                  ctx,
                  ModerationSheetResult(
                    reason: selectedReason,
                    blockAuthor: blockAuthor,
                  ),
                ),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Şikayet Et'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgeç'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
