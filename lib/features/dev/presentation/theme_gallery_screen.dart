import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';

/// Catálogo visual del design system de AgeCare: colores, tipografía,
/// botones/campos y los widgets compartidos de core/widgets/common.dart.
///
/// No es una pantalla de negocio: solo se navega a ella desde ProfileScreen,
/// y ese acceso solo existe en modo debug (ver kDebugMode en ese archivo).
/// Todo lo que se ve aquí usa las mismas fuentes que el resto de la app
/// (AppColors, Theme.of(context), los widgets reales) — nada está
/// hardcodeado ni es una captura de pantalla.
class ThemeGalleryScreen extends StatelessWidget {
  const ThemeGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design system')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionTitle('Colores'),
          _ColorSwatches(),
          SizedBox(height: 32),
          _SectionTitle('Tipografía'),
          _TypographySamples(),
          SizedBox(height: 32),
          _SectionTitle('Botones y campos'),
          _ButtonsAndFields(),
          SizedBox(height: 32),
          _SectionTitle('Semáforo de bienestar'),
          _WellbeingChips(),
          SizedBox(height: 32),
          _SectionTitle('Widgets compartidos'),
          _SharedWidgetsShowcase(),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      );
}

class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches();

  static const _colors = <(String, Color)>[
    ('primary', AppColors.primary),
    ('primaryDark', AppColors.primaryDark),
    ('secondary', AppColors.secondary),
    ('background', AppColors.background),
    ('surface', AppColors.surface),
    ('textPrimary', AppColors.textPrimary),
    ('textSecondary', AppColors.textSecondary),
    ('divider', AppColors.divider),
    ('statusOk', AppColors.statusOk),
    ('statusWarning', AppColors.statusWarning),
    ('statusAttention', AppColors.statusAttention),
    ('critical', AppColors.critical),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final (name, color) in _colors)
          SizedBox(
            width: 100,
            child: Column(
              children: [
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.divider),
                  ),
                ),
                const SizedBox(height: 6),
                Text(name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12)),
                Text(
                  '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TypographySamples extends StatelessWidget {
  const _TypographySamples();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final samples = <(String, TextStyle?)>[
      ('headlineLarge', t.headlineLarge),
      ('titleLarge', t.titleLarge),
      ('titleMedium', t.titleMedium),
      ('bodyLarge', t.bodyLarge),
      ('bodyMedium', t.bodyMedium),
      ('labelLarge', t.labelLarge),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, style) in samples)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('$name — AgeCare', style: style),
          ),
      ],
    );
  }
}

class _ButtonsAndFields extends StatelessWidget {
  const _ButtonsAndFields();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton(onPressed: () {}, child: const Text('Botón primario')),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () {}, child: const Text('Botón secundario')),
        const SizedBox(height: 12),
        TextButton(onPressed: () {}, child: const Text('Botón de texto')),
        const SizedBox(height: 16),
        const TextField(decoration: InputDecoration(labelText: 'Campo de texto')),
      ],
    );
  }
}

class _WellbeingChips extends StatelessWidget {
  const _WellbeingChips();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final status in WellbeingStatus.values)
          WellbeingChip(status: status),
      ],
    );
  }
}

class _SharedWidgetsShowcase extends StatelessWidget {
  const _SharedWidgetsShowcase();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AppCard', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const AppCard(child: Text('Contenido dentro de un AppCard')),
        const SizedBox(height: 20),
        const Text('InitialsAvatar', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Row(children: [
          InitialsAvatar(name: 'Elena Ramírez'),
          SizedBox(width: 12),
          InitialsAvatar(name: 'María', radius: 28),
        ]),
        const SizedBox(height: 20),
        const Text('EmptyView', style: TextStyle(fontWeight: FontWeight.w600)),
        const EmptyView(
          icon: Icons.inbox_outlined,
          title: 'Sin elementos',
          subtitle: 'Ejemplo de estado vacío',
        ),
      ],
    );
  }
}
