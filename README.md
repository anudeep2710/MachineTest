# Team Scheduler (Flutter + Supabase)

A cross-platform app to coordinate tasks by collecting team availability and automatically finding common time slots. Built with Flutter and Supabase.

## Features
- Onboarding with optional profile photo (stored in Supabase Storage)
- Manage personal availability (CRUD)
- Create tasks with collaborators
- Smart slot finder: computes overlapping availability for the chosen duration
- Task list with filters (All, Created, Mine), pagination (Load more)
- Session persistence (local) and Sign out

## Architecture
- Flutter UI (Material)
- State management: BLoC/Cubit (flutter_bloc)
- Backend: Supabase (PostgreSQL + Storage)
- Packages: supabase_flutter, flutter_bloc, image_picker, intl, shared_preferences, uuid, equatable

## Database Schema
Use the following PostgreSQL schema in your Supabase project (as provided):

```
CREATE TABLE IF NOT EXISTS public.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  photo_url text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.availability (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  start_time timestamptz NOT NULL,
  end_time timestamptz NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- policy for demo purposes (adjust for production)
CREATE POLICY "Allow all operations on availability"
ON public.availability FOR ALL USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_availability_user_start
  ON public.availability (user_id, start_time);

CREATE TABLE IF NOT EXISTS public.tasks (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  title text NOT NULL,
  description text,
  created_by uuid NOT NULL REFERENCES public.users(id) ON DELETE SET NULL,
  start_time timestamptz,
  end_time timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_task_range CHECK (
    (start_time IS NULL AND end_time IS NULL) OR (start_time < end_time)
  )
);

CREATE TABLE IF NOT EXISTS public.task_collaborators (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  task_id bigint NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  UNIQUE (task_id, user_id)
);
```

## Setup
### Prerequisites
- Flutter 3.29.3+, Dart 3.7+
- Supabase project with the schema above

### Configure secrets
This project reads Supabase settings from build-time definitions in `lib/config.dart`.
Run with:

- PowerShell (Windows)
```
$env:SUPABASE_URL = "https://YOUR-PROJECT.supabase.co"
$env:SUPABASE_ANON_KEY = "YOUR_ANON_KEY"
flutter run -d chrome --dart-define=SUPABASE_URL=$env:SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY
```

If values are missing, the app shows a configuration screen.

### Install dependencies
```
flutter pub get
```

## Running
- Windows desktop: `flutter run -d windows --dart-define=...`
- Web (Chrome): `flutter run -d chrome --dart-define=...`
- Android/iOS: run on emulator/device with the same `--dart-define` flags.

## Usage
1. Create your profile on first launch (optionally upload an image)
2. Add availability slots in My Availability
3. Create a task:
   - Select collaborators
   - Pick duration (10/15/30/60 min)
   - The app finds common slots within the next 7 days (inclusive through end of day 7)
4. Choose a slot and create the task
5. View tasks in Task List (filter by All/Created/Mine). Click "Load more" to paginate.

## Testing
```
flutter test
```

## Troubleshooting
- Config screen appears: pass `--dart-define` values for SUPABASE_URL and SUPABASE_ANON_KEY.
- No available slots found: ensure collaborators have overlapping availability in the next 7 days; the window is inclusive until 23:59 of day 7.
- RenderFlex overflow on small screens: the Stepper controls use a responsive Wrap to avoid overflow.
- Windows desktop run error: install a supported Visual Studio toolchain or run on Chrome/emulator.

## Directory Structure (key parts)
```
lib/
  main.dart                # App bootstrap and routing
  config.dart              # Build-time config (dart-define)
  cubits/                  # BLoC/Cubit state management
  models/                  # Data models
  screens/                 # UI screens (onboarding, availability, tasks)
  utils/availability_utils.dart  # Slot-finding algorithm
```

## Notes
- Do not commit secrets. Always pass them via `--dart-define`.
- The availability policy is permissive for development; tighten RLS policies before production.
