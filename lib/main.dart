import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme.dart';
import 'core/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

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

  @override
  void initState() {
    super.initState();
    _handleIncomingLinks();
  }

  void _handleIncomingLinks() {
    // Uygulama kapalıyken gelen link (cold start)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _navigateToLink(uri);
    });

    // Uygulama açıkken gelen link (warm start)
    _appLinks.uriLinkStream.listen((uri) {
      _navigateToLink(uri);
    });
  }

  void _navigateToLink(Uri uri) {
    // Sadece evlumba.com linklerini handle et
    if (uri.host != 'www.evlumba.com' && uri.host != 'evlumba.com') return;

    final path = uri.path; // örn: /projects/abc-123
    if (path.isEmpty) return;

    // Router hazır olana kadar kısa bekle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _router.go(path);
    });
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
