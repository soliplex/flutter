import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soliplex_client/soliplex_client.dart' show FeedbackType;
import 'package:soliplex_frontend/design/tokens/spacing.dart';
import 'package:soliplex_frontend/features/chat/widgets/feedback_reason_dialog.dart';

enum _FeedbackPhase { idle, countdown, modal, submitted }

/// Thumbs-up / thumbs-down feedback buttons with a 5-second countdown.
///
/// State machine:
/// - **Idle**: both thumbs unhighlighted, no timer.
/// - **Countdown**: one thumb highlighted, circular timer visible, 5-second
///   countdown running. No backend call yet.
/// - **Modal**: countdown paused, reason dialog open.
/// - **Submitted**: thumb highlighted, no timer, feedback sent to backend.
///   Active thumb locked; opposite thumb can start a new countdown.
class FeedbackButtons extends StatefulWidget {
  const FeedbackButtons({
    required this.onFeedbackSubmit,
    this.countdownSeconds = 5,
    super.key,
  });

  /// Called when feedback is ready to be sent (timer expired or modal submit).
  final void Function(FeedbackType feedback, String? reason) onFeedbackSubmit;

  /// Duration of the countdown in seconds.
  final int countdownSeconds;

  @override
  State<FeedbackButtons> createState() => _FeedbackButtonsState();
}

class _FeedbackButtonsState extends State<FeedbackButtons>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  _FeedbackPhase _phase = _FeedbackPhase.idle;
  FeedbackType? _direction;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.countdownSeconds),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTap(FeedbackType tapped) {
    switch (_phase) {
      case _FeedbackPhase.idle:
        _startCountdown(tapped);
      case _FeedbackPhase.countdown:
        if (tapped == _direction) {
          // Toggle off — cancel, return to idle
          _controller.stop();
          _countdownTimer?.cancel();
          setState(() {
            _phase = _FeedbackPhase.idle;
            _direction = null;
          });
        } else {
          // Switch direction — restart countdown
          _startCountdown(tapped);
        }
      case _FeedbackPhase.modal:
      // Reason dialog is open; taps on the underlying buttons are a no-op.
      case _FeedbackPhase.submitted:
        if (tapped != _direction) {
          // Start new countdown for opposite thumb
          _startCountdown(tapped);
        }
      // Tapping the active (submitted) thumb is a no-op
    }
  }

  void _startCountdown(FeedbackType direction) {
    _countdownTimer?.cancel();
    setState(() {
      _phase = _FeedbackPhase.countdown;
      _direction = direction;
    });
    _controller.reverse(from: 1);
    _countdownTimer = Timer(
      Duration(seconds: widget.countdownSeconds),
      () {
        if (mounted && _phase == _FeedbackPhase.countdown) {
          _submit(null);
        }
      },
    );
  }

  Future<void> _onTellUsWhyTap() async {
    _countdownTimer?.cancel();
    _controller.stop();
    setState(() {
      _phase = _FeedbackPhase.modal;
    });

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const FeedbackReasonDialog(),
    );

    if (!mounted) return;

    if (reason != null) {
      _submit(reason.trim().isEmpty ? null : reason.trim());
    } else {
      _startCountdown(_direction!);
    }
  }

  void _submit(String? reason) {
    final direction = _direction!;
    setState(() {
      _phase = _FeedbackPhase.submitted;
    });
    widget.onFeedbackSubmit(direction, reason);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isThumbsUpActive =
        _direction == FeedbackType.thumbsUp && _phase != _FeedbackPhase.idle;
    final isThumbsDownActive =
        _direction == FeedbackType.thumbsDown && _phase != _FeedbackPhase.idle;

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: SoliplexSpacing.s2,
      children: [
        _FeedbackThumbButton(
          tooltip: 'Thumbs up',
          icon: isThumbsUpActive ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
          color: isThumbsUpActive
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          onTap: () => _onTap(FeedbackType.thumbsUp),
        ),
        _FeedbackThumbButton(
          tooltip: 'Thumbs down',
          icon: isThumbsDownActive
              ? Icons.thumb_down
              : Icons.thumb_down_alt_outlined,
          color: isThumbsDownActive
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          onTap: () => _onTap(FeedbackType.thumbsDown),
        ),
        if (_phase == _FeedbackPhase.countdown) ...[
          _CountdownIndicator(controller: _controller),
          InkWell(
            onTap: _onTellUsWhyTap,
            borderRadius: BorderRadius.circular(4),
            child: Text(
              'Tell us why!',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FeedbackThumbButton extends StatelessWidget {
  const _FeedbackThumbButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  static const double _iconSize = 20;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Icon(
            icon,
            size: _iconSize,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Compact circular countdown indicator adapted for the feedback actions row.
class _CountdownIndicator extends StatelessWidget {
  const _CountdownIndicator({required this.controller});

  final AnimationController controller;

  static const _totalSeconds = 5;
  static const _size = 22.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: _size,
      height: _size,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final remaining = (_totalSeconds * controller.value).ceil();
          return Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: controller.value,
                strokeWidth: 2.5,
                color: theme.colorScheme.primary,
              ),
              Text(
                '$remaining',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontSize: 8,
                  height: 1,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
