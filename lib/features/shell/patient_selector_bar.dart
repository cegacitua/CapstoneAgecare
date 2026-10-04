import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../patients/application/patients_providers.dart';
import '../patients/domain/models.dart';

/// Barra superior persistente de [MainShell] (AGE-206 / DAC05-55).
///
/// Vive por encima de las 5 pestañas de navegación, así que el contexto de
/// paciente activo se mantiene al cambiar de pestaña. Cuando el usuario
/// tiene 2 o más pacientes vinculados, al tocarla despliega la lista
/// completa y permite cambiar el paciente activo en 1 toque; con 0 o 1
/// paciente solo muestra el contexto, sin acción.
///
/// Al elegir otro paciente se actualiza [selectedPatientProvider]. No hace
/// falta refrescar nada a mano: cada pantalla (Salud, Medicamentos, Hoy,
/// etc.) observa ese provider —directa o indirectamente— y Riverpod
/// reconstruye sus datos solo para el nuevo paciente.
class PatientSelectorBar extends ConsumerWidget {
  const PatientSelectorBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(myPatientsProvider);
    final selected = ref.watch(selectedPatientProvider);

    return Material(
      color: AppColors.surface,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: patientsAsync.when(
          loading: () => const _BarLabel('Cargando…'),
          error: (_, __) => const _BarLabel('AgeCare'),
          data: (patients) {
            if (patients.isEmpty) return const _BarLabel('AgeCare');

            final current = selected ?? patients.first;
            final canSwitch = patients.length >= 2;

            return InkWell(
              key: const Key('patientSelectorBar_tap'),
              onTap: canSwitch
                  ? () => _openSelector(context, ref, patients, current)
                  : null,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(current.wellbeingStatus.icon,
                        size: 20, color: current.wellbeingStatus.color),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        current.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (canSwitch) ...[
                      const SizedBox(width: 2),
                      const Icon(Icons.expand_more_rounded,
                          size: 20, color: AppColors.textSecondary),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openSelector(
    BuildContext context,
    WidgetRef ref,
    List<PatientCard> patients,
    PatientCard current,
  ) async {
    final chosen = await showModalBottomSheet<PatientCard>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Cambiar de paciente',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            for (final p in patients)
              ListTile(
                key: Key('patientSelectorBar_option_${p.patientId}'),
                leading: Icon(p.wellbeingStatus.icon,
                    color: p.wellbeingStatus.color),
                title: Text(p.fullName),
                subtitle: p.activeAlertsCount > 0
                    ? Text('${p.activeAlertsCount} alerta(s) activa(s)')
                    : null,
                trailing: p.patientId == current.patientId
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                selected: p.patientId == current.patientId,
                onTap: () => Navigator.of(sheetContext).pop(p),
              ),
          ],
        ),
      ),
    );

    if (chosen != null && chosen.patientId != current.patientId) {
      ref.read(selectedPatientProvider.notifier).select(chosen);
    }
  }
}

class _BarLabel extends StatelessWidget {
  const _BarLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
      );
}
