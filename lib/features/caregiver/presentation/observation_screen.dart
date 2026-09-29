import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/upload_service.dart';
import '../../../core/widgets/common.dart';
import '../application/caregiver_providers.dart';
import '../data/caregiver_repository.dart';

/// Formulario para registrar una observación (con foto opcional).
class ObservationScreen extends ConsumerStatefulWidget {
  const ObservationScreen({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<ObservationScreen> createState() => _ObservationScreenState();
}

class _ObservationScreenState extends ConsumerState<ObservationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _text = TextEditingController();
  final _picker = ImagePicker();

  final _categories = const [
    'Alimentación',
    'Ánimo',
    'Sueño',
    'Movilidad',
    'Higiene',
    'General',
  ];
  String? _category;
  File? _image;
  bool _saving = false;

  Future<void> _pick(ImageSource source) async {
    try {
      final picked =
          await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 2000);
      if (picked == null) return;
      setState(() => _image = File(picked.path));
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'No se pudo obtener la imagen.', error: true);
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      String? mediaUrl;
      if (_image != null) {
        final uploaded = await ref
            .read(uploadServiceProvider)
            .uploadFile(_image!, kind: 'photo');
        mediaUrl = uploaded.fileUrl;
      }
      await ref.read(caregiverRepositoryProvider).createObservation(
            widget.patientId,
            text: _text.text.trim(),
            mediaUrl: mediaUrl,
            category: _category,
          );
      ref.invalidate(observationsProvider);
      ref.invalidate(caregiverTodayProvider);
      if (mounted) {
        showAppSnackBar(context, 'Observación registrada.');
        context.pop();
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva observación')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [
                for (final c in _categories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _text,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '¿Qué observaste?',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe una observación' : null,
            ),
            const SizedBox(height: 16),
            if (_image != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_image!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                        onPressed: () => setState(() => _image = null),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: const Text('Cámara'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _saving ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Galería'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              label: const Text('Guardar observación'),
            ),
          ],
        ),
      ),
    );
  }
}
