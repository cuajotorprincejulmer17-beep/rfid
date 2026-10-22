// SAMPLE DATA
//
// Everything in this file is invented. It exists so the features the school
// backend does not serve yet can be demonstrated and tested.
//
// It is imported by exactly one place: the sample repository implementations
// in `demo_sample_repositories.dart`. No screen imports it, and no
// real-data repository imports it. The UI labels anything drawn from it as
// "Sample data".
//
// The backend contract lists no endpoints for schedule, tasks, a directory,
// rooms, Digital ID, lost and found, the library or the campus map, so
// these features cannot be served by the real API yet.

import '../../models/demo_models.dart';

/// The moment the sample data is anchored to.
///
/// Everything is generated relative to now, so the schedule always has a
/// class that is happening and a task that is due soon.
final DateTime sampleNow = DateTime.now();

DateTime _at(int daysFromNow, int hour, [int minute = 0]) {
  final day = sampleNow.add(Duration(days: daysFromNow));
  return DateTime(day.year, day.month, day.day, hour, minute);
}

/// Sample events for the schedule.
final List<ScheduleEvent> sampleEvents = <ScheduleEvent>[
  ScheduleEvent(
    id: 'ev-1',
    title: 'Mathematics 2',
    start: _at(0, 8, 0),
    end: _at(0, 9, 30),
    room: 'Room 204, Main Building',
    kind: 'class',
  ),
  ScheduleEvent(
    id: 'ev-2',
    title: 'Physics Laboratory',
    start: _at(0, 10, 0),
    end: _at(0, 12, 0),
    room: 'Lab 3, Science Block',
    kind: 'class',
  ),
  ScheduleEvent(
    id: 'ev-3',
    title: 'Library study block',
    start: _at(0, 14, 0),
    end: _at(0, 16, 0),
    room: 'Library, Level 1',
    kind: 'personal',
  ),
  ScheduleEvent(
    id: 'ev-4',
    title: 'English Literature',
    start: _at(1, 9, 0),
    end: _at(1, 10, 30),
    room: 'Room 118, Main Building',
    kind: 'class',
  ),
  ScheduleEvent(
    id: 'ev-5',
    title: 'Midterm Examination',
    start: _at(2, 8, 0),
    end: _at(2, 10, 0),
    room: 'Hall A, Examination Centre',
    kind: 'exam',
  ),
  ScheduleEvent(
    id: 'ev-6',
    title: 'Physical Education',
    start: _at(3, 11, 0),
    end: _at(3, 12, 30),
    room: 'Gymnasium',
    kind: 'class',
  ),
  ScheduleEvent(
    id: 'ev-7',
    title: 'Seminar: Research Methods',
    start: _at(4, 15, 0),
    end: _at(4, 16, 30),
    room: 'Seminar Room 2',
    kind: 'class',
  ),
];

/// Sample tasks.
final List<PulseTask> sampleTasks = <PulseTask>[
  PulseTask(
    id: 'task-1',
    title: 'Physics problem set 4',
    course: 'PHY 102',
    due: _at(0, 23, 59),
    priority: 'high',
  ),
  PulseTask(
    id: 'task-2',
    title: 'Read chapter 7 and take notes',
    course: 'ENG 201',
    due: _at(1, 18, 0),
    priority: 'medium',
  ),
  PulseTask(
    id: 'task-3',
    title: 'Submit the lab report',
    course: 'PHY 102',
    due: _at(2, 12, 0),
    priority: 'high',
  ),
  PulseTask(
    id: 'task-4',
    title: 'Group project outline',
    course: 'MTH 220',
    due: _at(4, 20, 0),
    priority: 'low',
  ),
  PulseTask(
    id: 'task-5',
    title: 'Revise for the midterm',
    course: 'MTH 201',
    due: _at(-2, 20, 0),
    priority: 'medium',
    completed: true,
  ),
];

/// Sample updates.
final List<UpdateItem> sampleUpdates = <UpdateItem>[
  UpdateItem(
    id: 'up-1',
    title: 'Class suspension on Thursday',
    body:
        'All afternoon classes are suspended on Thursday because of the '
        'scheduled facility maintenance. Morning classes run as usual.',
    category: 'school',
    publishedAt: _at(-1, 16, 30),
  ),
  UpdateItem(
    id: 'up-2',
    title: 'Research Week registration opens',
    body:
        'Registration for the undergraduate research week runs from Monday. '
        'Places are limited and are handed out in order of sign-up.',
    category: 'academic',
    publishedAt: _at(-2, 9, 0),
  ),
  UpdateItem(
    id: 'up-3',
    title: 'Library extends its opening hours',
    body:
        'During the examination period the library opens until midnight on '
        'weekdays and until 18:00 at the weekend.',
    category: 'events',
    publishedAt: _at(-3, 11, 45),
  ),
  UpdateItem(
    id: 'up-4',
    title: 'Student council election results',
    body:
        'The results of the student council election have been published. '
        'The new council starts on the first Monday of next month.',
    category: 'school',
    publishedAt: _at(-5, 14, 0),
    read: true,
  ),
];

/// Sample rooms.
final List<CampusRoom> sampleRooms = <CampusRoom>[
  const CampusRoom(
    id: 'room-204',
    name: 'Room 204',
    building: 'Main Building',
    floor: 2,
    capacity: 48,
    services: <String>['Projector', 'Whiteboard'],
  ),
  const CampusRoom(
    id: 'room-118',
    name: 'Room 118',
    building: 'Main Building',
    floor: 1,
    capacity: 36,
    services: <String>['Projector'],
  ),
  const CampusRoom(
    id: 'lab-3',
    name: 'Laboratory 3',
    building: 'Science Block',
    floor: 1,
    capacity: 24,
    services: <String>['Lab benches', 'Safety shower'],
  ),
  const CampusRoom(
    id: 'hall-a',
    name: 'Hall A',
    building: 'Examination Centre',
    floor: 1,
    capacity: 220,
    services: <String>['Hearing loop'],
  ),
  const CampusRoom(
    id: 'gym-1',
    name: 'Gymnasium',
    building: 'Sports Complex',
    floor: 1,
    capacity: 120,
    services: <String>['Changing rooms', 'Equipment hire'],
  ),
  const CampusRoom(
    id: 'seminar-2',
    name: 'Seminar Room 2',
    building: 'Humanities Wing',
    floor: 2,
    capacity: 20,
    services: <String>['Display screen'],
  ),
];

/// Sample directory entries.
final List<DirectoryEntry> sampleDirectory = <DirectoryEntry>[
  const DirectoryEntry(
    id: 'dir-1',
    name: 'Dr. Amara Reyes',
    role: 'Lecturer',
    department: 'Mathematics',
    email: 'a.reyes@example.edu',
    phone: '+63 900 000 0001',
  ),
  const DirectoryEntry(
    id: 'dir-2',
    name: 'Engr. Tomas Vela',
    role: 'Lab Instructor',
    department: 'Physics',
    email: 't.vela@example.edu',
    phone: '+63 900 000 0002',
  ),
  const DirectoryEntry(
    id: 'dir-3',
    name: 'Registrar Office',
    role: 'Administrative Office',
    department: 'Registrar',
    email: 'registrar@example.edu',
    phone: '+63 900 000 0003',
  ),
  const DirectoryEntry(
    id: 'dir-4',
    name: 'Campus Security Desk',
    role: 'Service',
    department: 'Security',
    email: 'security@example.edu',
    phone: '+63 900 000 0004',
  ),
  const DirectoryEntry(
    id: 'dir-5',
    name: 'Dr. Laila Haddad',
    role: 'Lecturer',
    department: 'English',
    email: 'l.haddad@example.edu',
  ),
];

/// Sample lost and found items.
final List<LostFoundItem> sampleLostFound = <LostFoundItem>[
  LostFoundItem(
    id: 'lf-1',
    name: 'Blue notebook, Mathematics',
    category: 'Stationery',
    location: 'Room 204, Main Building',
    reportedAt: _at(-1, 10, 0),
    claimed: false,
  ),
  LostFoundItem(
    id: 'lf-2',
    name: 'Student ID card',
    category: 'Cards',
    location: 'Library, Level 1',
    reportedAt: _at(-2, 15, 30),
    claimed: false,
  ),
  LostFoundItem(
    id: 'lf-3',
    name: 'Black umbrella',
    category: 'Belongings',
    location: 'Gymnasium',
    reportedAt: _at(-4, 12, 0),
    claimed: true,
  ),
  LostFoundItem(
    id: 'lf-4',
    name: 'Calculus textbook, 3rd edition',
    category: 'Books',
    location: 'Laboratory 3, Science Block',
    reportedAt: _at(-6, 9, 15),
    claimed: false,
  ),
];

/// Sample library items.
final List<LibraryItem> sampleLibrary = <LibraryItem>[
  const LibraryItem(
    id: 'lib-1',
    title: 'Introduction to Algorithms',
    author: 'Cormen, Leiserson, Rivest and Stein',
    shelf: 'CS 005.1',
    available: true,
    featured: true,
  ),
  const LibraryItem(
    id: 'lib-2',
    title: 'Fundamentals of Physics',
    author: 'Halliday, Resnick and Walker',
    shelf: 'PH 021.4',
    available: true,
    featured: true,
  ),
  const LibraryItem(
    id: 'lib-3',
    title: 'Pride and Prejudice',
    author: 'Jane Austen',
    shelf: 'EN 013.2',
    available: false,
  ),
  const LibraryItem(
    id: 'lib-4',
    title: 'Calculus: Early Transcendentals',
    author: 'Stewart',
    shelf: 'MA 002.7',
    available: true,
  ),
  const LibraryItem(
    id: 'lib-5',
    title: 'The Selfish Gene',
    author: 'Richard Dawkins',
    shelf: 'BI 030.1',
    available: false,
  ),
];

/// Sample campus map places.
final List<MapPlace> sampleMapPlaces = <MapPlace>[
  const MapPlace(
    id: 'map-1',
    name: 'Main Building',
    x: 20,
    y: 30,
    width: 110,
    height: 70,
  ),
  const MapPlace(
    id: 'map-2',
    name: 'Science Block',
    x: 150,
    y: 30,
    width: 100,
    height: 70,
  ),
  const MapPlace(
    id: 'map-3',
    name: 'Library',
    x: 20,
    y: 120,
    width: 90,
    height: 60,
  ),
  const MapPlace(
    id: 'map-4',
    name: 'Sports Complex',
    x: 270,
    y: 30,
    width: 90,
    height: 60,
  ),
  const MapPlace(
    id: 'map-5',
    name: 'Humanities Wing',
    x: 150,
    y: 120,
    width: 100,
    height: 60,
  ),
  const MapPlace(
    id: 'map-6',
    name: 'Cafeteria',
    x: 270,
    y: 120,
    width: 90,
    height: 60,
  ),
];

/// Sample FAQ entries.
final List<FaqItem> sampleFaq = <FaqItem>[
  const FaqItem(
    id: 'faq-1',
    question: 'How do I record an attendance scan?',
    answer:
        'Attendance is recorded by tapping your RFID card on the reader at '
        'the gate. The server decides the outcome, and the app only shows '
        'the status it is given.',
  ),
  const FaqItem(
    id: 'faq-2',
    question: 'What does "unavailable" mean on my attendance?',
    answer:
        'It means the server could not determine a status for that day, for '
        'example because the reader was offline. It does not mean you were '
        'absent.',
  ),
  const FaqItem(
    id: 'faq-3',
    question: 'Can I get a replacement student ID?',
    answer:
        'Replacement cards are handled by the registrar. The app shows the '
        'card and a demo code, but it does not issue official credentials.',
  ),
  const FaqItem(
    id: 'faq-4',
    question: 'Are tasks and notes official school records?',
    answer:
        'No. Tasks and notes live only on your device and are your own '
        'content, not official school information.',
  ),
];

/// Sample support paths.
final List<AssistancePath> sampleAssistance = <AssistancePath>[
  const AssistancePath(
    id: 'as-1',
    title: 'Card or attendance problem',
    description:
        'If your card was not read, or your attendance shows the wrong '
        'status, report it so the registrar can check the reader log.',
    iconName: 'credit_card',
  ),
  const AssistancePath(
    id: 'as-2',
    title: 'Lost card',
    description:
        'A lost or damaged card has to be replaced by the registrar before '
        'it can be used at a gate again.',
    iconName: 'badge',
  ),
  const AssistancePath(
    id: 'as-3',
    title: 'Academic concern',
    description:
        'Questions about grades, enrolment or your course section go to the '
        'registrar office.',
    iconName: 'school',
  ),
  const AssistancePath(
    id: 'as-4',
    title: 'Emergency contact information',
    description:
        'The campus emergency number and the campus security desk. This is '
        'demo content and it does not place calls.',
    iconName: 'emergency',
  ),
];
