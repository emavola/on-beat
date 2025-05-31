class NoteModel {
  final DurationType duration;
  final bool isRest;
  final DurationType nextNoteDuration;

  NoteModel({
    required this.duration,
    required this.isRest,
    required this.nextNoteDuration,
  });
}

enum DurationType { whole, half, quarter, eighth }
