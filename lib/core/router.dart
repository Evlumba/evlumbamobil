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

      // Always allow splash screen
      if (location == '/splash') return null;

      // Allow auth pages without auth
      final isAuthPage =
          location.startsWith('/login') || location.startsWith('/register');
      if (!isLoggedIn && !isAuthPage) {
        return '/login';
      }
      // Redirect bare root to home
      if (location == '/') return '/home';
      if (isLoggedIn && isAuthPage) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      // Designer profile – accessible without shell
      GoRoute(
        path: '/designers/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final designerId = state.pathParameters['id']!;
          return DesignerProfileScreen(designerId: designerId);
        },
      ),
      GoRoute(
        path: '/projects/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final projectId = state.pathParameters['id']!;
          return ProjectDetailScreen(projectId: projectId);
        },
      ),
      GoRoute(
        path: '/chat/:conversationId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          final otherName =
              state.uri.queryParameters['name'] ?? 'Mesaj';
          return ChatScreen(
            conversationId: conversationId,
            otherPartyName: otherName,
          );
        },
      ),
      // Designer panel routes
      GoRoute(
        path: '/panel',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PanelScreen(),
      ),
      GoRoute(
        path: '/panel/edit-profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/panel/projects',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PanelProjectsScreen(),
      ),
      GoRoute(
        path: '/panel/projects/new',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProjectFormScreen(),
      ),
      GoRoute(
        path: '/panel/projects/:id/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final projectId = state.pathParameters['id']!;
          return ProjectFormScreen(projectId: projectId);
        },
      ),
      // Main shell with bottom nav
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          // 0 - Home
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // 1 - Explore
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                builder: (context, state) => const ExploreScreen(),
              ),
            ],
          ),
          // 2 - Designers
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/designers-list',
                builder: (context, state) => const DesignersScreen(),
              ),
            ],
          ),
          // 3 - Messages
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages',
                builder: (context, state) => const ConversationsScreen(),
              ),
            ],
          ),
          // 4 - Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
