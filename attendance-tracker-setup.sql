-- ============================================================
-- Team Attendance Tracker — Supabase setup
-- Run this once in your K2 Supabase project's SQL editor
-- (Dashboard → SQL Editor → New query → paste → Run)
--
-- If you ran the earlier version of this script, drop the old table
-- first (it used a different, single-row-per-day model):
--   drop table if exists attendance_log;
-- team_roster from the earlier version is compatible — no need to
-- touch it unless you want a clean start.
-- ============================================================

create extension if not exists pgcrypto;

-- Who can log in, and as what role
create table if not exists team_roster (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  pin text not null,
  role text not null default 'member',   -- 'member' or 'admin'
  active boolean not null default true,   -- soft-delete: never hard-deleted
  created_at timestamptz default now()
);

-- One row per person per day: the overall status for payroll/leave purposes.
create table if not exists day_status (
  id uuid primary key default gen_random_uuid(),
  employee_name text not null,
  entry_date date not null,
  status text not null default 'present', -- present / half-day / absent / leave
  note text,                              -- reason, only used for absent/leave
  updated_at timestamptz default now(),
  unique (employee_name, entry_date)
);

-- Many rows per person per day: each time-code segment (Office/Field/Set/
-- Post-Prod/Travel/Home/Break/Lunch), with a running log of timestamped
-- notes stored as JSON — e.g. [{"time":"12:28","text":"Mango Agreement"}]
create table if not exists time_segments (
  id uuid primary key default gen_random_uuid(),
  employee_name text not null,
  entry_date date not null,
  code text not null,
  start_time time not null,
  end_time time,                          -- null while the segment is ongoing
  logs jsonb not null default '[]'::jsonb,
  created_at timestamptz default now()
);

-- Row Level Security — required by Supabase, kept permissive since this is
-- a small internal tool that identifies people by PIN inside the app
-- itself, not via Supabase auth (same trust model as your K2 app).
alter table team_roster enable row level security;
alter table day_status enable row level security;
alter table time_segments enable row level security;

create policy "allow all - team_roster" on team_roster for all using (true) with check (true);
create policy "allow all - day_status" on day_status for all using (true) with check (true);
create policy "allow all - time_segments" on time_segments for all using (true) with check (true);

-- Turn on realtime so the admin dashboard updates live as people log in/out
alter publication supabase_realtime add table day_status;
alter publication supabase_realtime add table time_segments;

-- ------------------------------------------------------------
-- Seed yourself as the first admin so you can log in immediately.
-- Edit the name and PIN, then run this block once.
-- Skip this if you already seeded team_roster from the earlier version.
-- ------------------------------------------------------------
insert into team_roster (name, pin, role) values ('Geetha', '1234', 'admin')
on conflict do nothing;
