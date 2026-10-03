import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/upload_service.dart';
import '../../../core/speech/speech_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../application/elder_providers.dart';
import '../data/elder_repository.dart';
import '../domain/models.dart';

/// Galería de fotos de la familia para el adulto mayor: imágenes grandes,
/// captions legibles, lectura por voz y reacciones con botones enormes.
class ElderPhotosScreen extends ConsumerWidget {
  const ElderPhotosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientId = ref.watch(elderPatientIdProvider);
    final photosAsync = ref.watch(photosProvider);
    final speech = ref.read(speechServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis fotos',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        toolbarHeight: 72,
      ),
      floatingActionButton: patientId == null
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _addPhoto(context, ref, patientId),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_a_photo_rounded, size: 30),
              label: const Text('Agregar foto',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ),
      body: patientId == null
          ? const EmptyView(
              icon: Icons.photo_library_rounded,
              title: 'Aún no hay fotos',
              subtitle: 'Cuando tu familia comparta fotos, aparecerán aquí.',
            )
          : photosAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: e is Exception ? e.toString() : 'No se pudieron cargar las fotos.',
                onRetry: () => ref.invalidate(photosProvider),
              ),
              data: (photos) {
                if (photos.isEmpty) {
                  return const EmptyView(
                    icon: Icons.photo_library_rounded,
                    title: 'Aún no hay fotos',
                    subtitle:
                        'Cuando tu familia comparta fotos, aparecerán aquí.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: photos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 24),
                  itemBuilder: (context, i) => _PhotoCard(
                    photo: photos[i],
                    speech: speech,
                    onReact: (reaction) =>
                        _react(context, ref, photos[i].id, reaction),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _react(
      BuildContext context, WidgetRef ref, String photoId, String reaction) async {
    try {
      await ref.read(elderRepositoryProvider).reactPhoto(photoId, reaction);
      ref.invalidate(photosProvider);
      if (context.mounted) {
        showAppSnackBar(context, 'Gracias por tu reacción');
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, 'No se pudo enviar la reacción', error: true);
      }
    }
  }

  Future<void> _addPhoto(
      BuildContext context, WidgetRef ref, String patientId) async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2000);
      if (picked == null) return;
      if (!context.mounted) return;

      final caption = await _askCaption(context);
      if (!context.mounted) return;

      showAppSnackBar(context, 'Subiendo la foto...');
      final uploaded = await ref
          .read(uploadServiceProvider)
          .uploadFile(File(picked.path), kind: 'photo');
      await ref.read(elderRepositoryProvider).addPhoto(
            patientId,
            fileUrl: uploaded.fileUrl,
            caption: caption,
          );
      ref.invalidate(photosProvider);
      if (context.mounted) showAppSnackBar(context, 'Foto agregada');
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, 'No se pudo agregar la foto', error: true);
      }
    }
  }

  Future<String?> _askCaption(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Qué muestra la foto?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 20),
          decoration: const InputDecoration(
            hintText: 'Ej. Mis nietos en la playa',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Omitir', style: TextStyle(fontSize: 18)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.photo,
    required this.speech,
    required this.onReact,
  });

  final FamilyPhoto photo;
  final SpeechService speech;
  final ValueChanged<String> onReact;

  @override
  Widget build(BuildContext context) {
    final caption = photo.caption;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                photo.url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.primary.withOpacity(.06),
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_rounded,
                      size: 56, color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (caption != null && caption.isNotEmpty) ...[
                  Text(
                    caption,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'De ${photo.fromName}',
                  style: const TextStyle(
                      fontSize: 18, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _ReactionButton(
                      icon: Icons.favorite_rounded,
                      color: AppColors.critical,
                      count: photo.reactionCount('love'),
                      onTap: () => onReact('love'),
                    ),
                    const SizedBox(width: 12),
                    _ReactionButton(
                      icon: Icons.sentiment_very_satisfied_rounded,
                      color: AppColors.statusWarning,
                      count: photo.reactionCount('smile'),
                      onTap: () => onReact('smile'),
                    ),
                    const Spacer(),
                    if (caption != null && caption.isNotEmpty)
                      _ReactionButton(
                        icon: Icons.volume_up_rounded,
                        color: AppColors.primary,
                        label: 'Escuchar',
                        onTap: () => speech.speak(caption),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.count,
    this.label,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? count;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 34, color: color),
                if (count != null && count! > 0) ...[
                  const SizedBox(width: 8),
                  Text('$count',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: color)),
                ],
                if (label != null) ...[
                  const SizedBox(width: 8),
                  Text(label!,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
