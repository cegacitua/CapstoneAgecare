import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/application/auth_controller.dart';
import '../auth/domain/models.dart';
import '../caregiver/presentation/caregiver_log_screen.dart';
import '../caregiver/presentation/caregiver_tasks_screen.dart';
import '../caregiver/presentation/caregiver_today_screen.dart';
import '../comms/presentation/comms_screen.dart';
import '../elder/presentation/elder_home_screen.dart';
import '../health/presentation/health_screen.dart';
import '../home/presentation/family_home_screen.dart';
import '../medications/presentation/medications_screen.dart';
import 'more_screen.dart';
import 'patient_selector_bar.dart';

/// Contenedor principal con navegación inferior según el rol del usuario.
/// - familiar/médico: Inicio · Salud · Medicamentos · Comunicación · Más
/// - cuidadora:       Hoy · Tareas · Bitácora · Comunicación · Más
/// - adulto mayor:    experiencia de mosaico a pantalla completa
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final role = user?.primaryRole ?? RoleType.family;

    if (role == RoleType.elder) {
      return const ElderHomeScreen();
    }

    final tabs = role == RoleType.caregiver ? _caregiverTabs : _familyTabs;
    final safeIndex = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PatientSelectorBar(),
            Expanded(
              child: IndexedStack(
                index: safeIndex,
                children: [for (final t in tabs) t.screen],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }

  static const _familyTabs = <_Tab>[
    _Tab('Inicio', Icons.home_outlined, Icons.home_rounded, FamilyHomeScreen()),
    _Tab('Salud', Icons.favorite_outline, Icons.favorite_rounded, HealthScreen()),
    _Tab('Medicinas', Icons.medication_outlined, Icons.medication_rounded, MedicationsScreen()),
    _Tab('Chat', Icons.forum_outlined, Icons.forum_rounded, CommsScreen()),
    _Tab('Más', Icons.menu_rounded, Icons.menu_rounded, MoreScreen()),
  ];

  static const _caregiverTabs = <_Tab>[
    _Tab('Hoy', Icons.today_outlined, Icons.today_rounded, CaregiverTodayScreen()),
    _Tab('Tareas', Icons.checklist_outlined, Icons.checklist_rounded, CaregiverTasksScreen()),
    _Tab('Bitácora', Icons.edit_note_outlined, Icons.edit_note_rounded, CaregiverLogScreen()),
    _Tab('Chat', Icons.forum_outlined, Icons.forum_rounded, CommsScreen()),
    _Tab('Más', Icons.menu_rounded, Icons.menu_rounded, MoreScreen()),
  ];
}

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon, this.screen);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;
}
