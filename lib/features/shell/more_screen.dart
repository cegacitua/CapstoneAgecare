import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/application/auth_controller.dart';
import '../auth/domain/models.dart';
import '../patients/application/patients_providers.dart';

/// Pestaña "Más": accesos a perfil, expediente, marketplace, premium y ajustes.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final role = user?.primaryRole ?? RoleType.family;
    final patient = ref.watch(selectedPatientProvider);
    final pq = patient != null ? '?patient=${patient.patientId}' : '';

    final items = <_MoreItem>[
      _MoreItem(Icons.person_outline, 'Mi perfil', () => context.push('/profile')),
      _MoreItem(Icons.folder_outlined, 'Expediente y documentos',
          () => context.push('/documents$pq')),
      _MoreItem(Icons.storefront_outlined, 'Marketplace de cuidado',
          () => context.push('/marketplace')),
      _MoreItem(Icons.groups_outlined, 'Círculo de Cuidado (Permisos)',
          () => context.push('/patients/circle')),
      if (role == RoleType.family)
        _MoreItem(Icons.group_add_outlined, 'Invitar al círculo de cuidado',
            () => context.push('/invite')),
      if (role != RoleType.family)
        _MoreItem(Icons.pin_outlined, 'Unirme con un código',
            () => context.push('/invite/accept')),
      if (role == RoleType.caregiver) ...[
        _MoreItem(Icons.workspace_premium_outlined, 'AgeCare Premium',
            () => context.push('/premium')),
        _MoreItem(Icons.insights_outlined, 'Mis reportes',
            () => context.push('/cg/reports')),
      ],
      _MoreItem(Icons.notifications_outlined, 'Notificaciones',
          () => context.push('/settings/notifications')),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: CircleAvatar(
              radius: 26,
              backgroundImage:
                  user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
              child: user?.avatarUrl == null
                  ? Text(_initials(user?.fullName ?? '?'))
                  : null,
            ),
            title: Text(user?.fullName ?? '',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(role.label),
          ),
          const Divider(),
          for (final it in items)
            ListTile(
              leading: Icon(it.icon),
              title: Text(it.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: it.onTap,
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Cerrar sesión',
                style: TextStyle(color: Colors.redAccent)),
            onTap: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

class _MoreItem {
  _MoreItem(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}
