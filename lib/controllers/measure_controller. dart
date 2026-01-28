import '../models/measure_model.dart';
import '../models/quarter_model.dart';

class MeasureController {
  final MeasureModel measure;

  int currentQuarterIndex = 0;
  double? quarterStartTime;
  final List<double> currentHits = [];

  MeasureController({required this.measure});

  /// Inizia la battuta
  void startMeasure(double startTime) {
    currentQuarterIndex = 0;
    _startQuarter(startTime);
  }

  /// Riceve un colpo dall'input
  void onHit(double timestamp) {
    currentHits.add(timestamp);
  }

  /// Passa al prossimo quarter
  void nextQuarter(double endTime) {
    // Qui normalmente invieresti currentHits a un evaluator
    currentHits.clear();

    currentQuarterIndex++;
    if (currentQuarterIndex < measure.quarters.length) {
      _startQuarter(endTime);
    } else {
      // Battuta finita
      quarterStartTime = null;
    }
  }

  QuarterModel? get currentQuarter {
    if (currentQuarterIndex < measure.quarters.length) {
      return measure.quarters[currentQuarterIndex];
    }
    return null;
  }

  bool get isMeasureFinished => currentQuarterIndex >= measure.quarters.length;

  void _startQuarter(double startTime) {
    quarterStartTime = startTime;
    currentHits.clear();
    // Eventuali callback per UI qui
  }
}
