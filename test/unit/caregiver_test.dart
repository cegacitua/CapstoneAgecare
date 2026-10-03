import 'package:flutter_test/flutter_test.dart';
import 'package:agecare_app/features/caregiver/data/caregiver_repository.dart';
import 'package:agecare_app/features/caregiver/domain/models.dart';

void main() {
  group('CaregiverRepository Unit Tests', () {
    late CaregiverRepositoryMock caregiverRepo;

    setUp(() {
      caregiverRepo = CaregiverRepositoryMock();
    });

    test('getToday returns caregiver shift summary and patient details', () async {
      final todayData = await caregiverRepo.getToday();

      expect(todayData, isNotNull);
      expect(todayData.patientName, isNotEmpty);
    });

    test('listTasks returns daily tasks for patient', () async {
      final tasks = await caregiverRepo.listTasks('p-elena');

      expect(tasks, isNotEmpty);
      expect(tasks.first.title, isNotEmpty);
    });

    test('checkin updates shift status to checkedIn', () async {
      final shift = await caregiverRepo.checkin('p-elena', type: 'in');

      expect(shift, equals(ShiftStatus.checkedIn));
    });

    test('createObservation adds a new observation note', () async {
      final obs = await caregiverRepo.createObservation(
        'p-elena',
        text: 'Paciente almorzó adecuadamente y tomó sus medicamentos.',
        category: 'rutina',
      );

      expect(obs.id, isNotEmpty);
      expect(obs.text, contains('almorzó'));
    });

    test('createHandoverNote registers shift change note', () async {
      final note = await caregiverRepo.createHandoverNote(
        'p-elena',
        text: 'Queda pendiente verificar presión arterial a las 20:00.',
      );

      expect(note.id, isNotEmpty);
      expect(note.text, contains('presión arterial'));
    });
  });
}
