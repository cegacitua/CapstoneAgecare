import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../patients/application/patients_providers.dart';
import '../application/medications_providers.dart';
import '../data/medications_repository.dart';
import '../domain/models.dart';

/// Pestaña principal de Medicamentos: adherencia, plan y dosis de hoy
/// (tickets AGE-401/402/403/404).
class MedicationsScreen extends ConsumerWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(selectedPatientProvider);
    final meds = ref.watch(medicationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicamentos'),
        actions: [
          IconButton(
            tooltip: 'Escanear receta',
            icon: const Icon(Icons.document_scanner_rounded),
            onPressed: patient == null
                ? null
                : () => context.push('/meds/scan?patient=${patient.patientId}'),
          ),
        ],
      ),
      floatingActionButton: patient == null
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: () =>
                  context.push('/meds/plan?patient=${patient.patientId}'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar'),
            ),
      body: patient == null
          ? const EmptyView(
              icon: Icons.person_search_rounded,
              title: 'Selecciona un paciente',
              subtitle: 'Elige a quién quieres ver los medicamentos.')
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(medicationsProvider);
                ref.invalidate(todayDosesProvider);
                ref.invalidate(adherenceProvider);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  const _AdherenceSection(),
                  const SizedBox(height: 20),
                  const _TodayDosesSection(),
                  const SizedBox(height: 20),
                  Text('Plan de medicación',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  meds.when(
                    loading: () => const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: LoadingView()),
                    error: (e, _) => ErrorView(
                        message: e.toString(),
                        onRetry: () => ref.invalidate(medicationsProvider)),
                    data: (list) => list.isEmpty
                        ? EmptyView(
                            icon: Icons.medication_rounded,
                            title: 'Sin medicamentos',
                            subtitle:
                                'Agrega uno o escanea una receta para empezar.',
                            action: FilledButton.icon(
                              onPressed: () => context.push(
                                  '/meds/plan?patient=${patient.patientId}'),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Agregar medicamento'),
                            ),
                          )
                        : Column(
                            children: [
                              for (final m in list)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _MedicationCard(
                                    medication: m,
                                    patientId: patient.patientId,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Adherencia
// ---------------------------------------------------------------------------
class _AdherenceSection extends ConsumerWidget {
  const _AdherenceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adherence = ref.watch(adherenceProvider);
    return adherence.when(
      loading: () => const AppCard(
          child: SizedBox(height: 160, child: LoadingView())),
      error: (e, _) => AppCard(
        child: ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(adherenceProvider)),
      ),
      data: (data) {
        if (data == null || data.byDay.isEmpty) {
          return const AppCard(
            child: EmptyView(
                icon: Icons.insights_rounded,
                title: 'Sin datos de adherencia'),
          );
        }
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Adherencia (7 días)',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Text('${data.pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _pctColor(data.pct))),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(height: 140, child: _AdherenceChart(points: data.byDay)),
              if (data.byMedication.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 4),
                for (final m in data.byMedication)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(m.medicationName)),
                        Text('${m.pct.toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _pctColor(m.pct))),
                      ],
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

class _AdherenceChart extends StatelessWidget {
  const _AdherenceChart({required this.points});

  final List<AdherencePoint> points;

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: 100,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (v) =>
              const FlLine(color: AppColors.divider, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(
                showTitles: true, reservedSize: 32, interval: 25),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(DateFormat('E', 'es').format(points[i].date),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: points[i].pct,
                width: 14,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
                color: _pctColor(points[i].pct),
              ),
            ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dosis de hoy
// ---------------------------------------------------------------------------
class _TodayDosesSection extends ConsumerWidget {
  const _TodayDosesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doses = ref.watch(todayDosesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dosis de hoy', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        doses.when(
          loading: () => const Padding(
              padding: EdgeInsets.only(top: 16), child: LoadingView()),
          error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(todayDosesProvider)),
          data: (list) => list.isEmpty
              ? const AppCard(
                  child: EmptyView(
                      icon: Icons.event_available_rounded,
                      title: 'No hay dosis programadas hoy'))
              : Column(
                  children: [
                    for (final d in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DoseTile(dose: d),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _DoseTile extends ConsumerStatefulWidget {
  const _DoseTile({required this.dose});
  final Dose dose;

  @override
  ConsumerState<_DoseTile> createState() => _DoseTileState();
}

class _DoseTileState extends ConsumerState<_DoseTile> {
  bool _busy = false;

  Future<void> _log(DoseStatus status) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(medicationsRepositoryProvider)
          .logDose(widget.dose.id, status);
      ref.invalidate(todayDosesProvider);
      ref.invalidate(adherenceProvider);
      if (mounted) {
        showAppSnackBar(context,
            status == DoseStatus.taken ? 'Toma registrada' : 'Dosis omitida');
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dose;
    final done = d.status != DoseStatus.pending;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.medication_rounded,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.medicationName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(
                      '${d.timeLabel}${d.dose != null ? ' · ${d.dose} ${d.unit ?? ''}'.trimRight() : ''}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: d.status),
            ],
          ),
          if (!done) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _log(DoseStatus.taken),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Tomada'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _log(DoseStatus.skipped),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Omitir'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final DoseStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(status.label,
          style: TextStyle(
              color: status.color,
              fontWeight: FontWeight.w700,
              fontSize: 12)),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de medicamento
// ---------------------------------------------------------------------------
class _MedicationCard extends ConsumerWidget {
  const _MedicationCard({required this.medication, required this.patientId});

  final Medication medication;
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: () => context.push(
          '/meds/plan?patient=$patientId&medication=${medication.id}'),
      child: Row(
        children: [
          const Icon(Icons.medication_liquid_rounded,
              color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(medication.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(medication.doseLabel,
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(medication.scheduleLabel,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

Color _pctColor(double pct) {
  if (pct >= 80) return AppColors.statusOk;
  if (pct >= 50) return AppColors.statusWarning;
  return AppColors.statusAttention;
}
