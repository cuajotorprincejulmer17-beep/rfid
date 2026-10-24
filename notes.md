# Running the server (Windows PowerShell)

The admin key now lives in `project\.env` (copy `project\.env.example`), so it
no longer has to be typed or written here. The key that used to be in this
file was committed to git: generate a new one and treat the old one as public.

```powershell
cd C:\Users\cuajo\OneDrive\Desktop\rfid-main\project
python run_server.py
```

## Mobile account claiming

```powershell
cd C:\Users\cuajo\OneDrive\Desktop\rfid-main\project
python tools\school_admin.py students
```

1. Register a student RFID card (admin console at http://localhost:5001/admin, or the desktop admin UI).
2. `python tools\school_admin.py set-profile <user_id> <student_number> --section "BSIT - 2A"`
3. `python tools\school_admin.py claim-code <user_id>` and give the code to the student.
