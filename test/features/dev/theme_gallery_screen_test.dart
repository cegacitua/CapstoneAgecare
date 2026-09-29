// Prueba de la pantalla galería del design system (AGE-105, criterio
// "tema y componentes documentados"). Monta la pantalla real (no una
// captura) y comprueba que las 5 secciones aparecen sin lanzar errores.
import 'package:agecare_app/core/theme/app_theme.dart';
import 'package:agecare_app/features/dev/presentation/theme_gallery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpGallery(WidgetTester tester) async {
    // La pantalla es un ListView largo: Flutter solo construye lo que cabe
    // en el viewport. Se agranda la "pantalla" de prueba para que las 5
    // secciones existan sin tener que simular scroll.
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const ThemeGalleryScreen(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra las 5 secciones del design system', (tester) async {
    await pumpGallery(tester);

    for (final titulo in [
      'Colores',
      'Tipografía',
      'Botones y campos',
      'Semáforo de bienestar',
      'Widgets compartidos',
    ]) {
      expect(find.text(titulo), findsOneWidget, reason: 'falta la sección "$titulo"');
    }
  });

  testWidgets('los 12 colores de AppColors aparecen con su nombre', (tester) async {
    await pumpGallery(tester);

    for (final nombre in [
      'primary',
      'primaryDark',
      'secondary',
      'background',
      'surface',
      'textPrimary',
      'textSecondary',
      'divider',
      'statusOk',
      'statusWarning',
      'statusAttention',
      'critical',
    ]) {
      expect(find.text(nombre), findsOneWidget, reason: 'falta el color "$nombre"');
    }
  });

  testWidgets('muestra los 3 estados del semáforo de bienestar', (tester) async {
    await pumpGallery(tester);

    for (final status in WellbeingStatus.values) {
      expect(find.text(status.label), findsOneWidget,
          reason: 'falta el estado "${status.label}"');
    }
  });

  testWidgets('renderiza los widgets compartidos reales (no texto suelto)',
      (tester) async {
    await pumpGallery(tester);

    expect(find.text('Contenido dentro de un AppCard'), findsOneWidget);
    expect(find.text('ER'), findsOneWidget); // iniciales de "Elena Ramírez"
    expect(find.text('Sin elementos'), findsOneWidget); // EmptyView
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
