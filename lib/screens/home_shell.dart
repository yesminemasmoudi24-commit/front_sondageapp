import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../theme/kpit_theme.dart';
import 'dashboard_screen.dart';
import 'delegations/delegations_screen.dart';
import 'employees/employees_screen.dart';
import 'notifications/notifications_screen.dart';
import 'profile_screen.dart';
import 'surveys/surveys_list_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final unread = context.watch<NotificationProvider>().unreadCount;
    final badge = context.watch<NotificationProvider>().badgeLabel;
    final canManage = user.canManageSurveys;
    final isAdmin = user.isAdmin;

    final destinations = <_NavItem>[
      if (canManage)
        const _NavItem(
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          builder: DashboardScreen.new,
        ),
      const _NavItem(
        label: 'Sondages',
        icon: Icons.poll_outlined,
        selectedIcon: Icons.poll,
        builder: SurveysListScreen.new,
      ),
      if (isAdmin)
        const _NavItem(
          label: 'Employés',
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          builder: EmployeesScreen.new,
        ),
      if (isAdmin)
        const _NavItem(
          label: 'Délégations',
          icon: Icons.handshake_outlined,
          selectedIcon: Icons.handshake,
          builder: DelegationsScreen.new,
        ),
      _NavItem(
        label: 'Notifs',
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications,
        builder: NotificationsScreen.new,
        badgeCount: unread,
        badgeLabel: badge,
      ),
      const _NavItem(
        label: 'Profil',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        builder: ProfileScreen.new,
      ),
    ];

    if (_index >= destinations.length) {
      _index = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (final d in destinations) d.builder(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          // Quand on ouvre Notifs, on resync le compteur.
          if (destinations[i].label == 'Notifs') {
            context.read<NotificationProvider>().refresh();
          }
        },
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: _NavIcon(
                icon: d.icon,
                badgeLabel: d.badgeLabel,
                showBadge: d.badgeCount > 0,
              ),
              selectedIcon: _NavIcon(
                icon: d.selectedIcon,
                badgeLabel: d.badgeLabel,
                showBadge: d.badgeCount > 0,
              ),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.badgeLabel,
    required this.showBadge,
  });

  final IconData icon;
  final String badgeLabel;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: showBadge,
      backgroundColor: KpitTheme.lime,
      textColor: KpitTheme.black,
      label: Text(
        badgeLabel,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
      ),
      child: Icon(icon),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
    this.badgeCount = 0,
    this.badgeLabel = '',
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() builder;
  final int badgeCount;
  final String badgeLabel;
}
