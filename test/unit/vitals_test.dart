import 'package:flutter_test/flutter_test.dart';
import 'package:agecare_app/features/health/data/vitals_repository.dart';
import 'package:agecare_app/features/health/domain/models.dart';

void main() {
  group('VitalsRepository Unit Tests', () {
    late VitalsRepositoryMock vitalsRepo;

    setUp(() {
      vitalsRepo = VitalsRepositoryMock();
    });

    test('getLatest returns latest vitals summary list for patient', () async {
      final latestList = await vitalsRepo.getLatest('p-elena');

      expect(latestList, isNotEmpty);
      expect(latestList.any((v) => v.type == VitalType.heartRate), isTrue);
      expect(latestList.any((v) => v.type == VitalType.spo2), isTrue);
    });

    test('getSeries returns time series data points for vital type', () async {
      final series = await vitalsRepo.getSeries(
        'p-elena',
        VitalType.heartRate,
        from: DateTime.now().subtract(const Duration(days: 7)),
        to: DateTime.now(),
      );

      expect(series.points, isNotEmpty);
      expect(series.type, equals(VitalType.heartRate));
      expect(series.points.first.value, greaterThan(0));
    });

    test('getThresholds returns custom alert thresholds', () async {
      final thresholds = await vitalsRepo.getThresholds('p-elena');

      expect(thresholds, isNotEmpty);
      final hrThreshold = thresholds.firstWhere((t) => t.type == VitalType.heartRate);
      expect(hrThreshold.minValue, isNotNull);
      expect(hrThreshold.maxValue, greaterThan(hrThreshold.minValue!));
    });
  });
}
