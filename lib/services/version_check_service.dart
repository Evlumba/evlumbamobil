import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const _gistUrl =
    'https://gist.githubusercontent.com/Evlumba/476b663eb77f8c7ad9178357827f4beb/raw/gistfile1.txt';

Future<void> checkForUpdate(BuildContext context) async {
  try {
    final response = await http.get(_versionConfigUri()).timeout(
          const Duration(seconds: 5),
        );
    if (response.statusCode != 200) return;

    final appInfo = await PackageInfo.fromPlatform();
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final config = _VersionConfig.fromJson(data, _platformKey);
    if (config == null) return;

    if (!context.mounted) return;

    final isForced = _compareVersions(appInfo.version, config.minVersion) < 0 ||
        _compareBuilds(appInfo.buildNumber, config.minBuild) < 0;
    final hasUpdate =
        _compareVersions(appInfo.version, config.latestVersion) < 0 ||
            _compareBuilds(appInfo.buildNumber, config.latestBuild) < 0;

    if (hasUpdate || isForced) {
      await showDialog(
        context: context,
        barrierDismissible: !isForced,
        builder: (_) => _UpdateDialog(
          isForced: isForced,
          updateMessage: config.updateMessage,
          storeUrl: config.storeUrl,
        ),
      );
    }
  } catch (_) {
    // App launch should never be blocked by a version-check network/config issue.
  }
}

Uri _versionConfigUri() {
  return Uri.parse(_gistUrl).replace(
    queryParameters: {
      'v': DateTime.now().millisecondsSinceEpoch.toString(),
    },
  );
}

String get _platformKey {
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => 'android',
  };
}

int _compareVersions(String a, String b) {
  final aParts = _versionParts(a);
  final bParts = _versionParts(b);
  final length = aParts.length > bParts.length ? aParts.length : bParts.length;

  for (var i = 0; i < length; i += 1) {
    final av = i < aParts.length ? aParts[i] : 0;
    final bv = i < bParts.length ? bParts[i] : 0;
    if (av != bv) return av - bv;
  }
  return 0;
}

List<int> _versionParts(String value) {
  return value
      .split(RegExp(r'[^0-9]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
}

int _compareBuilds(String currentBuild, int? targetBuild) {
  if (targetBuild == null) return 0;
  final current = int.tryParse(currentBuild) ?? 0;
  return current - targetBuild;
}

class _VersionConfig {
  const _VersionConfig({
    required this.latestVersion,
    required this.minVersion,
    required this.storeUrl,
    required this.updateMessage,
    this.latestBuild,
    this.minBuild,
  });

  final String latestVersion;
  final String minVersion;
  final int? latestBuild;
  final int? minBuild;
  final String storeUrl;
  final String updateMessage;

  static _VersionConfig? fromJson(Map<String, dynamic> data, String platform) {
    final platformData = data[platform];
    final source = platformData is Map<String, dynamic> ? platformData : data;
    final latestVersion = _readString(source, 'latest_version');
    final minVersion = _readString(source, 'min_version');

    if (latestVersion == null || minVersion == null) return null;

    return _VersionConfig(
      latestVersion: latestVersion,
      minVersion: minVersion,
      latestBuild: _readInt(source, 'latest_build'),
      minBuild: _readInt(source, 'min_build'),
      storeUrl: _readString(source, 'store_url') ?? '',
      updateMessage: _readString(source, 'update_message') ?? 'Güncelle',
    );
  }

  static String? _readString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static int? _readInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is int) return value;
    if (value is String) return int.tryParse(value.trim());
    return null;
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
          onPressed: storeUrl.isEmpty
              ? null
              : () async {
                  final uri = Uri.parse(storeUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
          child: Text(updateMessage),
        ),
      ],
    );
  }
}
