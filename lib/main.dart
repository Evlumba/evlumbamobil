import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme.dart';
import 'core/router.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await PushNotificationService.configureBackgroundHandling();

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
      detectSessionInUri: false,
    ),
  );
  unawaited(PushNotificationService.instance.initialize());

  runApp(
    const ProviderScope(
      child: EvlumbaApp(),
    ),
  );
}

class EvlumbaApp extends StatefulWidget {
  const EvlumbaApp({super.key});

  @override
  State<EvlumbaApp> createState() => _EvlumbaAppState();
}

class _EvlumbaAppState extends State<EvlumbaApp> {
  late final GoRouter _router = buildRouter();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  bool _handlingAuthCallback = false;

  @override
  void initState() {
    super.initState();
    PushNotificationService.instance.attachRouter(_router);
    _handleIncomingLinks();
  }

  void _handleIncomingLinks() {
    // Uygulama kapalıyken gelen link (cold start)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) unawaited(_handleIncomingUri(uri));
    }).catchError((_) {});

    // Uygulama açıkken gelen link (warm start)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handleIncomingUri(uri)),
      onError: (_) {},
    );
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    if (_isSupabaseAuthCallback(uri)) {
      await _completeSupabaseAuth(uri);
      return;
    }

    // Sadece evlumba.com linklerini handle et
    if (uri.host != 'www.evlumba.com' && uri.host != 'evlumba.com') return;

    final path = uri.path; // örn: /projects/abc-123
    if (path.isEmpty) return;

    final target = uri.hasQuery ? '$path?${uri.query}' : path;
    _goTo(target);
  }

  bool _isSupabaseAuthCallback(Uri uri) {
    if (uri.scheme != 'io.supabase.evlumba') return false;
    return uri.host == 'login-callback' ||
        uri.pathSegments.contains('login-callback') ||
        uri.fragment.contains('access_token') ||
        uri.fragment.contains('error_description') ||
        uri.queryParameters.containsKey('code');
  }

  Future<void> _completeSupabaseAuth(Uri uri) async {
    if (_handlingAuthCallback) return;
    _handlingAuthCallback = true;

    var hasAuthError = uri.fragment.contains('error_description') ||
        uri.queryParameters.containsKey('error_description');

    try {
      if (!hasAuthError) {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      }
    } on AuthException {
      hasAuthError = true;
    } catch (_) {
      hasAuthError = true;
    } finally {
      _handlingAuthCallback = false;
    }

    if (!mounted) return;
    final hasSession = Supabase.instance.client.auth.currentSession != null;
    _goTo(!hasAuthError && hasSession ? '/home' : '/login');
  }

  void _goTo(String location) {
    // Router hazır olana kadar kısa bekle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _router.go(location);
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Evlumba',
      theme: buildAppTheme(),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
