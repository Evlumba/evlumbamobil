import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../services/search_filters.dart';
import '../widgets/filter_exit_dialog.dart';

const _kPrimary = Color(0xFF0E5A3A);

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final Uri uri;

  const MainShell({
    super.key,
    required this.navigationShell,
    required this.uri,
  });

  // Maps shell branch index (0–3) → visual nav index (0,1,3,4)
  int get _visualIndex {
    final b = navigationShell.currentIndex;
    return b < 2 ? b : b + 1;
  }

  bool get _hasRouteFilters {
    return SearchFilters.fromQuery(uri.queryParameters).hasAny;
  }

  Future<bool> _confirmFilterExit(BuildContext context) async {
    return showFilterExitDialog(context);
  }

  void _onTap(BuildContext context, int visualIndex) async {
    if (visualIndex == 2) {
      // Centre + button — designer goes to new project, others go to ilanlar
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (context.mounted) context.push('/ilanlar');
        return;
      }
      final data = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      final role = data?['role'] as String?;
      final isDesigner = role == 'designer' ||
          role == 'designer_pending' ||
          role == 'admin' ||
          role == 'super_admin';
      if (context.mounted) {
        if (isDesigner) {
          context.push('/panel/projects/new');
        } else {
          context.push('/ilanlar');
        }
      }
      return;
    }
    final branchIndex = visualIndex < 2 ? visualIndex : visualIndex - 1;
    if (branchIndex != navigationShell.currentIndex && _hasRouteFilters) {
      final confirmed = await _confirmFilterExit(context);
      if (!confirmed || !context.mounted) return;
      if (branchIndex == 0) {
        context.go('/home');
        return;
      }
    }
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnHome = navigationShell.currentIndex == 0;
    return PopScope(
      canPop: isOnHome,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          if (_hasRouteFilters) {
            final confirmed = await _confirmFilterExit(context);
            if (!confirmed || !context.mounted) return;
            context.go('/home');
            return;
          }
          navigationShell.goBranch(0, initialLocation: false);
        }
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: _BottomBar(
          currentVisualIndex: _visualIndex,
          onTap: (i) => _onTap(context, i),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int currentVisualIndex;
  final void Function(int) onTap;

  const _BottomBar({required this.currentVisualIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, -4)),
        ],
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Ana Sayfa',
              isActive: currentVisualIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.explore_outlined,
              activeIcon: Icons.explore_rounded,
              label: 'Keşfet',
              isActive: currentVisualIndex == 1,
              onTap: () => onTap(1),
            ),
            // Centre + button
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(2),
                child: Center(
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: _kPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Color(0x330E5A3A),
                            blurRadius: 10,
                            offset: Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
            _NavItem(
              icon: Icons.chat_bubble_outline_rounded,
              activeIcon: Icons.chat_bubble_rounded,
              label: 'Mesajlar',
              isActive: currentVisualIndex == 3,
              onTap: () => onTap(3),
              badge: const _UnreadMessageBadge(),
            ),
            _NavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profil',
              isActive: currentVisualIndex == 4,
              onTap: () => onTap(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Widget? badge;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _kPrimary : AppColors.textSecondary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(isActive ? activeIcon : icon, color: color, size: 24),
                if (badge != null)
                  Positioned(
                    top: -8,
                    right: -10,
                    child: badge!,
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnreadMessageBadge extends StatefulWidget {
  const _UnreadMessageBadge();

  @override
  State<_UnreadMessageBadge> createState() => _UnreadMessageBadgeState();
}

class _UnreadMessageBadgeState extends State<_UnreadMessageBadge>
    with WidgetsBindingObserver {
  final _supabase = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _messageSubscription;
  Timer? _refreshDebounce;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = _supabase.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.tokenRefreshed ||
          event.event == AuthChangeEvent.userUpdated) {
        _startMessageListener();
        unawaited(_refreshUnreadCount());
      } else if (event.event == AuthChangeEvent.signedOut) {
        _messageSubscription?.cancel();
        _messageSubscription = null;
        if (mounted) setState(() => _count = 0);
      }
    });
    _startMessageListener();
    unawaited(_refreshUnreadCount());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshDebounce?.cancel();
    _authSubscription?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshUnreadCount());
    }
  }

  void _startMessageListener() {
    if (_messageSubscription != null) return;
    if (_supabase.auth.currentUser == null) return;

    _messageSubscription = _supabase
        .from('messages')
        .stream(primaryKey: ['id']).listen((_) => _scheduleRefresh());
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_refreshUnreadCount()),
    );
  }

  Future<void> _refreshUnreadCount() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      if (mounted && _count != 0) setState(() => _count = 0);
      return;
    }

    try {
      final homeownerConvs = await _supabase
          .from('conversations')
          .select('id')
          .eq('homeowner_id', currentUser.id);
      final designerConvs = await _supabase
          .from('conversations')
          .select('id')
          .eq('designer_id', currentUser.id);

      final conversationIds = <String>{
        for (final item in homeownerConvs as List)
          if (item is Map && item['id'] is String) item['id'] as String,
        for (final item in designerConvs as List)
          if (item is Map && item['id'] is String) item['id'] as String,
      }.toList();

      if (conversationIds.isEmpty) {
        if (mounted && _count != 0) setState(() => _count = 0);
        return;
      }

      final unreadData = await _supabase
          .from('messages')
          .select('id')
          .inFilter('conversation_id', conversationIds)
          .neq('sender_id', currentUser.id)
          .isFilter('read_at', null);
      final nextCount = (unreadData as List).length;

      if (mounted && nextCount != _count) {
        setState(() => _count = nextCount);
      }
    } catch (_) {
      // Badge uygulamanın ana navigasyonunu bozmasın; bir sonraki realtime
      // event veya app resume ile tekrar denenecek.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_count <= 0) return const SizedBox.shrink();

    final label = _count > 99 ? '99+' : '$_count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE04848),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
