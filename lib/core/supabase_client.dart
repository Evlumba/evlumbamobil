import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns the initialized Supabase client.
/// Call [SupabaseClient.initialize] in main.dart before using this.
SupabaseClient get supabase => Supabase.instance.client;
