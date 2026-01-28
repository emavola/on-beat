class NoteModel {
  final double duration;
  final bool isNote;
  final bool isDotted;

  NoteModel({
    required this.duration,
    required this.isNote,
    this.isDotted = false,
  });
}

enum DurationType { whole, half, quarter, eighth, sixteenth }
