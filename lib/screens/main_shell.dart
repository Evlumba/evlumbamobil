import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';

const _kPrimary = Color(0xFF0E5A3A);

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  // Maps shell branch index (0–3) → visual nav index (0,1,3,4)
  int get _visualIndex {
    final b = navigationShell.currentIndex;
    return b < 2 ? b : b + 1;
  }

  void _onTap(BuildContext context, int visualIndex) {
    if (visualIndex == 2) {
      // Centre + button
      context.push('/panel');
      return;
    }
    final branchIndex = visualIndex < 2 ? visualIndex : visualIndex - 1;
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _BottomBar(
        currentVisualIndex: _visualIndex,
        onTap: (i) => _onTap(context, i),
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
          BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, -4)),
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
                        BoxShadow(color: Color(0x330E5A3A), blurRadius: 10, offset: Offset(0, 4)),
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

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
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
            Icon(isActive ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}
