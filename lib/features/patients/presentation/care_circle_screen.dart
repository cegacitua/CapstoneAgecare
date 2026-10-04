import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../auth/domain/models.dart';
import '../application/patients_providers.dart';
import '../data/patients_repository.dart';
import '../domain/models.dart';

/// Pantalla de gestión de permisos y desvinculación de miembros del círculo de cuidado (ticket AGE-207).
class CareCircleScreen extends ConsumerStatefulWidget {
  const CareCircleScreen({super.key});

  @override
  ConsumerState<CareCircleScreen> createState() => _CareCircleScreenState();
}

class _CareCircleScreenState extends ConsumerState<CareCircleScreen> {
  List<CircleMember> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    final patient = ref.read(selectedPatientProvider);
    if (patient == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (!_loading && mounted) {
      setState(() => _loading = true);
    }

    try {
      final members = await ref
          .read(patientsRepositoryProvider)
          .listCircleMembers(patient.patientId);
      if (mounted) {
        setState(() {
          _members = members;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showAppSnackBar(context, e.message, error: true);
      }
    }
  }

  Future<void> _confirmAndRevokeMember(CircleMember member) async {
    final patient = ref.read(selectedPatientProvider);
    if (patient == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revocar Acceso'),
        content: Text(
          '¿Estás seguro de revocar el acceso a ${member.fullName} (${member.role.label}) del círculo de cuidado de ${patient.fullName}?\n\nEsta acción desvinculará la cuenta de inmediato.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.critical,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revocar Acceso'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(patientsRepositoryProvider)
            .revokeMember(patient.patientId, member.memberId);
        if (mounted) {
          showAppSnackBar(
            context,
            'Acceso revocado a ${member.fullName}. Cuenta desvinculada.',
          );
          _fetchMembers();
        }
      } on ApiException catch (e) {
        if (mounted) showAppSnackBar(context, e.message, error: true);
      }
    }
  }

  Future<void> _resendInvitation(CircleMember member) async {
    final patient = ref.read(selectedPatientProvider);
    if (patient == null) return;
    try {
      final inv = await ref
          .read(patientsRepositoryProvider)
          .resendInvitation(patient.patientId, member.memberId);
      await Clipboard.setData(ClipboardData(text: inv.code));
      if (mounted) {
        showAppSnackBar(
          context,
          'Invitación reenviada. Enlace copiado al portapapeles.',
        );
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = ref.watch(selectedPatientProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Círculo de Cuidado'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: _fetchMembers,
          ),
        ],
      ),
      body: patient == null
          ? const EmptyView(
              icon: Icons.group_outlined,
              title: 'Selecciona un paciente',
              subtitle: 'Debes seleccionar un paciente para gestionar su círculo.',
            )
          : RefreshIndicator(
              onRefresh: _fetchMembers,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.12),
                          child: const Icon(
                            Icons.elderly_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patient.fullName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Text(
                                'Gestión de integrantes y permisos',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 40),
                          ),
                          onPressed: () => context.push('/invite'),
                          icon: const Icon(Icons.person_add_rounded, size: 18),
                          label: const Text('Invitar'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_members.isEmpty)
                    const EmptyView(
                      icon: Icons.group_off_outlined,
                      title: 'Sin integrantes registrados',
                      subtitle: 'Usa el botón "Invitar" para agregar miembros.',
                    )
                  else ...[
                    const Text(
                      'Integrantes Activos e Invitaciones',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final m in _members) ...[
                      _buildMemberCard(m),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildMemberCard(CircleMember m) {
    return AppCard(
      key: ValueKey('member-${m.memberId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: m.isPending
                  ? AppColors.statusWarning.withOpacity(0.15)
                  : AppColors.primary.withOpacity(0.12),
              child: Icon(
                _getRoleIcon(m.role),
                color: m.isPending
                    ? AppColors.statusWarning
                    : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          m.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(m.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${m.role.label} • ${m.email}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (m.isPending) ...[
              IconButton(
                icon: const Icon(
                  Icons.send_rounded,
                  color: AppColors.primary,
                ),
                tooltip: 'Reenviar invitación',
                onPressed: () => _resendInvitation(m),
              ),
              IconButton(
                icon: const Icon(
                  Icons.cancel_outlined,
                  color: AppColors.critical,
                ),
                tooltip: 'Cancelar invitación',
                onPressed: () => _confirmAndRevokeMember(m),
              ),
            ] else ...[
              IconButton(
                icon: const Icon(
                  Icons.no_accounts_outlined,
                  color: AppColors.critical,
                ),
                tooltip: 'Revocar acceso',
                onPressed: () => _confirmAndRevokeMember(m),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getRoleIcon(RoleType role) {
    switch (role) {
      case RoleType.caregiver:
        return Icons.health_and_safety_rounded;
      case RoleType.doctor:
        return Icons.medical_services_rounded;
      case RoleType.elder:
        return Icons.elderly_rounded;
      case RoleType.family:
        return Icons.family_restroom_rounded;
    }
  }

  Widget _buildStatusBadge(InvitationState status) {
    Color bg;
    Color fg;
    switch (status) {
      case InvitationState.accepted:
        bg = AppColors.statusOk.withOpacity(0.12);
        fg = AppColors.statusOk;
        break;
      case InvitationState.pending:
        bg = AppColors.statusWarning.withOpacity(0.12);
        fg = AppColors.statusWarning;
        break;
      case InvitationState.expired:
        bg = AppColors.critical.withOpacity(0.12);
        fg = AppColors.critical;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
