import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../patients/application/patients_providers.dart';
import '../application/caregiver_providers.dart';
import '../data/caregiver_repository.dart';
import '../domain/models.dart';

/// Lista de tareas del paciente agrupadas por estado.
class CaregiverTasksScreen extends ConsumerWidget {
  const CaregiverTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(selectedPatientProvider);
    final tasksAsync = ref.watch(patientTasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tareas')),
      floatingActionButton: patient == null
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: () =>
                  context.push('/cg/task?patient=${patient.patientId}'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva tarea'),
            ),
      body: patient == null
          ? const EmptyView(
              icon: Icons.person_off_rounded,
              title: 'Sin paciente seleccionado',
              subtitle: 'Selecciona un paciente para ver sus tareas.',
            )
          : tasksAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(patientTasksProvider),
              ),
              data: (tasks) {
                if (tasks.isEmpty) {
                  return const EmptyView(
                    icon: Icons.checklist_rounded,
                    title: 'Sin tareas',
                    subtitle: 'Crea la primera tarea del plan de cuidado.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(patientTasksProvider),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    children: [
                      for (final status in TaskStatus.values)
                        ..._section(
                          context,
                          status,
                          tasks.where((t) => t.status == status).toList(),
                          patient.patientId,
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  List<Widget> _section(BuildContext context, TaskStatus status,
      List<CareTask> tasks, String patientId) {
    if (tasks.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: status.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text('${status.label} (${tasks.length})',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      for (final task in tasks)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TaskCard(task: task, patientId: patientId),
        ),
    ];
  }
}

class _TaskCard extends ConsumerStatefulWidget {
  const _TaskCard({required this.task, required this.patientId});

  final CareTask task;
  final String patientId;

  @override
  ConsumerState<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<_TaskCard> {
  bool _busy = false;

  Future<void> _setStatus(TaskStatus status) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(caregiverRepositoryProvider)
          .setTaskStatus(widget.task.id, status);
      ref.invalidate(patientTasksProvider);
      ref.invalidate(caregiverTodayProvider);
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    return AppCard(
      onTap: () => context
          .push('/cg/task?patient=${widget.patientId}&task=${task.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(task.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(task.timeLabel,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          if (task.description != null && task.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(task.description!,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (task.category != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(task.category!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.primary)),
                ),
              const Spacer(),
              if (_busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                _StatusMenu(current: task.status, onSelected: _setStatus),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusMenu extends StatelessWidget {
  const _StatusMenu({required this.current, required this.onSelected});

  final TaskStatus current;
  final ValueChanged<TaskStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TaskStatus>(
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final s in TaskStatus.values)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                Icon(Icons.circle, size: 12, color: s.color),
                const SizedBox(width: 8),
                Text(s.label),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: current.color.withOpacity(.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(current.label,
                style: TextStyle(
                    color: current.color, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, color: current.color),
          ],
        ),
      ),
    );
  }
}
