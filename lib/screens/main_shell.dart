import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'mastery_tab.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: const [
        HomeScreen(),
        MasteryTab(),
      ]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(children: [
              _NavItem(
                icon: Icons.chat_bubble_rounded,
                label: 'Sorular\u0131m',
                active: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
              _NavItem(
                icon: Icons.auto_awesome_rounded,
                label: 'Ustala\u015f',
                active: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Active indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: active ? 24 : 0,
            height: 3,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              gradient: active ? const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]) : null,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          // Icon
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: active
                ? const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)])
                : null,
            ),
            child: Icon(icon, size: 20,
              color: active ? Colors.white : const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
          )),
        ]),
      ),
    );
  }
}
