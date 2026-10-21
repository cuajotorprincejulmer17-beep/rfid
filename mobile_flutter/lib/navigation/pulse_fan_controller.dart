import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The phase of the fan.
enum FanPhase {
  /// Not visible.
  closed,

  /// Opening. The spring is running towards 1.
  opening,

  /// Fully open.
  open,

  /// Closing. The spring is running towards 0.
  closing,
}

/// The state of the fan overlay.
class PulseFanState {
  const PulseFanState({this.phase = FanPhase.closed, this.pendingRoute});

  final FanPhase phase;

  /// The route to push once the closing spring finishes.
  final String? pendingRoute;

  /// Whether the overlay should be on screen.
  bool get isVisible => phase != FanPhase.closed;

  /// Whether a category can still be chosen.
  bool get acceptsSelection =>
      phase == FanPhase.opening || phase == FanPhase.open;

  @override
  bool operator ==(Object other) =>
      other is PulseFanState &&
      other.phase == phase &&
      other.pendingRoute == pendingRoute;

  @override
  int get hashCode => Object.hash(phase, pendingRoute);
}

/// The fan state machine.
///
/// Opening never changes the router location. Choosing a category moves the
/// fan to `closing` with the route pending, so the overlay can push the
/// route exactly once, after the closing spring has finished.
class PulseFanNotifier extends Notifier<PulseFanState> {
  @override
  PulseFanState build() => const PulseFanState();

  /// Opens the fan, or closes it when it is already open.
  void toggle() {
    if (state.phase == FanPhase.closed || state.phase == FanPhase.closing) {
      open();
    } else {
      close();
    }
  }

  /// Opens the fan. Reopening while closing retargets the spring.
  void open() {
    if (state.phase == FanPhase.closed || state.phase == FanPhase.closing) {
      state = const PulseFanState(phase: FanPhase.opening);
    }
  }

  /// Closes the fan without navigating.
  void close() {
    if (state.acceptsSelection) {
      state = PulseFanState(phase: FanPhase.closing, pendingRoute: state.pendingRoute);
    }
  }

  /// Chooses a category. The route is pushed when the closing spring ends.
  void select(String route) {
    if (state.acceptsSelection && state.pendingRoute == null) {
      state = PulseFanState(phase: FanPhase.closing, pendingRoute: route);
    }
  }

  /// Called by the overlay when the opening spring finishes.
  void onOpened() {
    if (state.phase == FanPhase.opening) {
      state = const PulseFanState(phase: FanPhase.open);
    }
  }

  /// Called by the overlay when the closing spring finishes.
  ///
  /// Returns the route to push, if any. The route is handed out exactly
  /// once, because the state is reset here.
  String? onClosed() {
    if (state.phase != FanPhase.closing) return null;
    final route = state.pendingRoute;
    state = const PulseFanState();
    return route;
  }
}

final pulseFanProvider =
    NotifierProvider<PulseFanNotifier, PulseFanState>(PulseFanNotifier.new);
