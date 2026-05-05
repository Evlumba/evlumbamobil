import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';

class ModerationValidation {
  final bool isAllowed;
  final String? message;

  const ModerationValidation._(this.isAllowed, this.message);

  const ModerationValidation.allowed() : this._(true, null);

  const ModerationValidation.blocked(String message) : this._(false, message);
}

class ModerationService {
  static const termsVersion = '2026-05-05';

  static const _blockedTerms = <String>[
    'amk',
    'orospu',
    'siktir',
    'sikerim',
    'piç',
    'pic',
    'ibne',
    'göt',
    'got',
    'fuck',
    'bitch',
    'cunt',
    'nigger',
    'kill yourself',
    'öl kendini',
  ];

  static ModerationValidation validateText(String text) {
    final normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    for (final term in _blockedTerms) {
      if (normalized.contains(term)) {
        return const ModerationValidation.blocked(
          'İçerik topluluk kurallarımıza uygun değil. Lütfen sakıncalı ifade, taciz veya nefret söylemi içermeyen bir metin yazın.',
        );
      }
    }
    return const ModerationValidation.allowed();
  }

  static Future<void> acceptTerms({required String surface}) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('user_terms_acceptances').upsert(
        {
          'user_id': user.id,
          'surface': surface,
          'terms_version': termsVersion,
          'accepted_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,terms_version,surface',
      );
    } catch (e) {
      debugPrint('Terms acceptance could not be stored: $e');
    }
  }

  static Future<Set<String>> loadBlockedUserIds() async {
    final user = supabase.auth.currentUser;
    if (user == null) return <String>{};

    try {
      final data = await supabase
          .from('blocked_users')
          .select('blocked_user_id')
          .eq('blocker_id', user.id);
      return (data as List)
          .map((row) => row['blocked_user_id'] as String?)
          .whereType<String>()
          .toSet();
    } catch (e) {
      debugPrint('Blocked users could not be loaded: $e');
      return <String>{};
    }
  }

  static Future<void> reportContent({
    required String contentType,
    required String contentId,
    required String contentOwnerId,
    required String reason,
    String? contentPreview,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw const AuthException('Oturum gerekli.');

    await supabase.from('content_reports').insert({
      'reporter_id': user.id,
      'content_type': contentType,
      'content_id': contentId,
      'content_owner_id': contentOwnerId,
      'reason': reason,
      'content_preview': _preview(contentPreview),
      'status': 'open',
    });
  }

  static Future<void> blockUser({
    required String blockedUserId,
    required String reason,
    String? sourceType,
    String? sourceId,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw const AuthException('Oturum gerekli.');
    if (blockedUserId == user.id) return;

    await supabase.from('blocked_users').upsert(
      {
        'blocker_id': user.id,
        'blocked_user_id': blockedUserId,
        'reason': reason,
        'source_type': sourceType,
        'source_id': sourceId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'blocker_id,blocked_user_id',
    );
  }

  static String? _preview(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.length <= 500) return trimmed;
    return trimmed.substring(0, 500);
  }
}
