import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/accessibility/motion_preferences.dart';
import '../core/theme/pulse_tokens.dart';
import '../navigation/destination_registry.dart';
import '../navigation/pulse_dock.dart';
import '../navigation/pulse_fan_controller.dart';
import '../navigation/pulse_fan_overlay.dart';
import '../navigation/pulse_launcher.dart';

/// The signed-in shell.
///
/// It is the only widget that composes the dock, the fan overlay and the
/// launcher, in that paint order, so the launcher is always drawn above the
/// scrim and the fan can always be closed with the control that opened it.
class PulseShell extends ConsumerStatefulWidget {
  const PulseShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<PulseShell> createState() => _PulseShellState();
}

class _PulseShellState extends ConsumerState<PulseShell> {
  final GlobalKey _launcherKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _closeFan();
    });
  }

  void _closeFan() {
    final notifier = ref.read(pulseFanProvider.notifier);
    if (ref.read(pulseFanProvider).phase != FanPhase.closed) {
      notifier.close();
    }
  }

  void _onTabSelected(int index) {
    // Switching a tab closes the fan before the tab changes.
    _closeFan();
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final fanPhase = ref.watch(pulseFanProvider).phase;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final haptics = ref.read(hapticsControllerProvider);

    // The dock and the launcher hide immediately when the keyboard is up.
    final chromeVisible = !keyboardOpen;

    final launcherCentre = _launcherCentre(context);

    return PopScope(
      // Back closes the fan first, then pops the route.
      canPop: fanPhase == FanPhase.closed,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _closeFan();
      },
      child: Scaffold(
        backgroundColor: t.background,
        body: Stack(
          children: [
            // 1. The routed content, with enough bottom padding that the dock
            // never hides it.
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: chromeVisible ? dockBottomPadding(context) : 0,
                ),
                child: widget.navigationShell,
              ),
            ),

            // 2. The dock.
            if (chromeVisible)
              Positioned(
                left: kDockSideInset,
                right: kDockSideInset,
                bottom: MediaQuery.paddingOf(context).bottom + kDockBottomInset,
                child: PulseDock(
                  selectedId: _selectedId(),
                  onSelected: (id) => _onTabSelected(
                    dockDestinations.indexWhere((d) => d.id == id),
                  ),
                ),
              ),

            // 3. The scrim and the fan.
            if (chromeVisible && fanPhase != FanPhase.closed)
              Positioned.fill(
                child: PulseFanOverlay(
                  launcherCenter: launcherCentre,
                  availableAbove: _availableAbove(context, launcherCentre),
                ),
              ),

            // 4. The launcher, painted above the scrim.
            if (chromeVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.paddingOf(context).bottom +
                    kDockBottomInset +
                    (kDockHeight - kLauncherSize) / 2 +
                    kLauncherLift,
                child: Center(
                  child: PulseLauncher(
                    key: _launcherKey,
                    open: fanPhase != FanPhase.closed,
                    haptics: haptics,
                    onPressed: () {
                      ref.read(pulseFanProvider.notifier).toggle();
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _selectedId() {
    final index = widget.navigationShell.currentIndex;
    if (index < 0 || index >= dockDestinations.length) {
      return dockDestinations.first.id;
    }
    return dockDestinations[index].id;
  }

  /// The centre of the launcher in global coordinates.
  Offset _launcherCentre(BuildContext context) {
    final box = _launcherKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final centre = box.localToGlobal(box.size.center(Offset.zero));
      return centre;
    }
    // Before the first layout the launcher has no box, so fall back to the
    // position the shell will place it at.
    final bottom = MediaQuery.paddingOf(context).bottom +
        kDockBottomInset +
        (kDockHeight - kLauncherSize) / 2 +
        kLauncherLift;
    return Offset(
      MediaQuery.sizeOf(context).width / 2,
      MediaQuery.sizeOf(context).height - bottom - kLauncherSize / 2,
    );
  }

  /// The vertical space above the launcher.
  double _availableAbove(BuildContext context, Offset launcherCentre) {
    final top = MediaQuery.paddingOf(context).top;
    return launcherCentre.dy - top - 32;
  }
}
