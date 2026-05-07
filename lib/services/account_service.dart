import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';

class AccountDeletionException implements Exception {
  final String message;

  const AccountDeletionException(this.message);

  @override
  String toString() => message;
}

class AccountService {
  static Future<void> deleteCurrentAccount() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      throw const AccountDeletionException('Oturum bulunamadı.');
    }

    try {
      final response = await supabase.functions.invoke(
        'delete-account',
        body: {'confirm': true},
      );

      final data = response.data;
      if (data is Map && data['ok'] == true) return;

      throw const AccountDeletionException(
        'Hesap silme işlemi tamamlanamadı.',
      );
    } on FunctionException catch (e) {
      throw AccountDeletionException(_messageFromFunctionException(e));
    } on AuthException catch (e) {
      throw AccountDeletionException(e.message);
    } catch (e) {
      if (e is AccountDeletionException) rethrow;
      throw AccountDeletionException('Hesap silinemedi: $e');
    }
  }

  static String _messageFromFunctionException(FunctionException e) {
    final details = e.details;
    if (details is Map) {
      final message = details['message'] ?? details['error'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    if (details is String && details.trim().isNotEmpty) {
      return details;
    }
    return 'Hesap silinemedi. (${e.status})';
  }
}
