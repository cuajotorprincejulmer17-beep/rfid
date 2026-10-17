/**
 * Clearly labelled display data for the Stage 1 prototype. It is isolated here
 * and must not be imported by future API services.
 */
export const SAMPLE = {
  attendance: { status: 'Time in recorded', last: '7:45 AM · Today' },
  nextClass: { title: 'Philosophy', time: '10:00 – 11:30 AM', room: 'Room 204' },
  tasks: [
    { id: 't1', title: 'Sample task: Activity 3', due: 'Due Oct 22 · 11:59 PM' },
    { id: 't2', title: 'Sample task: Quiz review', due: 'Due Oct 23 · 10:00 AM' },
    { id: 't3', title: 'Sample task: Performance task', due: 'Due Oct 24 · 11:59 PM' },
  ],
  updates: [{ id: 'u1', title: 'Sample announcement: enrollment notice', ago: '2h ago' }],
  review: { title: 'Data Structures', meta: '8 cards' },
  recentNote: { title: 'Data Structures', preview: 'Linked lists, stacks and queues', ago: '2h ago' },
} as const;
