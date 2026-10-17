/**
 * SAMPLE DATA for the visual prototype only. It is isolated here on purpose:
 * never import it from src/services (real API code) and never present it as real records.
 */
export const SAMPLE = {
  attendancePercent: 92,
  nextClass: { title: 'Philosophy', time: '10:00 AM' },
  tasksPending: 3,
  announcementsNew: 2,
  recentNotes: [
    { id: 'n1', title: 'Data Structures', preview: 'Linked lists, stacks and queues', ago: '2h ago' },
    { id: 'n2', title: 'Art History Review', preview: 'Middle Ages through Realism', ago: '4h ago' },
  ],
} as const;
