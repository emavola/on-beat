import 'quarter_model.dart';

class MeasureModel {
  final List<QuarterModel> quarters;

  MeasureModel(this.quarters) : assert(quarters.length == 4);

  QuarterModel operator [](int index) => quarters[index];
}
