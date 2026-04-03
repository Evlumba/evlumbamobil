import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/home/home_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/main_shell.dart';
import '../screens/explore/explore_screen.dart';
import '../screens/designers/designers_screen.dart';
import '../screens/designers/designer_profile_screen.dart';
import '../screens/designers/project_detail_screen.dart';
import '../screens/messages/conversations_screen.dart';
import '../screens/messages/chat_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/designer_panel/panel_screen.dart';
import '../screens/designer_panel/edit_profile_screen.dart';
import '../screens/designer_panel/projects_screen.dart';
import '../screens/designer_panel/project_form_screen.dart';
import '../screens/web/web_screen.dart';
import '../screens/profile/profile_settings_screen.dart';
import '../screens/profile/collections_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final location = state.uri.toString();

      // Public pages — no login required
      const publicPrefixes = [
        '/splash', '/login', '/register',
        '/home', '/explore', '/designers-list',
        '/forum', '/blog', '/ilanlar', '/forum-tab', '/sss',
      ];
      final isPublic = publicPrefixes.any((p) => location.startsWith(p));

      if (location == '/') return '/home';
      if (isLoggedIn && (location.startsWith('/login') || location.startsWith('/register'))) {
        return '/home';
      }
      if (!isLoggedIn && !isPublic) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      // Profile – accessible outside shell via top icon
      GoRoute(
        path: '/profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileScreen(),
      ),
      // Profile settings (native)
      GoRoute(
        path: '/profile-settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final tab = (state.extra as String?) ?? 'general';
          return ProfileSettingsScreen(tab: tab);
        },
      ),
      // Collections
      GoRoute(
        path: '/collections',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const CollectionsScreen(),
      ),
      // Admin panel
      GoRoute(
        path: '/admin',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const WebScreen(url: 'https://www.evlumba.com/admin', title: 'Admin Panel'),
      ),
      // SSS
      GoRoute(
        path: '/sss',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const WebScreen(url: 'https://www.evlumba.com/sss', title: 'Yardım'),
      ),
      // Web screens (Forum, Blog, İlanlar)
      GoRoute(
        path: '/forum',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const WebScreen(url: 'https://www.evlumba.com/forum', title: 'Forum'),
      ),
      GoRoute(
        path: '/blog',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const WebScreen(url: 'https://www.evlumba.com/blog', title: 'Blog'),
      ),
      GoRoute(
        path: '/ilanlar',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const WebScreen(url: 'https://www.evlumba.com/ilanlar', title: 'İlanlar'),
      ),
      // Designer profile & project detail
      GoRoute(
        path: '/designers/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => DesignerProfileScreen(designerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/projects/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ProjectDetailScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/messages',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const ConversationsScreen(),
      ),
      // Designers list – standalone (also available as shell branch)
      GoRoute(
        path: '/designers-list',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const DesignersScreen(),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ChatScreen(
          conversationId: state.pathParameters['conversationId']!,
          otherPartyName: state.uri.queryParameters['name'] ?? 'Mesaj',
          otherPartyAvatarUrl: state.uri.queryParameters['avatar'],
          otherPartySpecialty: state.uri.queryParameters['specialty'],
          otherPartyId: state.uri.queryParameters['userId'],
        ),
      ),
      // Designer panel
      GoRoute(path: '/panel', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const PanelScreen()),
      GoRoute(path: '/panel/edit-profile', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: '/panel/projects', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const PanelProjectsScreen()),
      GoRoute(path: '/panel/projects/new', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const ProjectFormScreen()),
      GoRoute(
        path: '/panel/projects/:id/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ProjectFormScreen(projectId: state.pathParameters['id']!),
      ),
      // Main shell with bottom nav (4 branches: Home, Explore, Messages, Profile)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          // 0 - Home
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKey,
            routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())],
          ),
          // 1 - Explore
          StatefulShellBranch(
            routes: [GoRoute(path: '/explore', builder: (_, __) => const ExploreScreen())],
          ),
          // 2 - Messages (visual index 3)
          StatefulShellBranch(
            routes: [GoRoute(path: '/messages-tab', builder: (_, __) => const ConversationsScreen())],
          ),
          // 3 - Profile (visual index 4)
          StatefulShellBranch(
            routes: [GoRoute(path: '/profile-tab', builder: (_, __) => const ProfileScreen())],
          ),
        ],
      ),
    ],
  );
}
