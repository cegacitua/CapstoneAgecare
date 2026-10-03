import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/upload_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../patients/application/patients_providers.dart';
import '../application/documents_providers.dart';
import '../data/documents_repository.dart';
import '../domain/models.dart';

/// Expediente del paciente: documentos agrupados por categoría, con subida,
/// apertura y eliminación.
class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key, this.patientId});

  final String? patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveId =
        patientId ?? ref.watch(selectedPatientProvider)?.patientId;
    final docs = ref.watch(documentsProvider(patientId));

    return Scaffold(
      appBar: AppBar(title: const Text('Expediente')),
      floatingActionButton: effectiveId == null
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _upload(context, ref, effectiveId),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Subir'),
            ),
      body: effectiveId == null
          ? const EmptyView(
              icon: Icons.person_search_rounded,
              title: 'Selecciona un paciente',
              subtitle: 'Elige a quién quieres ver el expediente.',
            )
          : docs.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(documentsProvider(patientId)),
              ),
              data: (list) => list.isEmpty
                  ? EmptyView(
                      icon: Icons.folder_open_rounded,
                      title: 'Expediente vacío',
                      subtitle:
                          'Sube recetas, estudios o identificaciones para tenerlos a la mano.',
                      action: FilledButton.icon(
                        onPressed: () => _upload(context, ref, effectiveId),
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Subir documento'),
                      ),
                    )
                  : _DocumentsList(patientId: patientId, documents: list),
            ),
    );
  }

  Future<void> _upload(
      BuildContext context, WidgetRef ref, String patientId) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _UploadSheet(patientId: patientId, keyArg: this.patientId),
    );
  }
}

class _DocumentsList extends StatelessWidget {
  const _DocumentsList({required this.patientId, required this.documents});

  final String? patientId;
  final List<PatientDocument> documents;

  @override
  Widget build(BuildContext context) {
    final byCategory = <String, List<PatientDocument>>{};
    for (final d in documents) {
      byCategory.putIfAbsent(d.category, () => []).add(d);
    }
    final categories = byCategory.keys.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        for (final cat in categories) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Row(
              children: [
                Icon(_categoryIcon(cat), size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(_categoryLabel(cat),
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          for (final d in byCategory[cat]!)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DocumentTile(patientId: patientId, document: d),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _DocumentTile extends ConsumerStatefulWidget {
  const _DocumentTile({required this.patientId, required this.document});

  final String? patientId;
  final PatientDocument document;

  @override
  ConsumerState<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends ConsumerState<_DocumentTile> {
  bool _busy = false;

  Future<void> _open() async {
    setState(() => _busy = true);
    try {
      final url = await ref
          .read(documentsRepositoryProvider)
          .downloadUrl(widget.document.id);
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        showAppSnackBar(context, 'No se pudo abrir el documento.',
            error: true);
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar documento'),
        content: Text('¿Eliminar "${widget.document.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.critical),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(documentsRepositoryProvider)
          .deleteDocument(widget.document.id);
      ref.invalidate(documentsProvider(widget.patientId));
      if (mounted) showAppSnackBar(context, 'Documento eliminado.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.document;
    return AppCard(
      onTap: _busy ? null : _open,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_fileIcon(d.fileUrl), color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('d MMM yyyy', 'es').format(d.createdAt)}'
                  '${d.uploaderName != null ? ' · ${d.uploaderName}' : ''}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.textSecondary),
            onPressed: _busy ? null : _delete,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hoja de subida
// ---------------------------------------------------------------------------
class _UploadSheet extends ConsumerStatefulWidget {
  const _UploadSheet({required this.patientId, this.keyArg});
  final String patientId;

  /// El argumento original pasado a la pantalla (puede ser null) para
  /// invalidar el provider correcto.
  final String? keyArg;

  @override
  ConsumerState<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends ConsumerState<_UploadSheet> {
  final _picker = ImagePicker();
  final _titleCtrl = TextEditingController();
  String _category = 'receta';
  File? _file;
  bool _busy = false;

  static const _categories = {
    'receta': 'Receta',
    'estudio': 'Estudio de laboratorio',
    'identificacion': 'Identificación',
    'general': 'Otro',
  };

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
          source: source, imageQuality: 90, maxWidth: 2400);
      if (picked == null) return;
      setState(() => _file = File(picked.path));
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'No se pudo obtener el archivo.',
            error: true);
      }
    }
  }

  Future<void> _save() async {
    if (_file == null) {
      showAppSnackBar(context, 'Selecciona un archivo primero.', error: true);
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      showAppSnackBar(context, 'Escribe un título.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final uploaded = await ref
          .read(uploadServiceProvider)
          .uploadFile(_file!, kind: 'document');
      await ref.read(documentsRepositoryProvider).addDocument(
            widget.patientId,
            fileUrl: uploaded.fileUrl,
            title: _titleCtrl.text.trim(),
            category: _category,
          );
      ref.invalidate(documentsProvider(widget.keyArg));
      if (mounted) {
        Navigator.of(context).pop();
        showAppSnackBar(context, 'Documento subido al expediente.');
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Subir documento',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (_file != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_file!, height: 140, fit: BoxFit.cover),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _busy ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('Cámara'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _busy ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Galería'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: [
              for (final e in _categories.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _category = v ?? 'general'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
IconData _categoryIcon(String category) {
  switch (category) {
    case 'receta':
      return Icons.receipt_long_rounded;
    case 'estudio':
      return Icons.science_rounded;
    case 'identificacion':
      return Icons.badge_rounded;
    default:
      return Icons.description_rounded;
  }
}

String _categoryLabel(String category) {
  switch (category) {
    case 'receta':
      return 'Recetas';
    case 'estudio':
      return 'Estudios';
    case 'identificacion':
      return 'Identificaciones';
    default:
      return 'Otros';
  }
}

IconData _fileIcon(String url) {
  final lower = url.toLowerCase();
  if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
  if (lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png')) {
    return Icons.image_rounded;
  }
  return Icons.insert_drive_file_rounded;
}
