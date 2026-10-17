import { comingSoon } from './comingSoon';

export const ScheduleScreen = comingSoon('Schedule', 5, 'Your own class schedule and reminders. No official school schedule is connected.', false);
export const TasksScreen = comingSoon('Tasks', 5, 'Your personal tasks and planner.', false);
export const UpdatesScreen = comingSoon('Updates', 3, 'School announcements and attendance alerts from your inbox.', true);
export const AttendanceScreen = comingSoon('Attendance', 3, 'Your attendance as recorded by the school server.', true);
export const NotesScreen = comingSoon('Notes', 4, 'Quick notes with autosave and search.', true);
export const ReviewScreen = comingSoon('Review', 4, 'Flashcards and spaced-repetition review.', true);
