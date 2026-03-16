import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const _gistUrl =
    'https://gist.githubusercontent.com/Evlumba/476b663eb77f8c7ad9178357827f4beb/raw/fe3ae7c5a91bff85cec8acb97a84beb2b1a27f26/gistfile1.txt';

const _currentVersion = '1.0.0';

/// Compares two semantic version strings. Returns negative if a < b, 0 if equal, positive if a > b.
int _compareVersions(String a, String b) {
  final aParts = a.split('.').map(int.parse).toList();
  final bParts = b.split('.').map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    final av = i < aParts.length ? aParts[i] : 0;
    final bv = i < bParts.length ? bParts[i] : 0;
    if (av != bv) return av - bv;
  }
  return 0;
}

Future<void> checkForUpdate(BuildContext context) async {
  try {
    final response = await http.get(Uri.parse(_gistUrl)).timeout(
      const Duration(seconds: 5),
    );
    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final latestVersion = data['latest_version'] as String? ?? _currentVersion;
    final minVersion = data['min_version'] as String? ?? _currentVersion;
    final storeUrl = data['store_url'] as String? ?? '';
    final updateMessage = data['update_message'] as String? ?? 'Update';

    if (!context.mounted) return;

    final isForced = _compareVersions(_currentVersion, minVersion) < 0;
    final hasUpdate = _compareVersions(_currentVersion, latestVersion) < 0;

    if (hasUpdate || isForced) {
      await showDialog(
        context: context,
        barrierDismissible: !isForced,
        builder: (_) => _UpdateDialog(
          isForced: isForced,
          updateMessage: updateMessage,
          storeUrl: storeUrl,
        ),
      );
    }
  } catch (_) {
    // Silently fail — don't block app launch on network errors
  }
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({
    required this.isForced,
    required this.updateMessage,
    required this.storeUrl,
  });

  final bool isForced;
  final String updateMessage;
  final String storeUrl;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Güncelleme Mevcut'),
      content: Text(
        isForced
            ? 'Bu sürüm artık desteklenmemektedir. Devam etmek için uygulamayı güncelleyin.'
            : 'Yeni bir sürüm mevcut. En iyi deneyim için güncelleyin.',
      ),
      actions: [
        if (!isForced)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Daha Sonra'),
          ),
        TextButton(
          onPressed: () async {
            if (storeUrl.isNotEmpty) {
              final uri = Uri.parse(storeUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
          child: Text(updateMessage),
        ),
      ],
    );
  }
}
