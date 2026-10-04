import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:agecare_app/features/alerts/presentation/sos_button.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../auth/application/auth_controller.dart';
import '../../patients/application/patients_providers.dart';
import '../application/home_providers.dart';
import '../domain/models.dart';

/// Inicio del familiar: saludo, semáforo del día, accesos rápidos, estado
/// del wearable, vitals y adherencia. El selector multi-paciente vive en la
/// barra superior de [MainShell] (AGE-206).
class FamilyHomeScreen extends ConsumerWidget {
  const FamilyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final patientsAsync = ref.watch(myPatientsProvider);
    final selected = ref.watch(selectedPatientProvider);

    return Scaffold(
      floatingActionButton: selected != null ? const SosButton() : null,
      body: SafeArea(
        child: patientsAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(myPatientsProvider),
          ),
          data: (patients) {
            if (patients.isEmpty) {
              return EmptyView(
                icon: Icons.people_alt_outlined,
                title: 'Aún no tienes pacientes',
                subtitle:
                    'Crea el perfil de tu familiar para empezar a cuidar de su bienestar.',
                action: FilledButton.icon(
                  onPressed: () => context.push('/patients/create'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Crear paciente'),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myPatientsProvider);
                ref.invalidate(todaySummaryProvider);
                ref.invalidate(selectedPatientDetailProvider);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  _Greeting(name: user?.fullName),
                  const SizedBox(height: 16),
                  const _TodayCard(),
                  const SizedBox(height: 16),
                  const _QuickActions(),
                  const SizedBox(height: 16),
                  const _WearableCard(),
                  const SizedBox(height: 16),
                  const _VitalsAndAdherenceCard(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final salute = hour < 12
        ? 'Buenos días'
        : hour < 20
            ? 'Buenas tardes'
            : 'Buenas noches';
    final firstName = (name ?? '').trim().split(RegExp(r'\s+')).first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          firstName.isEmpty ? salute : '$salute, $firstName',
          style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          _spanishDate(DateTime.now()),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  /// Fecha en español sin depender de datos de locale de intl
  /// (no se inicializa initializeDateFormatting en el arranque).
  static String _spanishDate(DateTime d) {
    const days = [
      'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'
    ];
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
      'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final day = days[d.weekday - 1];
    final month = months[d.month - 1];
    final capitalized = day[0].toUpperCase() + day.substring(1);
    return '$capitalized ${d.day} de $month';
  }
}

class _TodayCard extends ConsumerWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(todaySummaryProvider);
    return summaryAsync.when(
      loading: () => const AppCard(
        child: SizedBox(height: 120, child: LoadingView()),
      ),
      error: (e, _) => AppCard(
        child: ErrorView(
          message: 'No se pudo cargar el resumen del día.',
          onRetry: () => ref.invalidate(todaySummaryProvider),
        ),
      ),
      data: (summary) {
        if (summary == null) return const SizedBox.shrink();
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Resumen de hoy',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  WellbeingChip(status: summary.wellbeingStatus, large: true),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                summary.topReason ?? summary.summary,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textPrimary, height: 1.35),
              ),
              if (summary.topReason != null && summary.summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(summary.summary,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
              if (summary.highlights.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: summary.highlights
                      .map((h) => _HighlightPill(highlight: h))
                      .toList(),
                ),
              ],
              if (summary.hasAlerts) ...[
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push('/alerts'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.statusAttention.withOpacity(.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active_rounded,
                            size: 20, color: AppColors.statusAttention),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${summary.activeAlertsCount} ${summary.activeAlertsCount == 1 ? 'alerta activa' : 'alertas activas'}',
                            style: const TextStyle(
                                color: AppColors.statusAttention,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.statusAttention),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HighlightPill extends StatelessWidget {
  const _HighlightPill({required this.highlight});

  final SummaryHighlight highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(highlight.icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(highlight.label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              Text(highlight.value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPatientProvider);
    final id = selected?.patientId;
    final actions = <_QuickAction>[
      _QuickAction(
        icon: Icons.notifications_active_outlined,
        label: 'Alertas',
        onTap: () => context.push('/alerts'),
      ),
      _QuickAction(
        icon: Icons.medication_outlined,
        label: 'Medicación',
        onTap: () => context.push('/meds/plan?patient=$id'),
      ),
      _QuickAction(
        icon: Icons.description_outlined,
        label: 'Documentos',
        onTap: () => context.push('/documents?patient=$id'),
      ),
      _QuickAction(
        icon: Icons.person_add_alt_1_outlined,
        label: 'Invitar',
        onTap: () => context.push('/invite'),
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          Expanded(child: actions[i]),
          if (i != actions.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _WearableCard extends ConsumerWidget {
  const _WearableCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPatientProvider);
    final detail = ref.watch(selectedPatientDetailProvider);
    if (selected == null) return const SizedBox.shrink();

    return detail.maybeWhen(
      data: (patient) {
        final wearable = patient?.wearable;
        if (wearable != null && wearable.isLinked) {
          final color =
              wearable.isStale ? AppColors.statusWarning : AppColors.statusOk;
          final syncText = wearable.lastSyncAt == null
              ? 'sin datos recientes'
              : 'hace ${_ago(DateTime.now().difference(wearable.lastSyncAt!.toLocal()))}';
          return AppCard(
            child: Row(
              children: [
                Icon(Icons.watch_rounded, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Wearable',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        wearable.isStale
                            ? 'Sin datos recientes (última sync $syncText)'
                            : 'Sincronizado $syncText',
                        style: TextStyle(color: color, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (wearable.batteryPct != null) ...[
                  Icon(
                    wearable.batteryPct! > 20
                        ? Icons.battery_std_rounded
                        : Icons.battery_alert_rounded,
                    size: 18,
                    color: wearable.batteryPct! > 20
                        ? AppColors.textSecondary
                        : AppColors.critical,
                  ),
                  const SizedBox(width: 2),
                  Text('${wearable.batteryPct}%',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ],
            ),
          );
        }
        // No vinculado.
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.watch_off_outlined,
                      color: AppColors.textSecondary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Sin wearable vinculado',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Vincula un wearable para seguir el ritmo cardíaco, la actividad y el sueño.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () =>
                    context.push('/wearable/link/${selected.patientId}'),
                icon: const Icon(Icons.add_link_rounded),
                label: const Text('Vincular wearable'),
              ),
            ],
          ),
        );
      },
      orElse: () => const AppCard(
        child: SizedBox(height: 60, child: LoadingView()),
      ),
    );
  }

  static String _ago(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    if (d.inHours < 24) return '${d.inHours} h';
    return '${d.inDays} días';
  }
}

class _VitalsAndAdherenceCard extends ConsumerWidget {
  const _VitalsAndAdherenceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(todaySummaryProvider);
    return summaryAsync.maybeWhen(
      data: (summary) {
        if (summary == null) return const SizedBox.shrink();
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Últimos vitales',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.push('/health'),
                    child: const Text('Ver salud'),
                  ),
                ],
              ),
              if (summary.latestVitals.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Aún no hay lecturas recientes.',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              else
                ...summary.latestVitals.map((v) => _VitalRow(vital: v)),
              if (summary.adherencePct != null) ...[
                const Divider(height: 24),
                _AdherenceBar(pct: summary.adherencePct!),
              ],
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _VitalRow extends StatelessWidget {
  const _VitalRow({required this.vital});

  final VitalReading vital;

  @override
  Widget build(BuildContext context) {
    final color =
        vital.inRange ? AppColors.textPrimary : AppColors.statusAttention;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(vital.icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(vital.label,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Text(vital.display,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          if (!vital.inRange) ...[
            const SizedBox(width: 6),
            const Icon(Icons.error_rounded,
                size: 18, color: AppColors.statusAttention),
          ],
        ],
      ),
    );
  }
}

class _AdherenceBar extends StatelessWidget {
  const _AdherenceBar({required this.pct});

  final int pct;

  @override
  Widget build(BuildContext context) {
    final value = (pct.clamp(0, 100)) / 100;
    final color = pct >= 80
        ? AppColors.statusOk
        : pct >= 50
            ? AppColors.statusWarning
            : AppColors.statusAttention;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.medication_rounded,
                size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Adherencia del día',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            Text('$pct%',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
