import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/exercise_controller.dart';
import '../models/measure_model.dart';
import '../models/quarter_model.dart';
import '../services/hit_sensor.dart';
import '../services/rhythm_scanner_service.dart';
import '../services/scan_template.dart';
import 'exercise_page.dart';

/// Scan a printed, hand-coloured rhythm sheet and play it back.
///
/// Pipeline lives in [scanRhythmBytes]; this page picks an image, runs it off
/// the UI thread, shows each processing stage, and launches the exercise with
/// the decoded measures.
class ScanRhythmPage extends StatefulWidget {
  const ScanRhythmPage({super.key});

  @override
  State<ScanRhythmPage> createState() => _ScanRhythmPageState();
}

enum _Stage { original, grayscale, binary, overlay }

class _ScanRhythmPageState extends State<ScanRhythmPage> {
  final _picker = ImagePicker();

  Uint8List? _originalBytes;
  ScanResult? _result;
  bool _busy = false;
  String? _error;
  _Stage _stage = _Stage.overlay;

  int _bpm = 80;
  SensorType _sensor = SensorType.accelerometer;

  Future<void> _pickAndScan() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) {
        setState(() => _busy = false);
        return;
      }
      final bytes = await file.readAsBytes();
      // Run the pixel-crunching pipeline off the UI thread.
      final result = await compute(scanRhythmBytes, bytes);
      if (!mounted) return;
      setState(() {
        _originalBytes = bytes;
        _result = result;
        _stage = _Stage.overlay;
        _busy = false;
      });
    } on ScanException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong reading that image.';
        _busy = false;
      });
    }
  }

  List<MeasureModel> _buildMeasures(ScanResult result) => result.measures
      .map((beats) => MeasureModel(
            beats.map(QuarterModel.fromPattern).toList(growable: false),
          ))
      .toList(growable: false);

  void _play() {
    final result = _result;
    if (result == null) return;
    final measures = _buildMeasures(result);
    if (measures.isEmpty) return;
    if (_sensor == SensorType.microphone || _sensor == SensorType.mixed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use headphones — speaker metronome will be picked up by the mic.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExercisePage(
          mode: ExerciseMode.challenge,
          sensorType: _sensor,
          bpm: _bpm,
          scriptedMeasures: measures,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Rhythm')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _intro(context),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _pickAndScan,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Pick a photo of your sheet'),
          ),
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            const Center(child: Text('Reading the sheet…')),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            _errorCard(context, _error!),
          ],
          if (result != null && !_busy) ...[
            const SizedBox(height: 24),
            _stageViewer(context, result),
            const SizedBox(height: 20),
            _decoded(context, result),
            const SizedBox(height: 24),
            _playControls(context, result),
          ],
        ],
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.document_scanner_outlined,
                  color: theme.colorScheme.onSecondaryContainer),
              const SizedBox(width: 8),
              Text('How it works', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Print the rhythm sheet (assets/scan/rhythm_template.png). Each row '
            'is one measure of ${ScanTemplate.cols} sixteenth-note cells, grouped '
            'into ${ScanTemplate.beatsPerRow} beats. Colour a cell for a stroke, '
            'leave it blank for a rest, then photograph the sheet flat with the '
            'four corner squares in frame and pick it here.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _errorCard(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageViewer(BuildContext context, ScanResult result) {
    final theme = Theme.of(context);
    final bytes = switch (_stage) {
      _Stage.original => _originalBytes,
      _Stage.grayscale => result.grayscalePng,
      _Stage.binary => result.binaryPng,
      _Stage.overlay => result.overlayPng,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Processing stages', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Otsu threshold: ${result.otsuThreshold} (global) · '
          '${result.gridThreshold} (refined inside grid)',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        SegmentedButton<_Stage>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _Stage.original, label: Text('Original')),
            ButtonSegment(value: _Stage.grayscale, label: Text('Gray')),
            ButtonSegment(value: _Stage.binary, label: Text('Binary')),
            ButtonSegment(value: _Stage.overlay, label: Text('Detected')),
          ],
          selected: {_stage},
          onSelectionChanged: (s) => setState(() => _stage = s.first),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: bytes != null
              ? Image.memory(bytes, fit: BoxFit.contain)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _decoded(BuildContext context, ScanResult result) {
    final theme = Theme.of(context);
    final measures = result.measures;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Decoded ${measures.length} measure${measures.length == 1 ? '' : 's'}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (measures.isEmpty)
          Text(
            'No filled cells found. Colour some cells and try again.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          ...List.generate(measures.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${i + 1}',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ),
                  Expanded(child: _MeasureBitsBar(beats: measures[i])),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _playControls(BuildContext context, ScanResult result) {
    final theme = Theme.of(context);
    final canPlay = result.measures.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BPM', style: theme.textTheme.labelLarge),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: _bpm > 40 ? () => setState(() => _bpm -= 5) : null,
            ),
            Text('$_bpm', style: theme.textTheme.headlineSmall),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _bpm < 240 ? () => setState(() => _bpm += 5) : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Input sensor', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<SensorType>(
          segments: const [
            ButtonSegment(
                value: SensorType.accelerometer,
                icon: Icon(Icons.vibration),
                label: Text('Accel')),
            ButtonSegment(
                value: SensorType.microphone,
                icon: Icon(Icons.mic),
                label: Text('Mic')),
            ButtonSegment(
                value: SensorType.mixed,
                icon: Icon(Icons.sensors),
                label: Text('Mixed')),
          ],
          selected: {_sensor},
          onSelectionChanged: (s) => setState(() => _sensor = s.first),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: canPlay ? _play : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play this rhythm'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

/// Renders one decoded measure as its grid of sixteenth-note cells,
/// grouped into beats — a compact echo of the printed sheet.
class _MeasureBitsBar extends StatelessWidget {
  final List<int> beats; // beatsPerRow patterns, each 0..15
  const _MeasureBitsBar({required this.beats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = theme.colorScheme.primary;
    final off = theme.colorScheme.surfaceContainerHighest;
    return Row(
      children: [
        for (var b = 0; b < beats.length; b++) ...[
          for (var i = 0; i < ScanTemplate.cellsPerBeat; i++)
            Expanded(
              child: Container(
                height: 22,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: ((beats[b] >> (ScanTemplate.cellsPerBeat - 1 - i)) &
                              1) ==
                          1
                      ? on
                      : off,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          if (b != beats.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
