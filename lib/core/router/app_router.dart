import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/alerts/presentation/alerts_screen.dart';
import '../../features/alerts/presentation/alert_detail_screen.dart';
import '../../features/caregiver/presentation/checkin_screen.dart';
import '../../features/caregiver/presentation/handover_screen.dart';
import '../../features/caregiver/presentation/incident_screen.dart';
import '../../features/caregiver/presentation/observation_screen.dart';
import '../../features/caregiver/presentation/reports_screen.dart';
import '../../features/caregiver/presentation/task_edit_screen.dart';
import '../../features/comms/presentation/assistant_screen.dart';
import '../../features/comms/presentation/chat_screen.dart';
import '../../features/documents/presentation/documents_screen.dart';
import '../../features/health/presentation/vital_detail_screen.dart';
import '../../features/marketplace/presentation/caregiver_profile_screen.dart';
import '../../features/marketplace/presentation/marketplace_screen.dart';
import '../../features/medications/presentation/dose_confirm_screen.dart';
import '../../features/medications/presentation/medication_plan_screen.dart';
import '../../features/medications/presentation/prescription_scan_screen.dart';
import '../../features/patients/presentation/accept_invitation_screen.dart';
import '../../features/patients/presentation/create_patient_screen.dart';
import '../../features/patients/presentation/invite_member_screen.dart';
import '../../features/patients/presentation/care_circle_screen.dart';
import '../../features/premium/presentation/premium_screen.dart';
import '../../features/profile/presentation/notification_settings_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/shell/splash_screen.dart';
import '../../features/wearable/presentation/wearable_link_screen.dart';
import '../../features/dev/presentation/theme_gallery_screen.dart';

/// Rutas públicas (accesibles sin sesión).
const _publicRoutes = {'/login', '/register', '/recover', '/splash'};

/// Router principal. Escucha el estado de autenticación para redirigir.
final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      if (auth is AuthLoading) return loc == '/splash' ? null : '/splash';

      final loggedIn = auth is Authenticated;
      final onPublic = _publicRoutes.contains(loc);

      if (!loggedIn) return onPublic && loc != '/splash' ? null : '/login';
      if (loggedIn && (onPublic)) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, st) => RegisterScreen(
            invitationToken: st.uri.queryParameters['invite'],
          )),
      GoRoute(path: '/recover', builder: (_, __) => const RecoverPasswordScreen()),

      // Shell principal por rol.
      GoRoute(path: '/home', builder: (_, __) => const MainShell()),

      // --- Salud ---
      GoRoute(
        path: '/health/vital/:type',
        builder: (_, st) =>
            VitalDetailScreen(typeApiValue: st.pathParameters['type']!),
      ),
      GoRoute(
        path: '/wearable/link/:patientId',
        builder: (_, st) =>
            WearableLinkScreen(patientId: st.pathParameters['patientId']!),
      ),

      // --- Pacientes ---
      GoRoute(path: '/patients/create', builder: (_, __) => const CreatePatientScreen()),
      GoRoute(path: '/patients/circle', builder: (_, __) => const CareCircleScreen()),
      // Invita al miembro sobre el paciente seleccionado (selectedPatientProvider).
      GoRoute(path: '/invite', builder: (_, __) => const InviteMemberScreen()),
      // Lado del invitado: ingresar el código de 6 dígitos (AGE-205 / DAC05-7).
      GoRoute(
          path: '/invite/accept',
          builder: (_, __) => const AcceptInvitationScreen()),

      // --- Medicamentos ---
      GoRoute(
        path: '/meds/plan',
        builder: (_, st) => MedicationPlanScreen(
          patientId: st.uri.queryParameters['patient']!,
          medicationId: st.uri.queryParameters['medication'],
        ),
      ),
      GoRoute(
        path: '/meds/scan',
        builder: (_, st) =>
            PrescriptionScanScreen(patientId: st.uri.queryParameters['patient']!),
      ),
      GoRoute(
        path: '/dose/:id',
        builder: (_, st) => DoseConfirmScreen(doseId: st.pathParameters['id']!),
      ),

      // --- Alertas ---
      GoRoute(path: '/alerts', builder: (_, __) => const AlertsScreen()),
      GoRoute(
        path: '/alerts/:id',
        builder: (_, st) => AlertDetailScreen(alertId: st.pathParameters['id']!),
      ),

      // --- Comunicación ---
      GoRoute(
        path: '/chat',
        builder: (_, st) => ChatScreen(patientId: st.uri.queryParameters['patient']),
      ),
      GoRoute(
        path: '/assistant',
        builder: (_, st) =>
            AssistantScreen(patientId: st.uri.queryParameters['patient']),
      ),

      // --- Cuidadora ---
      GoRoute(path: '/cg/checkin', builder: (_, st) => CheckinScreen(patientId: st.uri.queryParameters['patient']!)),
      GoRoute(path: '/cg/task', builder: (_, st) => TaskEditScreen(patientId: st.uri.queryParameters['patient']!, taskId: st.uri.queryParameters['task'])),
      GoRoute(path: '/cg/observation', builder: (_, st) => ObservationScreen(patientId: st.uri.queryParameters['patient']!)),
      GoRoute(path: '/cg/incident', builder: (_, st) => IncidentScreen(patientId: st.uri.queryParameters['patient']!)),
      GoRoute(path: '/cg/handover', builder: (_, st) => HandoverScreen(patientId: st.uri.queryParameters['patient']!)),
      GoRoute(path: '/cg/reports', builder: (_, __) => const CaregiverReportsScreen()),

      // --- Marketplace ---
      GoRoute(path: '/marketplace', builder: (_, __) => const MarketplaceScreen()),
      GoRoute(
        path: '/marketplace/caregivers/:id',
        builder: (_, st) =>
            CaregiverProfileScreen(profileId: st.pathParameters['id']!),
      ),

      // --- Documentos / perfil / premium ---
      GoRoute(
        path: '/documents',
        builder: (_, st) =>
            DocumentsScreen(patientId: st.uri.queryParameters['patient']),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/settings/notifications', builder: (_, __) => const NotificationSettingsScreen()),
      // Alias usado desde ProfileScreen.
      GoRoute(path: '/profile/notifications', builder: (_, __) => const NotificationSettingsScreen()),
      GoRoute(path: '/premium', builder: (_, __) => const PremiumScreen()),

      // --- Solo desarrollo: catálogo del design system (AGE-105) ---
      if (kDebugMode)
        GoRoute(
          path: '/dev/gallery',
          builder: (_, __) => const ThemeGalleryScreen(),
        ),
    ],
  );
});

/// Puente entre Riverpod (authControllerProvider) y el refreshListenable de
/// go_router: notifica al router cuando cambia el estado de autenticación.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    _sub = ref.listen<AuthState>(
      authControllerProvider,
      (_, __) => notifyListeners(),
      fireImmediately: false,
    );
  }
  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
