import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../auth/domain/models.dart';
import '../application/patients_providers.dart';
import '../data/patients_repository.dart';
import '../domain/models.dart';

/// Invitar a un miembro del círculo de cuidado (ticket AGE-205).
class InviteMemberScreen extends ConsumerStatefulWidget {
  const InviteMemberScreen({super.key});

  @override
  ConsumerState<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends ConsumerState<InviteMemberScreen> {
  final _email = TextEditingController();
  RoleType _role = RoleType.caregiver;
  Invitation? _created;
  bool _loading = false;

  Future<void> _submit() async {
    final patient = ref.read(selectedPatientProvider);
    if (patient == null) return;
    setState(() => _loading = true);
    try {
      final invitation = await ref.read(patientsRepositoryProvider).invite(
            patientId: patient.patientId,
            role: _role,
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          );
      setState(() => _created = invitation);
    } on ApiException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = ref.watch(selectedPatientProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Invitar al círculo de cuidado')),
      body: patient == null
          ? const EmptyView(
              icon: Icons.group_outlined,
              title: 'Primero crea un paciente',
              subtitle: 'Las invitaciones se envían por paciente.')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Invitar a alguien al cuidado de ${patient.fullName}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  const Text('¿Qué rol tendrá?',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SegmentedButton<RoleType>(
                    segments: const [
                      ButtonSegment(
                          value: RoleType.caregiver,
                          label: Text('Cuidadora'),
                          icon: Icon(Icons.health_and_safety_outlined)),
                      ButtonSegment(
                          value: RoleType.family,
                          label: Text('Familiar'),
                          icon: Icon(Icons.family_restroom_outlined)),
                      ButtonSegment(
                          value: RoleType.doctor,
                          label: Text('Médico'),
                          icon: Icon(Icons.medical_services_outlined)),
                      ButtonSegment(
                          value: RoleType.elder,
                          label: Text('Adulto mayor'),
                          icon: Icon(Icons.elderly_outlined)),
                    ],
                    selected: {_role},
                    onSelectionChanged: (s) => setState(() => _role = s.first),
                    multiSelectionEnabled: false,
                    showSelectedIcon: false,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo (opcional)',
                      prefixIcon: Icon(Icons.mail_outline),
                      helperText: 'Para identificar a quién invitaste. El código '
                          'se comparte aparte, por el medio que prefieras.',
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: const Text('Generar código'),
                  ),
                  if (_created != null) ...[
                    const SizedBox(height: 24),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: AppColors.statusOk),
                              const SizedBox(width: 8),
                              Text(
                                'Código para ${_created!.role.label.toLowerCase()}',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              _created!.code,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 8,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Center(
                            child: Text(
                              'Vence en 48 horas · compártelo solo con esa persona',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: _created!.code));
                              if (context.mounted) {
                                showAppSnackBar(context, 'Código copiado');
                              }
                            },
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('Copiar código'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
