import 'package:flutter/material.dart';
import 'package:on_beat/models/quarter_state.dart';

class QuarterTile extends StatelessWidget {
  final QuarterState state;
  final bool isActive; // il quarto “in lettura”
  final Widget child;

  const QuarterTile({
    super.key,
    required this.child,
    required this.state,
    this.isActive = false,
  });

  Color _backgroundColor(BuildContext context) {
    final theme = Theme.of(context);

    switch (state) {
      case QuarterState.perfect:
        return Colors.greenAccent.withValues(alpha: 0.8);
      case QuarterState.ok:
        return Colors.yellowAccent.withValues(alpha: 0.8);
      case QuarterState.miss:
        return Colors.redAccent.withValues(alpha: 0.8);
      case QuarterState.neutral:
        return theme.colorScheme.surface;
    }
  }

  Color _borderColor(BuildContext context) {
    if (isActive) {
      return Theme.of(context).colorScheme.primary;
    }
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: 70,
      height: 70,
      padding: EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _backgroundColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor(context), width: 2),
        boxShadow: [
          if (state != QuarterState.neutral)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: AnimatedScale(
        scale: state == QuarterState.neutral ? 1.0 : 1.1,
        duration: const Duration(milliseconds: 200),
        child: child,
      ),
    );
  }
}
