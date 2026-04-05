import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme.dart';

class WebScreen extends StatefulWidget {
  final String url;
  final String title;
  final bool showBottomNav;

  const WebScreen({super.key, required this.url, required this.title, this.showBottomNav = true});

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  Session? get _session => Supabase.instance.client.auth.currentSession;

  /// Session varsa /api/auth/set-session üzerinden server-side cookie set
  /// ettirip hedef sayfaya redirect ettirir.
  String get _urlWithSession {
    final session = _session;
    if (session == null) return widget.url;
    final targetUri = Uri.parse(widget.url);
    final path = targetUri.path.isEmpty ? '/' : targetUri.path;
    return 'https://www.evlumba.com/api/auth/set-session'
        '?access_token=${Uri.encodeComponent(session.accessToken)}'
        '&refresh_token=${Uri.encodeComponent(session.refreshToken ?? '')}'
        '&redirect=${Uri.encodeComponent(path)}';
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(_urlWithSession));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      bottomNavigationBar: widget.showBottomNav ? Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: 0,
          onTap: (index) {
            switch (index) {
              case 0:
                context.go('/home');
              case 1:
                context.go('/explore');
              case 2:
                context.go('/designers-list');
              case 3:
                context.go('/forum');
              case 4:
                context.go('/ilanlar-tab');
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Ana Sayfa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Keşfet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Tasarımcılar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.forum_outlined),
              activeIcon: Icon(Icons.forum),
              label: 'Forum',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              activeIcon: Icon(Icons.list_alt),
              label: 'İlanlar',
            ),
          ],
        ),
      ) : null,
    );
  }
}
