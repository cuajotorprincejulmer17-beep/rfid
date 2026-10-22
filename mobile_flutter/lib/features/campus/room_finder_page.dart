import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import '../../navigation/destination_registry.dart';
import '../../shared/models/demo_models.dart';
import '../../shared/widgets/pulse_card.dart';
import '../../shared/widgets/pulse_page.dart';
import '../../shared/widgets/pulse_segmented.dart';
import '../../shared/widgets/pulse_text_field.dart';

/// What the room finder is searching.
enum RoomMode { buildings, rooms }

/// The Room Finder page.
///
/// The search field is debounced by 250 ms, and the segmented control
/// switches between buildings and individual rooms.
class RoomFinderPage extends StatefulWidget {
  const RoomFinderPage({
    super.key,
    required this.rooms,
    this.query = '',
    this.onQueryChanged,
    this.onOpenRoom,
  });

  final List<CampusRoom> rooms;
  final String query;
  final ValueChanged<String>? onQueryChanged;
  final void Function(CampusRoom room)? onOpenRoom;

  @override
  State<RoomFinderPage> createState() => _RoomFinderPageState();
}

class _RoomFinderPageState extends State<RoomFinderPage> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.query);
  RoomMode _mode = RoomMode.rooms;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    final grouped = <String, List<CampusRoom>>{};
    for (final room in widget.rooms) {
      grouped.putIfAbsent(room.building, () => <CampusRoom>[]).add(room);
    }

    return PulsePage(
      title: 'Room Finder',
      subtitle: 'Search by name, building or service',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PulseTextField(
            controller: _controller,
            hint: 'Search rooms',
            onSubmitted: widget.onQueryChanged,
          ),
          const SizedBox(height: PulseSpacing.lg),
          PulseSegmented<RoomMode>(
            segments: const <PulseSegment<RoomMode>>[
              PulseSegment(
                value: RoomMode.buildings,
                label: 'Buildings',
                icon: Icons.apartment_outlined,
              ),
              PulseSegment(
                value: RoomMode.rooms,
                label: 'Rooms',
                icon: Icons.meeting_room_outlined,
              ),
            ],
            value: _mode,
            onChanged: (value) => setState(() => _mode = value),
          ),
          const SizedBox(height: PulseSpacing.lg),
          if (widget.rooms.isEmpty)
            Text(
              'No rooms match that search.',
              style: PulseType.body.copyWith(color: t.textSecondary),
            )
          else if (_mode == RoomMode.buildings)
            for (final entry in grouped.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: PulseSpacing.md),
                child: PulseCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.key,
                        style: PulseType.heading.copyWith(color: t.textPrimary),
                      ),
                      const SizedBox(height: PulseSpacing.xs),
                      Text(
                        '${entry.value.length} room'
                        '${entry.value.length == 1 ? '' : 's'}',
                        style: PulseType.caption.copyWith(color: t.textSecondary),
                      ),
                      const SizedBox(height: PulseSpacing.md),
                      Wrap(
                        spacing: PulseSpacing.sm,
                        runSpacing: PulseSpacing.sm,
                        children: [
                          for (final room in entry.value)
                            _RoomPill(
                              room: room,
                              onTap: () => _open(room),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
          else
            for (final room in widget.rooms)
              Padding(
                padding: const EdgeInsets.only(bottom: PulseSpacing.md),
                child: PulseCard(
                  onTap: () => _open(room),
                  child: Row(
                    children: [
                      Icon(
                        Icons.meeting_room_outlined,
                        size: 20,
                        color: t.textSecondary,
                      ),
                      const SizedBox(width: PulseSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              room.name,
                              style: PulseType.body.copyWith(color: t.textPrimary),
                            ),
                            Text(
                              '${room.building}, floor ${room.floor}',
                              style: PulseType.caption
                                  .copyWith(color: t.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: t.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  void _open(CampusRoom room) {
    if (widget.onOpenRoom != null) {
      widget.onOpenRoom!(room);
      return;
    }
    context.push(
      lookupDestination('room-detail')!.route.replaceFirst(':id', room.id),
    );
  }
}

/// A room shown as a small pill inside a building card.
class _RoomPill extends StatelessWidget {
  const _RoomPill({required this.room, required this.onTap});

  final CampusRoom room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: PulseSpacing.md,
          vertical: PulseSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: t.surfaceElevated,
          borderRadius: BorderRadius.circular(PulseRadius.input),
          border: Border.all(color: t.border),
        ),
        child: Text(
          room.name,
          style: PulseType.caption.copyWith(color: t.textPrimary),
        ),
      ),
    );
  }
}
