import 'package:on_beat/models/note_model.dart';

class QuarterModel {
  final List<NoteModel> notes;

  QuarterModel(int rythmPattern) : notes = _parseQuarterMask(rythmPattern);

  static List<NoteModel> _parseQuarterMask(int mask) {
    final List<NoteModel> result = [];
    final bits = List.generate(4, (i) => ((mask >> (3 - i)) & 1) == 1);

    int i = 0;
    bool isRest = true;
    int count = 0;

    // Step through all bits
    while (i < 4) {
      if (!bits[i]) {
        count++;
        i++;
        continue;
      }
      if (i != 0) {
        result.add(NoteModel(duration: count / 4.0, isNote: !isRest));
      }

      count = 1;
      isRest = false;
      i++;
    }
    result.add(NoteModel(duration: count / 4.0, isNote: isRest));

    return result;
  }

  @override
  String toString() {
    return notes.toString();
  }
}
