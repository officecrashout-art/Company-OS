-- ============================================================
-- OpenHRApp — Initial Schema Migration
-- Migrated from PocketBase → Supabase (PostgreSQL)
-- 0001_initial_schema.sql
-- ============================================================

-- Extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pg_trgm"; -- for text search on names/emails

-- ============================================================
-- ORGANIZATIONS (no FK deps — create first)
-- ============================================================
create table public.organizations (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null,
  country     text not null default 'BD',
  address     text,
  logo        text,                                        -- storage path
  subscription_status text not null default 'TRIAL'
                check (subscription_status in ('TRIAL','ACTIVE','EXPIRED','SUSPENDED','AD_SUPPORTED')),
  trial_end_date      timestamptz,
  subscription_expires timestamptz,
  ad_consent  boolean default false,
  created     timestamptz not null default now(),
  updated     timestamptz not null default now()
);

create index idx_organizations_subscription_status on public.organizations(subscription_status);

-- ============================================================
-- PROFILES (extends auth.users 1-to-1)
-- PocketBase "users" collection
-- ============================================================
create table public.profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  organization_id uuid references public.organizations(id) on delete set null,
  name            text,
  role            text not null default 'EMPLOYEE'
                  check (role in ('SUPER_ADMIN','ADMIN','HR','MANAGER','EMPLOYEE')),
  employee_id     text,
  designation     text,
  department      text,
  line_manager_id uuid references public.profiles(id) on delete set null,
  team_id         uuid,                                    -- FK added after teams table
  shift_id        uuid,                                    -- FK added after shifts table
  avatar          text,                                    -- storage path
  verified        boolean default false,
  employment_type text,
  work_type       text,
  joining_date    date,
  salary          numeric,
  mobile          text,
  emergency_contact text,
  location        text,
  created         timestamptz not null default now(),
  updated         timestamptz not null default now()
);

create index idx_profiles_organization_id on public.profiles(organization_id);
create index idx_profiles_role on public.profiles(role);
create index idx_profiles_employee_id on public.profiles(organization_id, employee_id);

-- ============================================================
-- TEAMS
-- ============================================================
create table public.teams (
  id              uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name            text not null,
  department      text,
  leader_id       uuid references public.profiles(id) on delete set null,
  created         timestamptz not null default now(),
  updated         timestamptz not null default now()
);

create index idx_teams_organization_id on public.teams(organization_id);

-- Add FK now that teams table exists
alter table public.profiles
  add constraint fk_profiles_team_id foreign key (team_id) references public.teams(id) on delete set null;

-- ============================================================
-- SHIFTS
-- ============================================================
create table public.shifts (
  id                    uuid primary key default uuid_generate_v4(),
  organization_id       uuid not null references public.organizations(id) on delete cascade,
  name                  text not null,
  start_time            time not null,
  end_time              time not null,
  late_grace_period     integer default 0,                -- minutes
  early_out_grace_period integer default 0,              -- minutes
  earliest_check_in     time,
  auto_session_close_time time,
  working_days          text[] default array['MON','TUE','WED','THU','FRI'],
  is_default            boolean default false,
  created               timestamptz not null default now(),
  updated               timestamptz not null default now()
);

create index idx_shifts_organization_id on public.shifts(organization_id);

-- Add FK now that shifts table exists
alter table public.profiles
  add constraint fk_profiles_shift_id foreign key (shift_id) references public.shifts(id) on delete set null;

-- ============================================================
-- ATTENDANCE
-- ============================================================
create table public.attendance (
  id              uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_id     text not null,                           -- denormalized ID string (PB pattern)
  employee_name   text,
  date            date not null,
  check_in        timestamptz,
  check_out       timestamptz,
  status          text default 'PRESENT'
                  check (status in ('PRESENT','ABSENT','LATE','HALF_DAY','HOLIDAY','LEAVE','REMOTE')),
  duty_type       text,
  location        text,
  latitude        double precision,
  longitude       double precision,
  selfie          text,                                    -- storage path
  remarks         text,
  reconcile       boolean default false,
  created         timestamptz not null default now(),
  updated         timestamptz not null default now()
);

create index idx_attendance_organization_id on public.attendance(organization_id);
create index idx_attendance_employee_date on public.attendance(organization_id, employee_id, date);
create index idx_attendance_date on public.attendance(organization_id, date);

-- ============================================================
-- LEAVES
-- ============================================================
create table public.leaves (
  id              uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_id     text not null,
  employee_name   text,
  line_manager_id text,
  applied_date    date,
  start_date      date not null,
  end_date        date not null,
  total_days      numeric default 1,
  type            text not null,
  reason          text,
  status          text not null default 'PENDING_MANAGER'
                  check (status in ('PENDING_MANAGER','PENDING_HR','APPROVED','REJECTED','CANCELLED')),
  manager_remarks text,
  approver_remarks text,
  created         timestamptz not null default now(),
  updated         timestamptz not null default now()
);

create index idx_leaves_organization_id on public.leaves(organization_id);
create index idx_leaves_employee_id on public.leaves(organization_id, employee_id);
create index idx_leaves_status on public.leaves(organization_id, status);
create index idx_leaves_start_date on public.leaves(organization_id, start_date);

-- ============================================================
-- ANNOUNCEMENTS
-- ============================================================
create table public.announcements (
  id              uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  author_id       uuid references public.profiles(id) on delete set null,
  author_name     text,
  title           text not null,
  content         text,
  items           jsonb,
  priority        text default 'NORMAL'
                  check (priority in ('LOW','NORMAL','HIGH','URGENT')),
  target_roles    text[],
  expires_at      timestamptz,
  response        text,
  created         timestamptz not null default now(),
  updated         timestamptz not null default now()
);

create index idx_announcements_organization_id on public.announcements(organization_id);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
create table public.notifications (
  id              uuid primary key default uuid_generate_v4(),
  organization_id uuid references public.organizations(id) on delete cascade,
  user_id         uuid references public.profiles(id) on delete cascade,
  type            text not null,
  title           text not null,
  message         text,
  is_read         boolean default false,
  priority        text default 'NORMAL'
                  check (priority in ('LOW','NORMAL','HIGH','URGENT')),
  reference_id    text,
  reference_type  text,
  action_url      text,
  metadata        jsonb,
  items           jsonb,
  created         timestamptz not null default now(),
  updated         timestamptz not null default now()
);

create index idx_notifications_user_id on public.notifications(user_id, is_read);
create index idx_notifications_organization_id on public.notifications(organization_id);

-- ============================================================
-- SETTINGS (key-value per org)
-- ============================================================
create table public.settings (
  id              uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  key             text not null,
  value           text,
  created         timestamptz not null default now(),
  updated         timestamptz not null default now(),
  unique (organization_id, key)
);

create index idx_settings_organization_key on public.settings(organization_id, key);

-- ============================================================
-- REVIEW CYCLES
-- ============================================================
create table public.review_cycles (
  id                uuid primary key default uuid_generate_v4(),
  organization_id   uuid not null references public.organizations(id) on delete cascade,
  name              text not null,
  cycle_type        text,
  start_date        date,
  end_date          date,
  review_start_date date,
  review_end_date   date,
  is_active         boolean default true,
  created           timestamptz not null default now(),
  updated           timestamptz not null default now()
);

create index idx_review_cycles_organization_id on public.review_cycles(organization_id);

-- ============================================================
-- PERFORMANCE REVIEWS
-- ============================================================
create table public.performance_reviews (
  id                  uuid primary key default uuid_generate_v4(),
  organization_id     uuid not null references public.organizations(id) on delete cascade,
  cycle_id            uuid references public.review_cycles(id) on delete set null,
  employee_id         text not null,
  employee_name       text,
  line_manager_id     text,
  manager_name        text,
  status              text default 'PENDING',
  submitted_at        timestamptz,
  completed_at        timestamptz,
  finalized_by        text,
  self_ratings        jsonb,
  manager_ratings     jsonb,
  manager_reviewed_at timestamptz,
  hr_overall_rating   text,
  hr_final_remarks    text,
  rating              text,
  competency          jsonb,
  active_competencies jsonb,
  comment             text,
  -- attendance summary snapshot
  present_days        integer,
  absent_days         integer,
  late_days           integer,
  early_out_days      integer,
  attendance_percentage numeric,
  annual_leave_taken  integer,
  casual_leave_taken  integer,
  sick_leave_taken    integer,
  leave_summary_json  jsonb,
  created             timestamptz not null default now(),
  updated             timestamptz not null default now()
);

create index idx_perf_reviews_organization_id on public.performance_reviews(organization_id);
create index idx_perf_reviews_cycle_id on public.performance_reviews(cycle_id);
create index idx_perf_reviews_employee_id on public.performance_reviews(organization_id, employee_id);

-- ============================================================
-- UPGRADE REQUESTS
-- ============================================================
create table public.upgrade_requests (
  id                  uuid primary key default uuid_generate_v4(),
  organization_id     uuid not null references public.organizations(id) on delete cascade,
  request_type        text not null
                      check (request_type in ('DONATION','TRIAL_EXTENSION','AD_SUPPORTED')),
  status              text not null default 'PENDING'
                      check (status in ('PENDING','APPROVED','REJECTED')),
  donation_amount     numeric,
  donation_tier       text,
  donation_reference  text,
  donation_screenshot text,                               -- storage path
  extension_reason    text,
  extension_days      integer,
  admin_notes         text,
  processed_by        uuid references public.profiles(id) on delete set null,
  processed_at        timestamptz,
  created             timestamptz not null default now(),
  updated             timestamptz not null default now()
);

create index idx_upgrade_requests_organization_id on public.upgrade_requests(organization_id);
create index idx_upgrade_requests_status on public.upgrade_requests(status);

-- ============================================================
-- BLOG POSTS (public, no org isolation)
-- ============================================================
create table public.blog_posts (
  id          uuid primary key default uuid_generate_v4(),
  author_id   uuid references public.profiles(id) on delete set null,
  author_name text,
  title       text not null,
  content     text,
  excerpt     text,
  cover_image text,                                       -- storage path
  slug        text unique not null,
  status      text default 'DRAFT'
              check (status in ('DRAFT','PUBLISHED','ARCHIVED')),
  published_at timestamptz,
  created     timestamptz not null default now(),
  updated     timestamptz not null default now()
);

create index idx_blog_posts_slug on public.blog_posts(slug);
create index idx_blog_posts_status on public.blog_posts(status);

-- ============================================================
-- TUTORIALS
-- ============================================================
create table public.tutorials (
  id            uuid primary key default uuid_generate_v4(),
  title         text not null,
  content       text,
  excerpt       text,
  cover_image   text,
  slug          text unique not null,
  status        text default 'DRAFT'
                check (status in ('DRAFT','PUBLISHED','ARCHIVED')),
  category      text,
  author_name   text,
  parent_id     uuid references public.tutorials(id) on delete set null,
  display_order integer default 0,
  published_at  timestamptz,
  created       timestamptz not null default now(),
  updated       timestamptz not null default now()
);

create index idx_tutorials_slug on public.tutorials(slug);
create index idx_tutorials_category on public.tutorials(category);

-- ============================================================
-- SHOWCASE ORGANIZATIONS (public landing page)
-- ============================================================
create table public.showcase_organizations (
  id            uuid primary key default uuid_generate_v4(),
  name          text not null,
  tagline       text,
  logo          text,
  country       text,
  industry      text,
  website_url   text,
  is_active     boolean default true,
  display_order integer default 0,
  created       timestamptz not null default now(),
  updated       timestamptz not null default now()
);

-- ============================================================
-- SOCIAL LINKS (public footer links)
-- ============================================================
create table public.social_links (
  id            uuid primary key default uuid_generate_v4(),
  platform      text not null,
  url           text not null,
  is_active     boolean default true,
  display_order integer default 0,
  created       timestamptz not null default now(),
  updated       timestamptz not null default now()
);

-- ============================================================
-- GUIDE HELP LINKS (in-app help)
-- ============================================================
create table public.guide_help_links (
  id            uuid primary key default uuid_generate_v4(),
  key           text unique not null,
  value         text,
  created       timestamptz not null default now(),
  updated       timestamptz not null default now()
);

-- ============================================================
-- CONTENT IMAGES (rich text editor uploads)
-- ============================================================
create table public.content_images (
  id          uuid primary key default uuid_generate_v4(),
  image       text not null,                              -- storage path
  alt_text    text,
  uploaded_by text,
  created     timestamptz not null default now(),
  updated     timestamptz not null default now()
);

-- ============================================================
-- REPORTS QUEUE (bulk email / async jobs)
-- ============================================================
create table public.reports_queue (
  id              uuid primary key default uuid_generate_v4(),
  organization_id uuid references public.organizations(id) on delete cascade,
  type            text,
  status          text default 'PENDING'
                  check (status in ('PENDING','PROCESSING','SENT','FAILED')),
  recipient_email text,
  subject         text,
  message         text,
  error_message   text,
  sent_at         timestamptz,
  created         timestamptz not null default now(),
  updated         timestamptz not null default now()
);

create index idx_reports_queue_status on public.reports_queue(status);
create index idx_reports_queue_organization_id on public.reports_queue(organization_id);

-- ============================================================
-- updated_at auto-maintenance trigger
-- ============================================================
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated = now();
  return new;
end;
$$;

-- Apply trigger to every table that has an `updated` column
do $$
declare tbl text;
begin
  foreach tbl in array array[
    'organizations','profiles','teams','shifts','attendance','leaves',
    'announcements','notifications','settings','review_cycles',
    'performance_reviews','upgrade_requests','blog_posts','tutorials',
    'showcase_organizations','social_links','guide_help_links',
    'content_images','reports_queue'
  ]
  loop
    execute format(
      'create trigger trg_%I_updated_at before update on public.%I for each row execute function public.set_updated_at()',
      tbl, tbl
    );
  end loop;
end;
$$;
-- ============================================================
-- OpenHRApp — Row Level Security Policies
-- Mirrors PocketBase listRule / viewRule / createRule / updateRule / deleteRule
-- 0002_rls_policies.sql
-- ============================================================

-- ============================================================
-- HELPER: query caller's role + org directly from profiles table
-- (free-tier compatible — no custom JWT hook required)
-- ============================================================
create or replace function public.auth_role()
returns text language sql stable security definer set search_path = public as $$
  select coalesce((select role from public.profiles where id = auth.uid()), '')
$$;

create or replace function public.auth_org_id()
returns uuid language sql stable security definer set search_path = public as $$
  select organization_id from public.profiles where id = auth.uid()
$$;

create or replace function public.is_super_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'SUPER_ADMIN' from public.profiles where id = auth.uid()), false)
$$;

-- ============================================================
-- ORGANIZATIONS
-- PB: listRule = @request.auth.role = "SUPER_ADMIN" || id = @request.auth.organization_id
-- ============================================================
alter table public.organizations enable row level security;

create policy "organizations_select" on public.organizations for select using (
  public.is_super_admin() or id = public.auth_org_id()
);
create policy "organizations_insert" on public.organizations for insert with check (
  public.is_super_admin()
);
create policy "organizations_update" on public.organizations for update using (
  public.is_super_admin() or id = public.auth_org_id()
);
create policy "organizations_delete" on public.organizations for delete using (
  public.is_super_admin()
);

-- ============================================================
-- PROFILES
-- PB: listRule = @request.auth.role = "SUPER_ADMIN" || organization_id = @request.auth.organization_id
-- ============================================================
alter table public.profiles enable row level security;

create policy "profiles_select" on public.profiles for select using (
  public.is_super_admin()
  or organization_id = public.auth_org_id()
  or id = auth.uid()
);
create policy "profiles_insert" on public.profiles for insert with check (
  public.is_super_admin()
  or organization_id = public.auth_org_id()
);
create policy "profiles_update" on public.profiles for update using (
  public.is_super_admin()
  or organization_id = public.auth_org_id()
);
create policy "profiles_delete" on public.profiles for delete using (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);

-- ============================================================
-- TEAMS
-- ============================================================
alter table public.teams enable row level security;

create policy "teams_select" on public.teams for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "teams_insert" on public.teams for insert with check (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);
create policy "teams_update" on public.teams for update using (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);
create policy "teams_delete" on public.teams for delete using (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);

-- ============================================================
-- SHIFTS
-- ============================================================
alter table public.shifts enable row level security;

create policy "shifts_select" on public.shifts for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "shifts_insert" on public.shifts for insert with check (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);
create policy "shifts_update" on public.shifts for update using (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);
create policy "shifts_delete" on public.shifts for delete using (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);

-- ============================================================
-- ATTENDANCE
-- ============================================================
alter table public.attendance enable row level security;

create policy "attendance_select" on public.attendance for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "attendance_insert" on public.attendance for insert with check (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "attendance_update" on public.attendance for update using (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR','MANAGER'))
);
create policy "attendance_delete" on public.attendance for delete using (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);

-- ============================================================
-- LEAVES
-- ============================================================
alter table public.leaves enable row level security;

create policy "leaves_select" on public.leaves for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "leaves_insert" on public.leaves for insert with check (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "leaves_update" on public.leaves for update using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "leaves_delete" on public.leaves for delete using (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);

-- ============================================================
-- ANNOUNCEMENTS
-- ============================================================
alter table public.announcements enable row level security;

create policy "announcements_select" on public.announcements for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "announcements_insert" on public.announcements for insert with check (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR','MANAGER'))
);
create policy "announcements_update" on public.announcements for update using (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR','MANAGER'))
);
create policy "announcements_delete" on public.announcements for delete using (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
alter table public.notifications enable row level security;

create policy "notifications_select" on public.notifications for select using (
  public.is_super_admin()
  or user_id = auth.uid()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);
create policy "notifications_insert" on public.notifications for insert with check (
  auth.uid() is not null
);
create policy "notifications_update" on public.notifications for update using (
  public.is_super_admin() or user_id = auth.uid()
);
create policy "notifications_delete" on public.notifications for delete using (
  public.is_super_admin()
  or user_id = auth.uid()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);

-- ============================================================
-- SETTINGS
-- ============================================================
alter table public.settings enable row level security;

create policy "settings_select" on public.settings for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "settings_insert" on public.settings for insert with check (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);
create policy "settings_update" on public.settings for update using (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);
create policy "settings_delete" on public.settings for delete using (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() = 'ADMIN')
);

-- ============================================================
-- REVIEW CYCLES
-- ============================================================
alter table public.review_cycles enable row level security;

create policy "review_cycles_select" on public.review_cycles for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "review_cycles_insert" on public.review_cycles for insert with check (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);
create policy "review_cycles_update" on public.review_cycles for update using (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);
create policy "review_cycles_delete" on public.review_cycles for delete using (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() = 'ADMIN')
);

-- ============================================================
-- PERFORMANCE REVIEWS
-- ============================================================
alter table public.performance_reviews enable row level security;

create policy "perf_reviews_select" on public.performance_reviews for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "perf_reviews_insert" on public.performance_reviews for insert with check (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "perf_reviews_update" on public.performance_reviews for update using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "perf_reviews_delete" on public.performance_reviews for delete using (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);

-- ============================================================
-- UPGRADE REQUESTS
-- PB: listRule = SUPER_ADMIN || organization_id = auth.organization_id
-- ============================================================
alter table public.upgrade_requests enable row level security;

create policy "upgrade_requests_select" on public.upgrade_requests for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "upgrade_requests_insert" on public.upgrade_requests for insert with check (
  auth.uid() is not null
);
create policy "upgrade_requests_update" on public.upgrade_requests for update using (
  public.is_super_admin()
);
create policy "upgrade_requests_delete" on public.upgrade_requests for delete using (
  public.is_super_admin()
);

-- ============================================================
-- BLOG POSTS (public read, SUPER_ADMIN write)
-- ============================================================
alter table public.blog_posts enable row level security;

create policy "blog_posts_select" on public.blog_posts for select using (
  status = 'PUBLISHED' or public.is_super_admin() or auth.uid() is not null
);
create policy "blog_posts_insert" on public.blog_posts for insert with check (
  public.is_super_admin()
);
create policy "blog_posts_update" on public.blog_posts for update using (
  public.is_super_admin()
);
create policy "blog_posts_delete" on public.blog_posts for delete using (
  public.is_super_admin()
);

-- ============================================================
-- TUTORIALS (public read, SUPER_ADMIN write)
-- ============================================================
alter table public.tutorials enable row level security;

create policy "tutorials_select" on public.tutorials for select using (
  status = 'PUBLISHED' or public.is_super_admin() or auth.uid() is not null
);
create policy "tutorials_insert" on public.tutorials for insert with check (
  public.is_super_admin()
);
create policy "tutorials_update" on public.tutorials for update using (
  public.is_super_admin()
);
create policy "tutorials_delete" on public.tutorials for delete using (
  public.is_super_admin()
);

-- ============================================================
-- SHOWCASE ORGANIZATIONS (public read)
-- ============================================================
alter table public.showcase_organizations enable row level security;

create policy "showcase_orgs_select" on public.showcase_organizations for select using (true);
create policy "showcase_orgs_write" on public.showcase_organizations for all using (
  public.is_super_admin()
);

-- ============================================================
-- SOCIAL LINKS (public read)
-- ============================================================
alter table public.social_links enable row level security;

create policy "social_links_select" on public.social_links for select using (true);
create policy "social_links_write" on public.social_links for all using (
  public.is_super_admin()
);

-- ============================================================
-- GUIDE HELP LINKS (public read)
-- ============================================================
alter table public.guide_help_links enable row level security;

create policy "guide_help_links_select" on public.guide_help_links for select using (true);
create policy "guide_help_links_write" on public.guide_help_links for all using (
  public.is_super_admin()
);

-- ============================================================
-- CONTENT IMAGES (authenticated read/write)
-- ============================================================
alter table public.content_images enable row level security;

create policy "content_images_select" on public.content_images for select using (
  auth.uid() is not null
);
create policy "content_images_insert" on public.content_images for insert with check (
  auth.uid() is not null
);
create policy "content_images_update" on public.content_images for update using (
  public.is_super_admin()
);
create policy "content_images_delete" on public.content_images for delete using (
  public.is_super_admin()
);

-- ============================================================
-- REPORTS QUEUE
-- ============================================================
alter table public.reports_queue enable row level security;

create policy "reports_queue_select" on public.reports_queue for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "reports_queue_insert" on public.reports_queue for insert with check (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);
create policy "reports_queue_update" on public.reports_queue for update using (
  public.is_super_admin()
);
create policy "reports_queue_delete" on public.reports_queue for delete using (
  public.is_super_admin()
);
-- ============================================================
-- OpenHRApp — Auth Hook: Custom JWT Claims
-- Injects role + organization_id into app_metadata so RLS
-- helper functions (auth_role, auth_org_id) can read them
-- without a DB round-trip on every query.
-- 0003_auth_hooks.sql
-- ============================================================

-- Grant usage so the hook can query profiles
grant usage on schema public to supabase_auth_admin;
grant select on public.profiles to supabase_auth_admin;

create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  profile_row record;
  claims      jsonb;
begin
  select role, organization_id
    into profile_row
    from public.profiles
   where id = (event->>'user_id')::uuid;

  claims := coalesce(event->'claims', '{}'::jsonb);

  if profile_row is not null then
    claims := jsonb_set(claims, '{app_metadata}',
      coalesce(claims->'app_metadata', '{}'::jsonb)
      || jsonb_build_object(
           'role',            profile_row.role,
           'organization_id', profile_row.organization_id
         )
    );
  end if;

  return jsonb_set(event, '{claims}', claims);
end;
$$;

-- Grant execute to auth system
grant execute on function public.custom_access_token_hook to supabase_auth_admin;

-- ============================================================
-- Register hook in auth.config
-- Run this in Supabase Dashboard → Auth → Hooks → Custom Access Token
-- OR via SQL:
-- ============================================================
-- NOTE: The SQL below works on self-hosted Supabase.
-- For Supabase Cloud, register via Dashboard → Auth → Hooks instead.
--
-- update auth.config
--   set custom_access_token_hook_uri = 'pg-functions://public/custom_access_token_hook'
-- where id = 1;

-- ============================================================
-- Auto-create profile row when a new auth user signs up
-- (Handles Edge Function registrations that create via admin API
-- and need a matching profile row)
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Only insert if no profile exists (idempotent)
  insert into public.profiles (id, name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', new.email)
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
-- ============================================================
-- OpenHRApp — Fix RLS Helper Functions
-- Replaces JWT app_metadata approach (requires Pro plan hook)
-- with direct profiles table lookup — works on free tier.
-- 0004_fix_rls_helpers.sql
-- ============================================================

-- Drop the 0003 auth hook trigger (not available on free plan)
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();
drop function if exists public.custom_access_token_hook(jsonb);

-- ============================================================
-- Replace helpers: query profiles directly via auth.uid()
-- security definer + set search_path prevents privilege escalation
-- ============================================================

create or replace function public.auth_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select role from public.profiles where id = auth.uid()),
    ''
  )
$$;

create or replace function public.auth_org_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select organization_id
  from public.profiles
  where id = auth.uid()
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select role = 'SUPER_ADMIN' from public.profiles where id = auth.uid()),
    false
  )
$$;

-- ============================================================
-- Re-add auto profile creation on signup using a simpler trigger
-- that doesn't need supabase_auth_admin grants
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', new.email)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
-- ============================================================
-- OpenHRApp — Storage Buckets + RLS Policies
-- 0005_storage_buckets.sql
-- ============================================================

-- ── Buckets ──────────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars',               'avatars',               false, 5242880,  array['image/jpeg','image/png','image/webp','image/gif']),
  ('org-logos',             'org-logos',             true,  5242880,  array['image/jpeg','image/png','image/webp','image/gif']),
  ('selfies',               'selfies',               false, 10485760, array['image/jpeg','image/png','image/webp']),
  ('content-images',        'content-images',        true,  10485760, array['image/jpeg','image/png','image/webp','image/gif']),
  ('donation-screenshots',  'donation-screenshots',  false, 5242880,  array['image/jpeg','image/png','image/webp','image/gif']),
  ('showcase-logos',        'showcase-logos',        true,  5242880,  array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do nothing;

-- ── avatars (private — user reads own, admin reads org) ──────────────────────
create policy "avatars_select" on storage.objects for select using (
  bucket_id = 'avatars' and (
    public.is_super_admin()
    or (storage.foldername(name))[1] = auth.uid()::text
    or public.auth_org_id() is not null  -- any authed org member can view avatars
  )
);
create policy "avatars_insert" on storage.objects for insert with check (
  bucket_id = 'avatars' and auth.uid() is not null and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.auth_role() in ('ADMIN','HR','SUPER_ADMIN')
  )
);
create policy "avatars_update" on storage.objects for update using (
  bucket_id = 'avatars' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.auth_role() in ('ADMIN','HR','SUPER_ADMIN')
  )
);
create policy "avatars_delete" on storage.objects for delete using (
  bucket_id = 'avatars' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.auth_role() in ('ADMIN','HR','SUPER_ADMIN')
  )
);

-- ── org-logos (public read, ADMIN+ write) ────────────────────────────────────
create policy "org_logos_select" on storage.objects for select using (
  bucket_id = 'org-logos'
);
create policy "org_logos_insert" on storage.objects for insert with check (
  bucket_id = 'org-logos' and auth.uid() is not null and
  public.auth_role() in ('ADMIN','SUPER_ADMIN')
);
create policy "org_logos_update" on storage.objects for update using (
  bucket_id = 'org-logos' and
  public.auth_role() in ('ADMIN','SUPER_ADMIN')
);
create policy "org_logos_delete" on storage.objects for delete using (
  bucket_id = 'org-logos' and
  public.auth_role() in ('ADMIN','SUPER_ADMIN')
);

-- ── selfies (private — org members with ADMIN/HR/MANAGER read, uploader write)
create policy "selfies_select" on storage.objects for select using (
  bucket_id = 'selfies' and (
    public.is_super_admin()
    or public.auth_role() in ('ADMIN','HR','MANAGER')
    or (storage.foldername(name))[1] = auth.uid()::text
  )
);
create policy "selfies_insert" on storage.objects for insert with check (
  bucket_id = 'selfies' and auth.uid() is not null
);
create policy "selfies_update" on storage.objects for update using (
  bucket_id = 'selfies' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.auth_role() in ('ADMIN','HR','SUPER_ADMIN')
  )
);
create policy "selfies_delete" on storage.objects for delete using (
  bucket_id = 'selfies' and
  public.auth_role() in ('ADMIN','HR','SUPER_ADMIN')
);

-- ── content-images (public read, authed write) ───────────────────────────────
create policy "content_images_select" on storage.objects for select using (
  bucket_id = 'content-images'
);
create policy "content_images_insert" on storage.objects for insert with check (
  bucket_id = 'content-images' and auth.uid() is not null
);
create policy "content_images_update" on storage.objects for update using (
  bucket_id = 'content-images' and auth.uid() is not null
);
create policy "content_images_delete" on storage.objects for delete using (
  bucket_id = 'content-images' and
  public.auth_role() in ('ADMIN','HR','SUPER_ADMIN')
);

-- ── donation-screenshots (private — uploader + SUPER_ADMIN) ─────────────────
create policy "donation_screenshots_select" on storage.objects for select using (
  bucket_id = 'donation-screenshots' and (
    public.is_super_admin()
    or public.auth_org_id()::text = (storage.foldername(name))[1]
  )
);
create policy "donation_screenshots_insert" on storage.objects for insert with check (
  bucket_id = 'donation-screenshots' and auth.uid() is not null
);
create policy "donation_screenshots_update" on storage.objects for update using (
  bucket_id = 'donation-screenshots' and
  public.auth_role() in ('ADMIN','SUPER_ADMIN')
);
create policy "donation_screenshots_delete" on storage.objects for delete using (
  bucket_id = 'donation-screenshots' and public.is_super_admin()
);

-- ── showcase-logos (public read, SUPER_ADMIN write) ─────────────────────────
create policy "showcase_logos_select" on storage.objects for select using (
  bucket_id = 'showcase-logos'
);
create policy "showcase_logos_write" on storage.objects for all using (
  bucket_id = 'showcase-logos' and public.is_super_admin()
);
-- Required for settings upsert onConflict: 'organization_id,key'
-- Allows null organization_id (platform-level settings like guide_help_links)
create unique index if not exists idx_settings_org_key
  on public.settings (organization_id, key)
  where organization_id is not null;

create unique index if not exists idx_settings_platform_key
  on public.settings (key)
  where organization_id is null;
-- ============================================================
-- OpenHRApp — Allow employees to update their own attendance rows
-- 0007_attendance_self_update.sql
--
-- Bug: original attendance_update policy (0002) only allowed
-- ADMIN/HR/MANAGER roles to update attendance. Regular employees
-- could not write check_out to their own row, so the check-out
-- punch silently failed under RLS and the UI reverted back to
-- "Check Out".
-- ============================================================

drop policy if exists "attendance_update" on public.attendance;

create policy "attendance_update" on public.attendance for update using (
  public.is_super_admin()
  or (
    organization_id = public.auth_org_id()
    and (
      public.auth_role() in ('ADMIN','HR','MANAGER')
      or employee_id = auth.uid()
    )
  )
);
-- ============================================================
-- OpenHRApp — Fix attendance_update RLS: employee_id is text, auth.uid() is uuid
-- 0008_attendance_self_update_text_cast.sql
--
-- Migration 0007 used `employee_id = auth.uid()` but employee_id is `text`
-- (denormalized PB-style ID string) and auth.uid() is `uuid`. Postgres
-- either errors on the comparison or evaluates to false, so the self-update
-- branch never matches. Cast auth.uid() to text to fix.
-- ============================================================

drop policy if exists "attendance_update" on public.attendance;

create policy "attendance_update" on public.attendance for update using (
  public.is_super_admin()
  or (
    organization_id = public.auth_org_id()
    and (
      public.auth_role() in ('ADMIN','HR','MANAGER')
      or employee_id = auth.uid()::text
    )
  )
);
-- ============================================================
-- OpenHRApp — Cron Job Setup
-- 0009_cron_setup.sql
--
-- Enables pg_net (HTTP from SQL) for Edge Function triggers.
-- Schedules pure-SQL cleanup cron jobs via pg_cron.
--
-- Edge Function cron schedules (auto_close_sessions, auto_expire_trials,
-- auto_absent_check, daily_attendance_report, attendance_reminders,
-- review_cycle_transition) are set up separately in
-- scripts/setup-cron-edge-functions.sql after deploying Edge Functions.
-- ============================================================

-- pg_cron: must be enabled in Supabase Dashboard → Database → Extensions → pg_cron
-- before running this migration. The extension requires superuser and cannot be
-- created inside a regular migration.
-- create extension if not exists pg_cron;  ← run manually if not yet enabled

-- pg_net: enables net.http_post() for calling Edge Functions from pg_cron
create extension if not exists pg_net with schema extensions;

-- ============================================================
-- NOTIFICATION CLEANUP — Daily 3 AM UTC
-- Deletes notifications older than 30 days to keep table lean.
-- Retention period can be extended by changing the interval.
-- ============================================================
select cron.schedule(
  'notification-cleanup',
  '0 3 * * *',
  $$
    delete from public.notifications
    where created < now() - interval '30 days';
  $$
);

-- ============================================================
-- SELFIE CLEANUP — Daily 2 AM UTC
-- Clears selfie storage path on old attendance rows.
-- Note: actual Storage objects are deleted via Edge Function
-- cron-selfie-storage-cleanup (scheduled separately) because
-- Supabase Storage deletion requires service role HTTP call.
-- This SQL step nulls the path reference so the app stops
-- serving broken URLs immediately.
-- ============================================================
select cron.schedule(
  'selfie-cleanup',
  '0 2 * * *',
  $$
    update public.attendance
    set
      selfie = null,
      updated = now()
    where
      date < current_date - interval '30 days'
      and selfie is not null;
  $$
);
-- Contact form submissions from landing page (public, no auth required)
-- Anti-spam: rate-limited by email (3/hr, 10/day) via helper function,
-- honeypot column for bot detection.

-- ── Table ──────────────────────────────────────────────────────────────────────
create table public.contact_submissions (
  id         uuid primary key default uuid_generate_v4(),
  name       text not null,
  email      text not null,
  subject    text not null,
  message    text not null,
  honeypot   text not null default '',              -- hidden field; bots fill, humans don't
  created    timestamptz not null default now()
);

create index idx_contact_submissions_email_created
  on public.contact_submissions(email, created);

-- ── Rate-limit helper (SECURITY DEFINER so RLS policy can call it) ──────────────
create or replace function public.check_contact_rate_limit(p_email text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select (
    (select count(*) from public.contact_submissions
     where email = p_email
     and created > now() - interval '1 hour') < 3
    and
    (select count(*) from public.contact_submissions
     where email = p_email
     and created > now() - interval '1 day') < 10
  );
$$;

-- ── RLS ────────────────────────────────────────────────────────────────────────
alter table public.contact_submissions enable row level security;

-- Anyone can insert provided: honeypot is empty AND rate limits not exceeded
create policy "contact_submissions_insert" on public.contact_submissions
  for insert with check (
    honeypot = ''
    and public.check_contact_rate_limit(email)
  );

-- Only super admins can read submissions
create policy "contact_submissions_select" on public.contact_submissions
  for select using (public.is_super_admin());
-- ============================================================
-- OpenHRApp — Push Notification Subscriptions
-- 0011_push_subscriptions.sql
--
-- Stores Web Push (VAPID) subscriptions per user.
-- One row per user per browser/device. Upsert on endpoint.
-- ============================================================

create table public.push_subscriptions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  endpoint     text not null,
  p256dh       text not null,
  auth         text not null,
  created      timestamptz not null default now(),
  updated      timestamptz not null default now(),
  unique (user_id, endpoint)
);

create index idx_push_subs_org on public.push_subscriptions(organization_id);
create index idx_push_subs_user on public.push_subscriptions(user_id);

-- RLS
alter table public.push_subscriptions enable row level security;

-- Users can manage their own subscriptions
create policy "push_subs_own_select"
  on public.push_subscriptions for select
  using (auth.uid() = user_id);

create policy "push_subs_own_insert"
  on public.push_subscriptions for insert
  with check (auth.uid() = user_id);

create policy "push_subs_own_delete"
  on public.push_subscriptions for delete
  using (auth.uid() = user_id);

create policy "push_subs_own_update"
  on public.push_subscriptions for update
  using (auth.uid() = user_id);

-- Service role (Edge Functions) can read all
create policy "push_subs_service_read"
  on public.push_subscriptions for select
  to service_role
  using (true);
-- ============================================================
-- OpenHRApp — Broadcast Audit Log
-- 0012_broadcasts.sql
--
-- Records every Super Admin push broadcast: who sent it, target,
-- counts. Service role only writes; SUPER_ADMIN reads via RPC or
-- service-role Edge Function.
-- ============================================================

create table public.broadcasts (
  id              uuid primary key default gen_random_uuid(),
  sent_by         uuid not null references auth.users(id) on delete set null,
  sent_by_name    text,
  title           text not null,
  body            text not null,
  url             text,
  icon            text,
  target_type     text not null check (target_type in ('ALL','ORG','ROLE','USER')),
  target_value    text,
  recipient_count int  not null default 0,
  delivered_count int  not null default 0,
  failed_count    int  not null default 0,
  stale_cleaned   int  not null default 0,
  created         timestamptz not null default now()
);

create index idx_broadcasts_created on public.broadcasts(created desc);
create index idx_broadcasts_sent_by on public.broadcasts(sent_by);

-- RLS
alter table public.broadcasts enable row level security;

-- Service role full access (Edge Function writes + reads for history list)
create policy "broadcasts_service_all"
  on public.broadcasts for all
  to service_role
  using (true)
  with check (true);

-- SUPER_ADMIN can read history (role lookup via profiles)
create policy "broadcasts_superadmin_read"
  on public.broadcasts for select
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.role = 'SUPER_ADMIN'
    )
  );
-- ============================================================
-- OpenHRApp — Add email column to profiles
-- Email is stored in auth.users but not in profiles, so admin
-- views of employee profiles show an empty work email.
-- 0013_add_email_to_profiles.sql
-- ============================================================

-- Add the column (nullable initially so it works on existing rows)
alter table public.profiles add column if not exists email text;

-- Backfill existing profiles from auth.users
update public.profiles p
   set email = u.email
  from auth.users u
 where p.id = u.id
   and p.email is null;

-- Update the handle_new_user trigger to capture email on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', new.email),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Sync email changes from auth.users to profiles
create or replace function public.sync_email_from_auth()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles set email = new.email where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_email_change on auth.users;
create trigger on_auth_user_email_change
  after update of email on auth.users
  for each row execute function public.sync_email_from_auth();
-- Allow ADMIN and HR roles to see attendance/leaves across all organizations,
-- not just their own. Previously only SUPER_ADMIN had cross-org visibility.

-- DROP and recreate attendance_select policy
drop policy if exists "attendance_select" on public.attendance;
create policy "attendance_select" on public.attendance for select using (
  public.is_super_admin()
  or public.auth_role() in ('ADMIN', 'HR')
  or organization_id = public.auth_org_id()
);

-- DROP and recreate leaves_select policy
drop policy if exists "leaves_select" on public.leaves;
create policy "leaves_select" on public.leaves for select using (
  public.is_super_admin()
  or public.auth_role() in ('ADMIN', 'HR')
  or organization_id = public.auth_org_id()
);
-- ============================================================
-- OpenHRApp — Notify Super Admins RPC Function
-- Allows client code to create notifications for all SUPER_ADMIN
-- users without needing to bypass RLS on the profiles table.
-- ============================================================

-- Drop if exists (idempotent)
drop function if exists public.notify_super_admins(
  p_type text,
  p_title text,
  p_message text,
  p_priority text,
  p_reference_type text,
  p_reference_id uuid,
  p_action_url text
);

create or replace function public.notify_super_admins(
  p_type text,
  p_title text,
  p_message text default null,
  p_priority text default 'NORMAL',
  p_reference_type text default null,
  p_reference_id uuid default null,
  p_action_url text default null
)
returns setof uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  sa record;
  new_id uuid;
begin
  for sa in
    select id from public.profiles where role = 'SUPER_ADMIN'
  loop
    insert into public.notifications (
      user_id,
      type,
      title,
      message,
      is_read,
      priority,
      reference_type,
      reference_id,
      action_url
    ) values (
      sa.id,
      p_type,
      p_title,
      p_message,
      false,
      p_priority,
      p_reference_type,
      p_reference_id,
      p_action_url
    ) returning id into new_id;

    return next new_id;
  end loop;

  return;
end
$$;
-- ============================================================
-- OpenHRApp — pg_net Extension for Selfie Storage Cleanup
-- 0016_schedule_selfie_storage_cleanup.sql
--
-- Enables pg_net so the cron-selfie-storage-cleanup Edge Function
-- can be called via net.http_post() from pg_cron.
--
-- The cron schedule itself must be created via Supabase SQL Editor
-- (not through a migration), as the Supabase platform restricts
-- cron.schedule() during db push. Run this manually:
--
--   select cron.schedule(
--     'selfie-storage-cleanup',
--     '0 2 * * *',
--     $$
--       select net.http_post(
--         url := 'https://<PROJECT_REF>.supabase.co/functions/v1/cron-selfie-storage-cleanup',
--         headers := '{"Authorization": "Bearer <CRON_SECRET>", "Content-Type": "application/json"}'::jsonb,
--         body := '{}'::jsonb
--       );
--     $$
--   );
-- ============================================================

-- pg_net: enables net.http_post() for calling Edge Functions from pg_cron
create extension if not exists pg_net with schema extensions;
-- Add reading_time column to blog_posts for pre-computed read time
ALTER TABLE public.blog_posts ADD COLUMN IF NOT EXISTS reading_time INTEGER NOT NULL DEFAULT 1;

-- Backfill existing posts: strip HTML tags, count words, divide by 200 wpm
UPDATE public.blog_posts
SET reading_time = GREATEST(1, CEIL(
  array_length(
    regexp_split_to_array(
      regexp_replace(
        regexp_replace(content, '<[^>]+>', ' ', 'g'),
        '\s+',
        ' ',
        'g'
      ),
      ' '
    ),
    1
  ) / 200.0
))
WHERE content IS NOT NULL AND content != '';
-- Add category column to blog_posts for content organization
ALTER TABLE public.blog_posts ADD COLUMN IF NOT EXISTS category text;
-- Ensure organization_id allows NULL for platform-level settings (e.g. super admin theme, guide_help_links).
-- The partial unique indexes from 0006 already handle both null and non-null conflict resolution;
-- this migration just makes sure the column accepts NULLs.
ALTER TABLE public.settings ALTER COLUMN organization_id DROP NOT NULL;
-- Add index on category column for faster distinct queries and filtering
CREATE INDEX IF NOT EXISTS idx_blog_posts_category ON public.blog_posts(category);
-- Add demo mode columns to organizations table
ALTER TABLE public.organizations ADD COLUMN IF NOT EXISTS is_demo boolean DEFAULT false;
ALTER TABLE public.organizations ADD COLUMN IF NOT EXISTS demo_reset_at timestamptz;

-- Index for efficient demo-org lookups by cron functions and demo-login
CREATE INDEX IF NOT EXISTS idx_organizations_is_demo ON public.organizations(is_demo);
-- ============================================================
-- OpenHRApp — Sync profiles.verified when email is confirmed
-- When a user clicks the confirmation link, Supabase Auth sets
-- auth.users.email_confirmed_at but nothing propagates that to
-- public.profiles.verified.  This trigger closes that gap so
-- the login gate (auth.service.ts:48) no longer blocks users
-- whose email is already confirmed.
-- 0022_sync_verified_on_email_confirm.sql
-- ============================================================

-- Function: set verified=true when email_confirmed_at transitions
-- from NULL to a timestamp (first-time confirmation).
create or replace function public.set_verified_on_email_confirm()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.email_confirmed_at is null and new.email_confirmed_at is not null then
    update public.profiles
       set verified = true
     where id = new.id
       and verified = false;
  end if;
  return new;
end;
$$;

-- Trigger on auth.users — follows the same pattern as the
-- on_auth_user_email_change trigger in migration 0013.
drop trigger if exists on_auth_user_email_confirmed on auth.users;
create trigger on_auth_user_email_confirmed
  after update of email_confirmed_at on auth.users
  for each row
  when (old.email_confirmed_at is null and new.email_confirmed_at is not null)
  execute function public.set_verified_on_email_confirm();

-- Backfill: fix existing users who already confirmed their email
-- but are stuck with verified = false.  This is a one-time repair
-- that brings the data into a consistent state.
update public.profiles p
   set verified = true
  from auth.users u
 where p.id = u.id
   and u.email_confirmed_at is not null
   and p.verified = false;
-- ============================================================
-- OpenHRApp — Add status column to profiles
-- Enables employee lifecycle management: ACTIVE / INACTIVE / ON_LEAVE
-- 0023_add_profile_status.sql
-- ============================================================

-- Add status column with check constraint
alter table public.profiles
  add column if not exists status text not null default 'ACTIVE'
  check (status in ('ACTIVE', 'INACTIVE', 'ON_LEAVE'));

-- Backfill: all existing rows already default to 'ACTIVE' via the column default,
-- but explicitly set it for clarity in case the column was added without a default
-- in a prior partial run.
update public.profiles set status = 'ACTIVE' where status is null;

-- Index for filtering by status in employee directory queries
create index if not exists idx_profiles_status on public.profiles(organization_id, status);
-- Showcase consent — Addendum 4, §5b.
--
-- An organization's name and logo may appear in the showcase on the public landing page only
-- if an ADMIN of that organization has explicitly opted in. Consent is recorded, not assumed:
-- when someone asks in a year why a given organization's name is on the homepage, the answer
-- has to be a row rather than a memory.
--
-- Everything here defaults to off, so applying this migration changes nothing visible. The
-- public read path (a view over the opted-in rows) is deliberately NOT created yet — it lands
-- with the showcase component itself, once there are consents to show.

alter table organizations
  -- The opt-in itself. False for every existing organization.
  add column if not exists show_on_landing boolean not null default false,
  -- When consent was most recently given. Deliberately NOT cleared on withdrawal: we want to
  -- be able to answer "were they ever opted in, and when".
  add column if not exists landing_consent_at timestamptz,
  -- Who recorded it and how — 'admin opt-in' from the app, or a note from a super admin who
  -- obtained permission another way (email, contract). Free text on purpose; this is an audit
  -- breadcrumb for a human, not something the app branches on.
  add column if not exists landing_consent_note text;

comment on column organizations.show_on_landing is
  'ADMIN opt-in to show this organization''s name and logo in the public landing-page showcase. Withdrawable at any time from Organization & Setup → System.';
comment on column organizations.landing_consent_at is
  'When showcase consent was last granted. Retained after withdrawal as an audit record.';
comment on column organizations.landing_consent_note is
  'How consent was obtained, for consents recorded by a super admin rather than self-serve.';

-- Only an ADMIN of the organization may set the flag, and never for a demo org.
-- The existing update policy on organizations already restricts writes to the caller's own
-- organization; this adds the role and demo constraints specific to the consent columns.
create or replace function enforce_showcase_consent()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.show_on_landing is distinct from old.show_on_landing then
    -- A demo organization is not a customer and must never be showcased.
    if coalesce(new.is_demo, false) then
      raise exception 'A demo organization cannot be shown in the showcase';
    end if;

    -- Super admins (no organization_id of their own) may always record consent obtained
    -- out of band. Otherwise the caller must be an ADMIN of this organization.
    if not exists (
      select 1 from profiles p
       where p.id = auth.uid()
         and (
           p.role = 'SUPER_ADMIN'
           or (p.role = 'ADMIN' and p.organization_id = new.id)
         )
    ) then
      raise exception 'Only an ADMIN of this organization may change showcase consent';
    end if;

    -- Stamp the grant. Withdrawal leaves the previous timestamp in place.
    if new.show_on_landing then
      new.landing_consent_at := now();
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_showcase_consent on organizations;
create trigger trg_enforce_showcase_consent
  before update on organizations
  for each row
  execute function enforce_showcase_consent();
-- ============================================================
-- OpenHRApp — SECURITY FIX: restore tenant isolation on leaves + attendance
-- 0025_fix_cross_org_rls_leak.sql
--
-- Migration 0014 added a bare `auth_role() in ('ADMIN','HR')` branch to the
-- SELECT policies on public.leaves and public.attendance. That branch carries
-- no organization predicate, so ANY user holding the ADMIN or HR role in ANY
-- organization could read every leave and attendance row in the database.
--
-- Impact when found: 168 accounts (162 ADMIN + 6 HR) across 163 organizations.
-- Symptom: an org's HR approval queue listed other companies' employees, with
-- live Approve/Reject controls.
--
-- Fix: drop the unscoped branch. Cross-organization visibility is reserved for
-- SUPER_ADMIN, which is what is_super_admin() already expresses. UPDATE, INSERT
-- and DELETE policies on both tables were already correctly org-scoped and are
-- deliberately left untouched.
-- ============================================================

drop policy if exists "attendance_select" on public.attendance;
create policy "attendance_select" on public.attendance for select using (
  public.is_super_admin()
  or organization_id = public.auth_org_id()
);

drop policy if exists "leaves_select" on public.leaves;
create policy "leaves_select" on public.leaves for select using (
  public.is_super_admin()
  or organization_id = public.auth_org_id()
);
-- ============================================================
-- OpenHRApp — Tamper-resistant audit trail
-- 0026_audit_logs.sql
--
-- Written after an incident in which two leave requests in one organization
-- were moved to REJECTED and it was impossible to determine who did it: the
-- database held no actor column and no history, so the only forensic evidence
-- was which remarks column happened to be non-null.
--
-- The trigger fires inside the database, so it records the actor even when the
-- write arrives straight from PostgREST, and it cannot be skipped by a client
-- that forgets to call a logging helper.
-- ============================================================

create table if not exists public.audit_logs (
  id              uuid primary key default gen_random_uuid(),
  occurred_at     timestamptz not null default now(),
  actor_id        uuid,                    -- auth.uid(); null for service-role/cron writes
  actor_role      text,                    -- caller's profiles.role at write time
  actor_org_id    uuid,                    -- caller's organization_id at write time
  organization_id uuid,                    -- organization the affected row belongs to
  table_name      text not null,
  record_id       text not null,
  action          text not null check (action in ('INSERT','UPDATE','DELETE')),
  changed_fields  text[],                  -- populated on UPDATE only
  old_data        jsonb,
  new_data        jsonb
);

create index if not exists audit_logs_org_time_idx    on public.audit_logs (organization_id, occurred_at desc);
create index if not exists audit_logs_record_idx      on public.audit_logs (table_name, record_id, occurred_at desc);
create index if not exists audit_logs_actor_idx       on public.audit_logs (actor_id, occurred_at desc);

-- ── Generic row auditor ─────────────────────────────────────────────────────
-- security definer so it can always write to audit_logs regardless of the
-- caller's own privileges; search_path pinned to prevent hijacking.
create or replace function public.fn_audit_row()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old      jsonb := case when TG_OP = 'INSERT' then null else to_jsonb(OLD) end;
  v_new      jsonb := case when TG_OP = 'DELETE' then null else to_jsonb(NEW) end;
  v_changed  text[];
  v_org      uuid;
  v_actor    uuid := auth.uid();
  v_role     text;
  v_actorg   uuid;
  v_recid    text;
begin
  -- Identify the row and its tenant from the FULL images, before any narrowing
  -- below: id and organization_id rarely change, so they are absent from a diff.
  -- `organizations` itself has no organization_id column — its own id is the
  -- tenant key.
  if TG_TABLE_NAME = 'organizations' then
    v_org := coalesce((v_new ->> 'id')::uuid, (v_old ->> 'id')::uuid);
  else
    v_org := coalesce((v_new ->> 'organization_id')::uuid, (v_old ->> 'organization_id')::uuid);
  end if;

  v_recid := coalesce(v_new ->> 'id', v_old ->> 'id');

  -- On UPDATE, record only the fields that actually differ, and store only
  -- those fields' values rather than both full rows. Two reasons: no-op writes
  -- (refresh loops, idempotent saves) are dropped entirely, and on a
  -- high-volume table like attendance a diff is a fraction of the row size.
  -- INSERT and DELETE keep the full row — there is no diff to take, and those
  -- are the cases where you want the whole record.
  -- `updated` is maintained by a timestamp trigger, so it differs on every
  -- touch. Counting it would mean a row that changed nothing still produces an
  -- audit entry, which is all cost and no signal. Judge by the real columns.
  if TG_OP = 'UPDATE' then
    select array_agg(key order by key) into v_changed
    from jsonb_each(v_new)
    where v_new -> key is distinct from v_old -> key
      and key not in ('updated', 'created');

    if v_changed is null then
      return NEW;
    end if;

    v_old := (select jsonb_object_agg(k, v_old -> k) from unnest(v_changed) as k);
    v_new := (select jsonb_object_agg(k, v_new -> k) from unnest(v_changed) as k);
  end if;

  if v_actor is not null then
    select role, organization_id into v_role, v_actorg
    from public.profiles where id = v_actor;
  end if;

  insert into public.audit_logs (
    actor_id, actor_role, actor_org_id, organization_id,
    table_name, record_id, action, changed_fields, old_data, new_data
  ) values (
    v_actor,
    coalesce(v_role, 'SERVICE_ROLE'),
    v_actorg,
    v_org,
    TG_TABLE_NAME,
    v_recid,
    TG_OP,
    v_changed,
    v_old,
    v_new
  );

  return case when TG_OP = 'DELETE' then OLD else NEW end;
end;
$$;

-- ── Attach to the tables that carry decisions or access ─────────────────────
do $$
declare t text;
begin
  foreach t in array array['leaves','attendance','profiles','organizations','settings']
  loop
    execute format('drop trigger if exists trg_audit_%1$s on public.%1$I', t);
    execute format(
      'create trigger trg_audit_%1$s after insert or update or delete on public.%1$I
         for each row execute function public.fn_audit_row()', t);
  end loop;
end $$;

-- ── Read access: own org's admins, or SUPER_ADMIN. Nobody writes directly. ──
alter table public.audit_logs enable row level security;

drop policy if exists "audit_logs_select" on public.audit_logs;
create policy "audit_logs_select" on public.audit_logs for select using (
  public.is_super_admin()
  or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);

-- No INSERT/UPDATE/DELETE policies: with RLS enabled and no permissive policy,
-- every direct client write is rejected. The security-definer trigger is the
-- only writer, and nobody can rewrite history through the API.

-- ── Retention ───────────────────────────────────────────────────────────────
-- Audit value decays; storage cost does not. Trim to 24 months by default.
-- Schedule alongside the other pg_cron jobs, or call manually.
create or replace function public.prune_audit_logs(p_keep_months int default 24)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare v_deleted bigint;
begin
  delete from public.audit_logs
  where occurred_at < now() - make_interval(months => p_keep_months);
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;
-- ============================================================
-- OpenHRApp — Registration rate limiting + email lookup index
-- 0027_registration_rate_limit.sql
--
-- /register is public and unauthenticated. Turnstile (added alongside this
-- migration) stops commodity bots; this stops a determined human or headless
-- browser creating organizations one at a time. Mirrors the existing
-- check_contact_rate_limit pattern from 0010.
--
-- Context: at the time of writing, 130 of 163 organizations had a single user
-- and zero activity, and 81 of 318 accounts had never confirmed their email.
-- ============================================================

create table if not exists public.registration_attempts (
  id         uuid primary key default gen_random_uuid(),
  email      text not null,
  ip         text,
  succeeded  boolean not null default false,
  created    timestamptz not null default now()
);

create index if not exists registration_attempts_email_idx on public.registration_attempts (email, created desc);
create index if not exists registration_attempts_ip_idx    on public.registration_attempts (ip, created desc);

-- Locked down: only the service-role edge function touches this table.
alter table public.registration_attempts enable row level security;

-- The duplicate-email check in the register function looks up profiles by
-- email; without this it is a sequential scan on every registration.
--
-- Indexed on the bare column, not lower(email): the lookup is
-- `.eq('email', email)`, and a functional index on lower(email) would never be
-- used by that predicate. The register function lowercases the address before
-- storing and before querying, and every stored address is already lowercase,
-- so the plain index is both usable and correct. Dropped first because an
-- earlier revision created this name over lower(email), and
-- `create index if not exists` would silently keep the wrong one.
drop index if exists public.profiles_email_idx;
create index if not exists profiles_email_idx on public.profiles (email);

-- ── Rate-limit check ────────────────────────────────────────────────────────
-- Records the attempt and reports whether it should be allowed. Deliberately
-- VOLATILE (it writes) rather than STABLE like the contact-form equivalent.
create or replace function public.check_registration_rate_limit(
  p_email text,
  p_ip    text default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_by_email int;
  v_by_ip    int;
begin
  select count(*) into v_by_email
  from public.registration_attempts
  where email = lower(p_email) and created > now() - interval '1 hour';

  select count(*) into v_by_ip
  from public.registration_attempts
  where p_ip is not null and ip = p_ip and created > now() - interval '1 hour';

  insert into public.registration_attempts (email, ip) values (lower(p_email), p_ip);

  -- 3 attempts/hour per address, 5 attempts/hour per IP. An IP allowance above
  -- the email allowance leaves room for shared office NAT while still capping
  -- bulk creation from one source.
  return v_by_email < 3 and (p_ip is null or v_by_ip < 5);
end;
$$;

-- Housekeeping: attempts older than 30 days carry no signal.
create or replace function public.prune_registration_attempts()
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.registration_attempts where created < now() - interval '30 days';
$$;
-- ============================================================
-- OpenHRApp — Organization hygiene report
-- 0028_org_hygiene_report.sql
--
-- Backs the super-admin spam review screen. At the time of writing, 130 of 163
-- organizations had a single user and no activity at all — the residue of a
-- registration endpoint that ran for months with no bot protection.
--
-- Exists as one RPC rather than per-organization counts from the client, which
-- would be several hundred round-trips. SECURITY DEFINER so it can aggregate
-- across every tenant, with an explicit SUPER_ADMIN guard — without that guard
-- the definer rights would hand any authenticated user a cross-tenant census.
-- ============================================================

create or replace function public.org_hygiene_report()
returns table (
  org_id              uuid,
  org_name            text,
  org_created         timestamptz,
  org_country         text,
  org_subscription    text,
  org_trial_end       timestamptz,
  org_is_demo         boolean,
  user_count          int,
  unverified_count    int,
  attendance_count    int,
  leave_count         int,
  settings_count      int,
  admin_email         text,
  last_activity       timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_super_admin() then
    raise exception 'Only SUPER_ADMIN may run the organization hygiene report'
      using errcode = '42501';
  end if;

  return query
  with u as (
    select p.organization_id as oid,
           count(*)::int as n,
           count(*) filter (where p.verified is not true)::int as unv
    from public.profiles p
    where p.organization_id is not null
    group by p.organization_id
  ), a as (
    select t.organization_id as oid, count(*)::int as n, max(t.created) as last_at
    from public.attendance t
    where t.organization_id is not null
    group by t.organization_id
  ), l as (
    select v.organization_id as oid, count(*)::int as n, max(v.created) as last_at
    from public.leaves v
    where v.organization_id is not null
    group by v.organization_id
  ), s as (
    select st.organization_id as oid, count(*)::int as n
    from public.settings st
    where st.organization_id is not null
    group by st.organization_id
  ), adm as (
    -- The founding admin: earliest ADMIN profile in the organization.
    select distinct on (p.organization_id) p.organization_id as oid, p.email as email
    from public.profiles p
    where p.role = 'ADMIN' and p.organization_id is not null
    order by p.organization_id, p.created
  )
  select
    o.id,
    o.name,
    o.created,
    o.country,
    o.subscription_status,
    o.trial_end_date,
    coalesce(o.is_demo, false),
    coalesce(u.n, 0),
    coalesce(u.unv, 0),
    coalesce(a.n, 0),
    coalesce(l.n, 0),
    coalesce(s.n, 0),
    adm.email,
    -- GREATEST ignores nulls, so an org with only one kind of activity still
    -- reports the date it actually has.
    greatest(a.last_at, l.last_at)
  from public.organizations o
  left join u   on u.oid   = o.id
  left join a   on a.oid   = o.id
  left join l   on l.oid   = o.id
  left join s   on s.oid   = o.id
  left join adm on adm.oid = o.id
  order by o.created desc;
end;
$$;

revoke all on function public.org_hygiene_report() from public;
grant execute on function public.org_hygiene_report() to authenticated;
-- ============================================================
-- OpenHRApp — AI lifecycle email automation
-- 0029_ai_email_automation.sql
--
-- Templates a super admin can edit, an AI instruction per template, a send
-- ledger that doubles as the deduplication key, and a suppression list.
--
-- Every template ships INACTIVE. Nothing sends until a human turns it on, and
-- the reason is concrete: 81 of 318 accounts on this platform never confirmed
-- their email, and most came from the same unprotected signup form that
-- produced 130 ghost organizations. Mailing that backlog drives the bounce rate
-- up, and bounce rate decides whether openhrapp.com's real transactional mail
-- lands in an inbox or a spam folder. That reputation is slow to earn and slow
-- to repair, so the default is off.
-- ============================================================

-- ── Templates ───────────────────────────────────────────────────────────────
create table if not exists public.email_templates (
  id               uuid primary key default gen_random_uuid(),
  key              text not null unique,
  name             text not null,
  description      text,
  -- Who this template is for. The cron resolves each audience with its own query.
  audience         text not null check (audience in
                     ('UNCONFIRMED_ADMIN','NO_EMPLOYEES','NO_ATTENDANCE','TRIAL_ENDING')),
  -- Used verbatim when ai_enabled is false, and as the fallback whenever
  -- generation fails. A template that cannot send without the model is a
  -- template that stops working the day the provider has an outage.
  subject_template text not null,
  body_template    text not null,
  ai_enabled       boolean not null default true,
  -- The super admin's instruction to the model: tone, length, what to mention.
  ai_prompt        text,
  provider         text not null default 'openrouter'
                     check (provider in ('openrouter','deepseek','openai','anthropic')),
  model            text not null default 'deepseek/deepseek-chat-v3-0324:free',
  -- Days after the qualifying event to send each stage, e.g. {1,3,7}.
  send_after_days  int[] not null default '{1}',
  daily_cap        int  not null default 50 check (daily_cap between 1 and 500),
  is_active        boolean not null default false,
  created          timestamptz not null default now(),
  updated          timestamptz not null default now()
);

-- ── Send ledger ─────────────────────────────────────────────────────────────
-- The unique constraint is the whole point: a retry, an overlapping cron run or
-- a manual re-trigger can never send the same person the same stage twice.
create table if not exists public.email_sends (
  id                 uuid primary key default gen_random_uuid(),
  template_key       text not null,
  stage              int  not null,
  recipient_email    text not null,
  recipient_id       uuid,
  organization_id    uuid,
  status             text not null check (status in ('SENT','FAILED','SKIPPED','PREVIEW')),
  provider           text,
  model              text,
  subject            text,
  ai_used            boolean not null default false,
  error              text,
  created            timestamptz not null default now(),
  constraint email_sends_once unique (template_key, stage, recipient_email)
);

create index if not exists email_sends_created_idx  on public.email_sends (created desc);
create index if not exists email_sends_template_idx on public.email_sends (template_key, created desc);
create index if not exists email_sends_org_idx      on public.email_sends (organization_id);

-- ── Suppression list ────────────────────────────────────────────────────────
-- Checked before every send. A hard bounce or an unsubscribe is permanent
-- unless a human removes it.
create table if not exists public.email_suppressions (
  email    text primary key,
  reason   text not null check (reason in ('HARD_BOUNCE','UNSUBSCRIBED','COMPLAINT','MANUAL')),
  note     text,
  created  timestamptz not null default now()
);

-- ── RLS: super admin reads; the client never writes the delivery record ─────
alter table public.email_templates    enable row level security;
alter table public.email_sends        enable row level security;
alter table public.email_suppressions enable row level security;

drop policy if exists "email_templates_select" on public.email_templates;
create policy "email_templates_select" on public.email_templates
  for select using (public.is_super_admin());

-- Templates are the one thing a super admin edits directly from the dashboard.
drop policy if exists "email_templates_write" on public.email_templates;
create policy "email_templates_write" on public.email_templates
  for update using (public.is_super_admin()) with check (public.is_super_admin());

drop policy if exists "email_sends_select" on public.email_sends;
create policy "email_sends_select" on public.email_sends
  for select using (public.is_super_admin());

drop policy if exists "email_suppressions_select" on public.email_suppressions;
create policy "email_suppressions_select" on public.email_suppressions
  for select using (public.is_super_admin());

drop policy if exists "email_suppressions_write" on public.email_suppressions;
create policy "email_suppressions_write" on public.email_suppressions
  for all using (public.is_super_admin()) with check (public.is_super_admin());

-- email_sends has no write policy on purpose: only the service-role cron
-- appends to it, so the delivery record cannot be edited from the dashboard.

-- ── Starter templates, all inactive ─────────────────────────────────────────
insert into public.email_templates
  (key, name, description, audience, subject_template, body_template, ai_prompt, send_after_days, daily_cap)
values
(
  'confirm_email',
  'Confirm your email',
  'For admins who registered but never clicked the confirmation link.',
  'UNCONFIRMED_ADMIN',
  'Confirm your email to finish setting up {{org_name}}',
  '<p>Hi {{admin_name}},</p><p>You started setting up <strong>{{org_name}}</strong> on OpenHRApp but have not confirmed your email address yet. Until you do, you will not be able to sign in.</p><p><a href="{{app_url}}">Open OpenHRApp</a></p>',
  'Write a short, warm reminder that the admin has not confirmed their email address yet. Two short paragraphs at most. Mention their organization name naturally. Do not invent features, deadlines or discounts. No exclamation marks. End with one clear action: confirm the email address.',
  '{1,3,7}',
  50
),
(
  'getting_started',
  'Getting started',
  'For organizations whose admin confirmed but who never added an employee.',
  'NO_EMPLOYEES',
  'Add your first employee to {{org_name}}',
  '<p>Hi {{admin_name}},</p><p><strong>{{org_name}}</strong> is set up, but there are no employees yet. Adding your team is what turns on attendance and leave.</p><p><a href="{{app_url}}">Add your team</a></p>',
  'Write a brief, practical nudge to add their first employee. Explain in one sentence why it matters: attendance and leave only work once people are added. Two short paragraphs. Plain and helpful, not salesy. No exclamation marks.',
  '{1,4}',
  50
),
(
  'how_to_use',
  'How to use OpenHRApp',
  'For organizations with employees but no attendance recorded yet.',
  'NO_ATTENDANCE',
  'How your team checks in on OpenHRApp',
  '<p>Hi {{admin_name}},</p><p>Your team is on <strong>{{org_name}}</strong> but nobody has checked in yet. Employees check in from their own dashboard; you can see everything under Attendance.</p><p><a href="{{app_url}}">Open OpenHRApp</a></p>',
  'Explain in plain language how employees check in and where the admin sees attendance. Three short paragraphs at most. Assume the reader is not technical. Do not describe features that are not mentioned in the fallback text.',
  '{3,10}',
  50
),
(
  'trial_ending',
  'Trial ending',
  'For organizations whose trial is about to end. Coordinate with cron-expire-trials before enabling.',
  'TRIAL_ENDING',
  'Your OpenHRApp trial for {{org_name}} ends soon',
  '<p>Hi {{admin_name}},</p><p>The trial for <strong>{{org_name}}</strong> ends on {{trial_end}}.</p><p><a href="{{app_url}}">Open OpenHRApp</a></p>',
  'Write a factual, unpushy note that the trial is ending, including the date. Two short paragraphs. Do not use urgency language, countdowns or pressure. State what happens next plainly.',
  '{3}',
  50
)
on conflict (key) do nothing;
-- ============================================================
-- OpenHRApp — Correct the default OpenRouter model slug
-- 0030_fix_default_llm_model.sql
--
-- 0029 shipped with 'deepseek/deepseek-chat-v3-0324:free', which does not exist
-- on OpenRouter. Checked against the live model list: every generation would
-- have failed and silently fallen back to the plain template, which is the
-- worst kind of bug — it looks like it works.
--
-- Replaced with google/gemma-4-31b-it:free, chosen over the other free models
-- because it is instruction-tuned and the templates demand strict JSON output.
-- The larger free options are reasoning models that tend to emit a thinking
-- preamble, which breaks JSON parsing far more often than it improves the copy.
--
-- Model slugs come and go on the free tier. This column is deliberately plain
-- text and editable from the dashboard so a dead slug is a one-field fix rather
-- than a migration.
-- ============================================================

alter table public.email_templates
  alter column model set default 'google/gemma-4-31b-it:free';

update public.email_templates
set    model = 'google/gemma-4-31b-it:free',
       updated = now()
where  provider = 'openrouter'
  and  model = 'deepseek/deepseek-chat-v3-0324:free';
-- ============================================================
-- OpenHRApp — Schedule for cron-lifecycle-emails
-- 0031_schedule_lifecycle_emails.sql
--
-- pg_net is already enabled by 0016. As with the other cron jobs, the schedule
-- itself cannot be created from a migration — Supabase restricts cron.schedule()
-- during db push, and the statement embeds CRON_SECRET, which does not belong in
-- version control. Run this once in the SQL Editor, substituting the secret:
--
--   select cron.schedule(
--     'lifecycle-emails',
--     '0 9 * * *',
--     $$
--       select net.http_post(
--         url := 'https://cixryuwtlwbofabctrkk.supabase.co/functions/v1/cron-lifecycle-emails',
--         headers := '{"Authorization": "Bearer <CRON_SECRET>", "Content-Type": "application/json"}'::jsonb,
--         body := '{}'::jsonb
--       );
--     $$
--   );
--
-- Scheduling it is safe before you are ready to send: every template ships
-- inactive, so the job wakes up, finds nothing active, and exits. Turning a
-- template on in the AI Email tab is the single switch that starts delivery.
--
-- To rehearse without sending, add ?dryRun=1 to the URL. The job resolves the
-- audience and generates the copy but sends nothing and writes no send records.
--
-- To stop it:  select cron.unschedule('lifecycle-emails');
-- To inspect:  select * from cron.job where jobname = 'lifecycle-emails';
-- ============================================================

-- Nothing to apply. pg_net comes from 0016; this file documents the manual step
-- so the schedule is discoverable in the repo rather than only in someone's
-- browser history.
select 1;
-- ============================================================
-- OpenHRApp — AI admin reporting: curated views + a contained query runner
-- 0032_ai_admin_reports.sql
--
-- Lets a super admin ask questions in plain English and have a model turn them
-- into a read-only query, so they can find the organizations and addresses worth
-- targeting before switching an email template on.
--
-- The threat model is the point. Organization names and email addresses are
-- written by whoever registered, and they are fed to the model as data — so the
-- model must be assumed steerable. The containment is therefore NOT the prompt
-- and NOT the keyword filter; it is a Postgres role that is physically incapable
-- of doing anything except SELECT from four views:
--
--   * ai_readonly holds no privileges anywhere else in the database.
--   * The runner switches to that role before executing anything.
--   * The views are owned by postgres and are NOT security_invoker, so they are
--     the only window ai_readonly has onto the real tables.
--   * A statement timeout and a hard row cap bound the blast radius.
--
-- Worst realistic case if the model is fully hijacked: it reads data the super
-- admin can already read, slowly, 200 rows at a time.
-- ============================================================

create schema if not exists ai_reports;

-- ── Curated views ───────────────────────────────────────────────────────────
-- Deliberately denormalised and pre-aggregated. The model writes better SQL
-- against four obvious views than against fifteen normalised tables, and a
-- narrow surface is easier to reason about than a wide one.

create or replace view ai_reports.organizations as
with u as (
  select organization_id oid, count(*)::int n,
         count(*) filter (where verified is not true)::int unverified
  from public.profiles where organization_id is not null group by organization_id
), a as (
  select organization_id oid, count(*)::int n, max(created) last_at
  from public.attendance where organization_id is not null group by organization_id
), l as (
  select organization_id oid, count(*)::int n
  from public.leaves where organization_id is not null group by organization_id
), s as (
  select organization_id oid, count(*)::int n
  from public.settings where organization_id is not null group by organization_id
), adm as (
  select distinct on (organization_id)
         organization_id oid, email, name, verified
  from public.profiles where role = 'ADMIN' and organization_id is not null
  order by organization_id, created
)
select
  o.id                                as organization_id,
  o.name                              as organization_name,
  o.country,
  o.subscription_status,
  o.created                           as registered_at,
  o.trial_end_date,
  coalesce(o.is_demo, false)          as is_demo,
  adm.email                           as admin_email,
  adm.name                            as admin_name,
  coalesce(adm.verified, false)       as admin_email_confirmed,
  coalesce(u.n, 0)                    as user_count,
  coalesce(u.unverified, 0)           as unconfirmed_user_count,
  coalesce(a.n, 0)                    as attendance_count,
  coalesce(l.n, 0)                    as leave_count,
  coalesce(s.n, 0)                    as settings_count,
  a.last_at                           as last_attendance_at,
  (coalesce(a.n,0) = 0 and coalesce(l.n,0) = 0) as never_used,
  (now()::date - o.created::date)     as days_since_registration
from public.organizations o
left join u   on u.oid   = o.id
left join a   on a.oid   = o.id
left join l   on l.oid   = o.id
left join s   on s.oid   = o.id
left join adm on adm.oid = o.id;

create or replace view ai_reports.people as
select
  p.id              as profile_id,
  p.organization_id,
  o.name            as organization_name,
  p.name,
  p.email,
  p.role,
  p.status,
  coalesce(p.verified, false) as email_confirmed,
  p.department,
  p.designation,
  p.created         as joined_at
from public.profiles p
left join public.organizations o on o.id = p.organization_id;

create or replace view ai_reports.email_history as
select
  es.template_key,
  es.stage,
  es.recipient_email,
  es.organization_id,
  o.name as organization_name,
  es.status,
  es.provider,
  es.model,
  es.subject,
  es.ai_used,
  es.error,
  es.created as sent_at
from public.email_sends es
left join public.organizations o on o.id = es.organization_id;

create or replace view ai_reports.email_suppressions as
select email, reason, note, created as suppressed_at
from public.email_suppressions;

-- ── The contained role ──────────────────────────────────────────────────────
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'ai_readonly') then
    create role ai_readonly nologin;
  end if;
end $$;

-- Grant exactly this and nothing else.
grant usage on schema ai_reports to ai_readonly;
grant select on all tables in schema ai_reports to ai_readonly;
alter default privileges in schema ai_reports grant select on tables to ai_readonly;

-- The runner is SECURITY DEFINER, so it starts as the owner. It must be able to
-- become ai_readonly before executing anything the model wrote.
grant ai_readonly to postgres;

-- ── The query runner ────────────────────────────────────────────────────────
create or replace function public.ai_admin_query(p_sql text)
returns jsonb
language plpgsql
security definer
set search_path = ai_reports, pg_temp
as $$
declare
  v_clean  text := btrim(coalesce(p_sql, ''), E' \t\n\r;');
  v_result jsonb;
begin
  if not public.is_super_admin() then
    raise exception 'Only SUPER_ADMIN may run report queries' using errcode = '42501';
  end if;

  if v_clean = '' then
    raise exception 'No query supplied';
  end if;

  -- One statement only. Stops the classic "; drop ..." tail even though the
  -- role could not execute it anyway.
  if position(';' in v_clean) > 0 then
    raise exception 'Only a single statement is allowed';
  end if;

  if v_clean !~* '^(select|with)\s' then
    raise exception 'Only SELECT queries are allowed';
  end if;

  -- A defence in depth, not the defence. Word-bounded so an organization called
  -- "Versatile Creation Ltd" does not trip the "create" rule.
  if v_clean ~* '\m(insert|update|delete|drop|alter|create|grant|revoke|truncate|copy|call|do|vacuum|reindex|refresh|listen|notify|prepare|lock|set|reset)\M' then
    raise exception 'Only read-only SELECT queries are allowed';
  end if;

  -- Bound the cost before handing over control.
  set local statement_timeout = '8s';
  set local role ai_readonly;

  execute format(
    'select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from (%s) q limit 200) t',
    v_clean
  ) into v_result;

  reset role;
  return v_result;
exception
  when others then
    -- Always drop privileges back, then re-raise for the caller to surface.
    reset role;
    raise;
end;
$$;

revoke all on function public.ai_admin_query(text) from public;
grant execute on function public.ai_admin_query(text) to authenticated;

comment on function public.ai_admin_query(text) is
  'Runs a single read-only SELECT against the ai_reports views as the ai_readonly role. SUPER_ADMIN only. Capped at 200 rows and an 8 second timeout.';
-- ============================================================
-- OpenHRApp — Run AI report queries as the caller, not as the owner
-- 0033_ai_query_runs_as_caller.sql
--
-- 0032 made ai_admin_query SECURITY DEFINER and tried to contain it by switching
-- to a stripped-down ai_readonly role. Two problems with that:
--
--   1. SET ROLE checks membership against the SESSION user, which inside a
--      SECURITY DEFINER function is still the PostgREST role — not the owner.
--      The switch would most likely have failed at runtime.
--   2. More importantly it was solving the problem the hard way. Running as the
--      owner means starting with superuser reach and clawing privileges back,
--      and anything clawed back imperfectly (auth.users, for one) is a hole.
--
-- SECURITY INVOKER inverts it. The query runs with exactly the caller's own
-- privileges, so the strongest thing a fully hijacked model can do is read what
-- that super admin could already read through the API. auth.users is not granted
-- to `authenticated` at all, so password hashes stay unreachable by
-- construction rather than by filtering.
--
-- The ai_reports views stay owner-owned and non-security_invoker, so they can
-- still aggregate across tenants. They are reachable only through this function:
-- PostgREST exposes public and graphql_public only, so ai_reports has no HTTP
-- surface of its own, and the function gates on is_super_admin().
-- ============================================================

-- The views are the only window; the caller needs to be able to look through it.
grant usage on schema ai_reports to authenticated;
grant select on all tables in schema ai_reports to authenticated;
alter default privileges in schema ai_reports grant select on tables to authenticated;

create or replace function public.ai_admin_query(p_sql text)
returns jsonb
language plpgsql
security invoker
set search_path = ai_reports, public, pg_temp
as $$
declare
  v_clean  text := btrim(coalesce(p_sql, ''), E' \t\n\r;');
  v_result jsonb;
begin
  if not public.is_super_admin() then
    raise exception 'Only SUPER_ADMIN may run report queries' using errcode = '42501';
  end if;

  if v_clean = '' then
    raise exception 'No query supplied';
  end if;

  -- One statement only.
  if position(';' in v_clean) > 0 then
    raise exception 'Only a single statement is allowed';
  end if;

  if v_clean !~* '^(select|with)\s' then
    raise exception 'Only SELECT queries are allowed';
  end if;

  -- Defence in depth, not the defence — the caller's own privileges are.
  -- Word-bounded so "Versatile Creation Ltd" does not trip the "create" rule.
  if v_clean ~* '\m(insert|update|delete|drop|alter|create|grant|revoke|truncate|copy|call|do|vacuum|reindex|refresh|listen|notify|prepare|lock|set|reset)\M' then
    raise exception 'Only read-only SELECT queries are allowed';
  end if;

  -- A generated query should never be able to sit on a connection.
  set local statement_timeout = '8s';

  execute format(
    'select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from (%s) q limit 200) t',
    v_clean
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.ai_admin_query(text) from public;
grant execute on function public.ai_admin_query(text) to authenticated;

comment on function public.ai_admin_query(text) is
  'Runs a single read-only SELECT against the ai_reports views with the caller''s own privileges. SUPER_ADMIN only. Capped at 200 rows and an 8 second statement timeout.';

-- Retire the role from 0032. It was never load-bearing and an unused role that
-- looks like a security control is worse than no role at all.
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'ai_readonly') then
    execute 'alter default privileges in schema ai_reports revoke select on tables from ai_readonly';
    execute 'revoke all on all tables in schema ai_reports from ai_readonly';
    execute 'revoke all on schema ai_reports from ai_readonly';
    execute 'revoke ai_readonly from postgres';
    execute 'drop role ai_readonly';
  end if;
end $$;
-- ============================================================
-- OpenHRApp — Let super admins create their own email templates
-- 0034_custom_email_templates.sql
--
-- 0029 shipped four templates and an UPDATE-only policy, so they could be
-- edited but not added to. Adds INSERT and DELETE so new templates can be
-- built in the dashboard and switched on later.
--
-- Also corrects the product name in the seeded rows. 0029 had already been
-- applied when the rename happened, so fixing the migration file alone would
-- have left the live rows still saying "OpenHR" — visible to customers in the
-- subject line.
-- ============================================================

-- ── Product name in the seeded content ──────────────────────────────────────
-- Collapse then expand, so running this twice cannot produce "OpenHRAppApp",
-- and a row an admin has already corrected by hand is left as it is.
update public.email_templates
set
  name             = replace(replace(name,             'OpenHRApp', 'OpenHR'), 'OpenHR', 'OpenHRApp'),
  description      = replace(replace(description,      'OpenHRApp', 'OpenHR'), 'OpenHR', 'OpenHRApp'),
  subject_template = replace(replace(subject_template, 'OpenHRApp', 'OpenHR'), 'OpenHR', 'OpenHRApp'),
  body_template    = replace(replace(body_template,    'OpenHRApp', 'OpenHR'), 'OpenHR', 'OpenHRApp'),
  ai_prompt        = replace(replace(ai_prompt,        'OpenHRApp', 'OpenHR'), 'OpenHR', 'OpenHRApp'),
  updated          = now()
where
  name             like '%OpenHR%'
  or description   like '%OpenHR%'
  or subject_template like '%OpenHR%'
  or body_template    like '%OpenHR%'
  or ai_prompt        like '%OpenHR%';

-- ── Creating and removing templates ─────────────────────────────────────────
drop policy if exists "email_templates_insert" on public.email_templates;
create policy "email_templates_insert" on public.email_templates
  for insert with check (public.is_super_admin());

drop policy if exists "email_templates_delete" on public.email_templates;
create policy "email_templates_delete" on public.email_templates
  for delete using (public.is_super_admin());

-- A template key ends up in email_sends as the deduplication key, so it has to
-- stay stable and URL-safe. Enforced here rather than trusted from the client.
alter table public.email_templates
  drop constraint if exists email_templates_key_format;
alter table public.email_templates
  add constraint email_templates_key_format
  check (key ~ '^[a-z][a-z0-9_]{2,49}$');

-- Deleting a template must not erase the record of what it sent. email_sends
-- has no foreign key to email_templates precisely so that history outlives the
-- template; this comment exists so nobody "helpfully" adds one later.
comment on table public.email_sends is
  'Delivery record. Deliberately has no FK to email_templates: the history of what was sent must survive the template being deleted.';
-- ============================================================
-- OpenHRApp — More audiences for lifecycle email
-- 0035_more_email_audiences.sql
--
-- 0029 shipped four audiences, which is enough to prove the mechanism and not
-- enough to plan around. Adds five more, each of which the daily job resolves
-- with its own query.
--
-- Every audience still excludes the demo organization, still runs through the
-- suppression list, still obeys the per-template daily cap, and still cannot
-- send the same person the same stage twice. Widening the audience list does
-- not widen any of that.
-- ============================================================

alter table public.email_templates
  drop constraint if exists email_templates_audience_check;

alter table public.email_templates
  add constraint email_templates_audience_check check (audience in (
    -- Original four
    'UNCONFIRMED_ADMIN',  -- admin registered, never confirmed the address
    'NO_EMPLOYEES',       -- confirmed, but never added anyone
    'NO_ATTENDANCE',      -- has employees, nobody has ever checked in
    'TRIAL_ENDING',       -- trial still running; stage counts days REMAINING

    -- Added here
    'WELCOME',            -- confirmed and set up; stage counts days since registering
    'TRIAL_EXPIRED',      -- trial end date has passed and they are still on TRIAL
    'SETUP_INCOMPLETE',   -- no settings ever saved, so onboarding was abandoned
    'DORMANT',            -- was active once; stage counts days since last activity
    'ACTIVE_ENGAGED'      -- healthy and in use; for product news and tips
  ));

comment on column public.email_templates.audience is
  'Which group the daily job resolves for this template. For TRIAL_ENDING the stage counts days REMAINING before the trial ends; for DORMANT it counts days since last activity; for everything else it counts days since the qualifying event.';
-- ============================================================
-- OpenHRApp — Give the seeded templates a real call to action
-- 0036_seed_templates_with_buttons.sql
--
-- The seeded bodies ended with a bare text link, which is why a test send read
-- as an unstyled note rather than as a product email. Replaces the trailing
-- link with a button.
--
-- A button is stored as an ordinary anchor carrying data-btn. It survives
-- sanitising, stays a working link if the styling is ever dropped, and reads
-- correctly to a screen reader; the send path turns it into the table-based
-- construction email clients need.
--
-- Guarded on `not like '%data-btn%'` so a template an admin has already edited
-- and given a button is left alone. Editing customer-facing copy out from under
-- someone is worse than leaving an old default in place.
-- ============================================================

update public.email_templates
set body_template = '<p>Hi {{admin_name}},</p>'
  || '<p>You started setting up <strong>{{org_name}}</strong> on OpenHRApp but have not confirmed your email address yet. Until you do, you will not be able to sign in.</p>'
  || '<p><a href="{{app_url}}" data-btn="teal">Confirm my email</a></p>'
  || '<p>If you did not create this account, you can ignore this message and nothing further will happen.</p>',
    updated = now()
where key = 'confirm_email' and body_template not like '%data-btn%';

update public.email_templates
set body_template = '<p>Hi {{admin_name}},</p>'
  || '<p><strong>{{org_name}}</strong> is set up, but there are no employees on it yet. Attendance and leave only start working once your team is added.</p>'
  || '<p><a href="{{app_url}}" data-btn="teal">Add your team</a></p>'
  || '<p>You can add people one at a time, or import a list if you have one.</p>',
    updated = now()
where key = 'getting_started' and body_template not like '%data-btn%';

update public.email_templates
set body_template = '<p>Hi {{admin_name}},</p>'
  || '<p>Your team is on <strong>{{org_name}}</strong>, but nobody has checked in yet. Here is how it works:</p>'
  || '<ul><li>Employees check in and out from their own dashboard.</li>'
  || '<li>You see everything as it happens under Attendance.</li>'
  || '<li>Late arrivals are worked out from the office hours you set.</li></ul>'
  || '<p><a href="{{app_url}}" data-btn="blue">Open OpenHRApp</a></p>',
    updated = now()
where key = 'how_to_use' and body_template not like '%data-btn%';

update public.email_templates
set body_template = '<p>Hi {{admin_name}},</p>'
  || '<p>The trial for <strong>{{org_name}}</strong> ends on {{trial_end}}. Your data stays exactly where it is either way.</p>'
  || '<p><a href="{{app_url}}" data-btn="amber">Open OpenHRApp</a></p>',
    updated = now()
where key = 'trial_ending' and body_template not like '%data-btn%';
-- ============================================================
-- OpenHRApp — Make the seeded email copy read like a person wrote it
-- 0037_natural_email_copy.sql
--
-- "Open OpenHRApp" was a bad button label and "Your OpenHRApp trial for
-- {{org_name}} ends soon" was a bad subject line. Two problems:
--
--   1. The brand already appears in the email header, so repeating it in the
--      button is redundant. The reader knows who sent it.
--   2. A button label should name the ACTION, not the tool. "Open your
--      dashboard" tells someone what happens when they click; "Open OpenHRApp"
--      tells them where they already know they are going.
--
-- Subjects now lead with the organization name, which is the part the reader
-- recognises in a crowded inbox, rather than burying it mid-sentence.
--
-- Still guarded so an edited template is never overwritten.
-- ============================================================

update public.email_templates
set subject_template = 'Confirm your email to finish setting up {{org_name}}',
    updated = now()
where key = 'confirm_email' and subject_template like '%OpenHR%';

update public.email_templates
set subject_template = '{{org_name}}: how your team checks in',
    body_template = replace(body_template, '>Open OpenHRApp<', '>Open your dashboard<'),
    updated = now()
where key = 'how_to_use' and (subject_template like '%OpenHR%' or body_template like '%Open OpenHRApp%');

update public.email_templates
set subject_template = '{{org_name}}: your trial ends on {{trial_end}}',
    body_template = replace(body_template, '>Open OpenHRApp<', '>Open your dashboard<'),
    updated = now()
where key = 'trial_ending' and (subject_template like '%OpenHR%' or body_template like '%Open OpenHRApp%');

-- Catch-all for any template still carrying the awkward label, including ones
-- created before this migration.
update public.email_templates
set body_template = replace(body_template, '>Open OpenHRApp<', '>Open your dashboard<'),
    updated = now()
where body_template like '%>Open OpenHRApp<%';
-- ============================================================
-- OpenHRApp / Company OS — Phase 1 & 7: Company Structure & Job Architecture
-- 0038_company_structure_and_job_architecture.sql
-- ============================================================

-- 1. DEPARTMENTS
create table if not exists public.departments (
  id                  uuid primary key default uuid_generate_v4(),
  organization_id     uuid not null references public.organizations(id) on delete cascade,
  name                text not null,
  code                text,
  description         text,
  manager_id          uuid references public.profiles(id) on delete set null,
  parent_id           uuid references public.departments(id) on delete set null,
  is_active           boolean not null default true,
  display_order       integer default 0,
  created             timestamptz not null default now(),
  updated             timestamptz not null default now(),
  unique (organization_id, name)
);

create index if not exists idx_departments_organization_id on public.departments(organization_id);
create index if not exists idx_departments_parent_id on public.departments(parent_id);
create index if not exists idx_departments_manager_id on public.departments(manager_id);

-- 2. ENHANCE TEAMS & PROFILES (Relational linkages)
alter table public.teams 
  add column if not exists department_id uuid references public.departments(id) on delete set null,
  add column if not exists description text,
  add column if not exists is_active boolean not null default true;

create index if not exists idx_teams_department_id on public.teams(department_id);

alter table public.profiles
  add column if not exists department_id uuid references public.departments(id) on delete set null;

create index if not exists idx_profiles_department_id on public.profiles(department_id);

-- 3. COMPATIBILITY VIEWS (companies & employees)
create or replace view public.companies as 
  select * from public.organizations;

create or replace view public.employees as 
  select * from public.profiles;

-- 4. ROLES & PERMISSIONS (Dynamic RBAC)
create table if not exists public.roles (
  id                  uuid primary key default uuid_generate_v4(),
  organization_id     uuid references public.organizations(id) on delete cascade,
  name                text not null,
  code                text not null,
  description         text,
  is_system           boolean not null default false,
  created             timestamptz not null default now(),
  updated             timestamptz not null default now(),
  unique (organization_id, code)
);

create index if not exists idx_roles_organization_id on public.roles(organization_id);

create table if not exists public.permissions (
  id                  uuid primary key default uuid_generate_v4(),
  module              text not null,
  action              text not null,
  code                text not null unique,
  name                text not null,
  description         text,
  created             timestamptz not null default now()
);

create index if not exists idx_permissions_module on public.permissions(module);
create index if not exists idx_permissions_code on public.permissions(code);

create table if not exists public.role_permissions (
  id                  uuid primary key default uuid_generate_v4(),
  role_id             uuid not null references public.roles(id) on delete cascade,
  permission_id       uuid not null references public.permissions(id) on delete cascade,
  created             timestamptz not null default now(),
  unique (role_id, permission_id)
);

create index if not exists idx_role_permissions_role_id on public.role_permissions(role_id);
create index if not exists idx_role_permissions_permission_id on public.role_permissions(permission_id);

-- 5. JOB ARCHITECTURE
-- 5a. Job Roles
create table if not exists public.job_roles (
  id                  uuid primary key default uuid_generate_v4(),
  organization_id     uuid not null references public.organizations(id) on delete cascade,
  department_id       uuid references public.departments(id) on delete set null,
  title               text not null,
  role_code           text,
  career_level        text default 'Mid',
  employment_type     text default 'Full-time',
  reports_to_role_id  uuid references public.job_roles(id) on delete set null,
  is_active           boolean not null default true,
  created             timestamptz not null default now(),
  updated             timestamptz not null default now(),
  unique (organization_id, title)
);

create index if not exists idx_job_roles_organization_id on public.job_roles(organization_id);
create index if not exists idx_job_roles_department_id on public.job_roles(department_id);

-- 5b. Versioned Job Descriptions
create table if not exists public.job_descriptions (
  id                  uuid primary key default uuid_generate_v4(),
  job_role_id         uuid not null references public.job_roles(id) on delete cascade,
  version             integer not null default 1,
  purpose             text,
  responsibilities    jsonb default '[]'::jsonb,
  requirements        jsonb default '[]'::jsonb,
  effective_from      date not null default current_date,
  effective_to        date,
  is_current          boolean not null default true,
  status              text not null default 'ACTIVE'
                      check (status in ('DRAFT', 'ACTIVE', 'ARCHIVED')),
  created             timestamptz not null default now(),
  updated             timestamptz not null default now(),
  unique (job_role_id, version)
);

create index if not exists idx_job_descriptions_role_id on public.job_descriptions(job_role_id);

-- 5c. Skills Matrix Catalog
create table if not exists public.skills (
  id                  uuid primary key default uuid_generate_v4(),
  organization_id     uuid not null references public.organizations(id) on delete cascade,
  name                text not null,
  category            text not null default 'Technical',
  description         text,
  is_active           boolean not null default true,
  created             timestamptz not null default now(),
  updated             timestamptz not null default now(),
  unique (organization_id, name)
);

create index if not exists idx_skills_organization_id on public.skills(organization_id);

-- 5d. Competencies
create table if not exists public.competencies (
  id                  uuid primary key default uuid_generate_v4(),
  organization_id     uuid not null references public.organizations(id) on delete cascade,
  name                text not null,
  description         text,
  behaviors           jsonb default '[]'::jsonb,
  is_active           boolean not null default true,
  created             timestamptz not null default now(),
  updated             timestamptz not null default now(),
  unique (organization_id, name)
);

create index if not exists idx_competencies_organization_id on public.competencies(organization_id);

-- 5e. KPIs
create table if not exists public.kpis (
  id                  uuid primary key default uuid_generate_v4(),
  organization_id     uuid not null references public.organizations(id) on delete cascade,
  job_role_id         uuid references public.job_roles(id) on delete set null,
  name                text not null,
  description         text,
  metric_unit         text,
  target_value        text,
  frequency           text default 'Quarterly',
  is_active           boolean not null default true,
  created             timestamptz not null default now(),
  updated             timestamptz not null default now()
);

create index if not exists idx_kpis_organization_id on public.kpis(organization_id);
create index if not exists idx_kpis_job_role_id on public.kpis(job_role_id);

-- 5f. Job Role <-> Skill Requirements
create table if not exists public.job_role_skills (
  id                  uuid primary key default uuid_generate_v4(),
  job_role_id         uuid not null references public.job_roles(id) on delete cascade,
  skill_id            uuid not null references public.skills(id) on delete cascade,
  required_level      integer not null default 3 check (required_level between 1 and 5),
  is_mandatory        boolean not null default true,
  created             timestamptz not null default now(),
  unique (job_role_id, skill_id)
);

create index if not exists idx_jrs_job_role_id on public.job_role_skills(job_role_id);
create index if not exists idx_jrs_skill_id on public.job_role_skills(skill_id);

-- 5g. Job Role <-> Competency Requirements
create table if not exists public.job_role_competencies (
  id                  uuid primary key default uuid_generate_v4(),
  job_role_id         uuid not null references public.job_roles(id) on delete cascade,
  competency_id       uuid not null references public.competencies(id) on delete cascade,
  expected_level      integer not null default 3 check (expected_level between 1 and 5),
  created             timestamptz not null default now(),
  unique (job_role_id, competency_id)
);

create index if not exists idx_jrc_job_role_id on public.job_role_competencies(job_role_id);

-- 5h. Employee Job Assignments (Historical Role Tracking)
create table if not exists public.employee_job_assignments (
  id                  uuid primary key default uuid_generate_v4(),
  employee_id         uuid not null references public.profiles(id) on delete cascade,
  job_role_id         uuid not null references public.job_roles(id) on delete cascade,
  job_description_id  uuid references public.job_descriptions(id) on delete set null,
  start_date          date not null default current_date,
  end_date            date,
  is_primary          boolean not null default true,
  created             timestamptz not null default now(),
  updated             timestamptz not null default now()
);

create index if not exists idx_eja_employee_id on public.employee_job_assignments(employee_id);
create index if not exists idx_eja_job_role_id on public.employee_job_assignments(job_role_id);

-- 5i. Employee Assessed Skills
create table if not exists public.employee_skills (
  id                  uuid primary key default uuid_generate_v4(),
  employee_id         uuid not null references public.profiles(id) on delete cascade,
  skill_id            uuid not null references public.skills(id) on delete cascade,
  self_rating         integer check (self_rating between 1 and 5),
  manager_rating      integer check (manager_rating between 1 and 5),
  verified_by         uuid references public.profiles(id) on delete set null,
  verified_at         timestamptz,
  created             timestamptz not null default now(),
  updated             timestamptz not null default now(),
  unique (employee_id, skill_id)
);

create index if not exists idx_es_employee_id on public.employee_skills(employee_id);
create index if not exists idx_es_skill_id on public.employee_skills(skill_id);

-- 6. AUTO-UPDATE TIMESTAMPS
do $$
declare tbl text;
begin
  foreach tbl in array array[
    'departments', 'roles', 'job_roles', 'job_descriptions', 
    'skills', 'competencies', 'kpis', 'employee_job_assignments', 'employee_skills'
  ]
  loop
    execute format(
      'create trigger trg_%I_updated_at before update on public.%I for each row execute function public.set_updated_at()',
      tbl, tbl
    );
  end loop;
exception when others then null;
end;
$$;

-- 7. ROW LEVEL SECURITY POLICIES

-- 7a. Departments
alter table public.departments enable row level security;

create policy "departments_select" on public.departments for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "departments_insert" on public.departments for insert with check (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);
create policy "departments_update" on public.departments for update using (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);
create policy "departments_delete" on public.departments for delete using (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);

-- 7b. Roles
alter table public.roles enable row level security;

create policy "roles_select" on public.roles for select using (
  public.is_super_admin() or organization_id = public.auth_org_id() or organization_id is null
);
create policy "roles_insert" on public.roles for insert with check (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);
create policy "roles_update" on public.roles for update using (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR') and not is_system)
);
create policy "roles_delete" on public.roles for delete using (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR') and not is_system)
);

-- 7c. Permissions (read-only for all authenticated, manageable by super admin)
alter table public.permissions enable row level security;

create policy "permissions_select" on public.permissions for select using (true);
create policy "permissions_modify" on public.permissions for all using (public.is_super_admin());

-- 7d. Role Permissions
alter table public.role_permissions enable row level security;

create policy "role_permissions_select" on public.role_permissions for select using (
  public.is_super_admin() or exists (
    select 1 from public.roles r 
    where r.id = role_permissions.role_id 
      and (r.organization_id = public.auth_org_id() or r.organization_id is null)
  )
);
create policy "role_permissions_modify" on public.role_permissions for all using (
  public.is_super_admin() or (public.auth_role() in ('ADMIN','HR'))
);

-- 7e. Job Architecture RLS
alter table public.job_roles enable row level security;
create policy "job_roles_select" on public.job_roles for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "job_roles_modify" on public.job_roles for all using (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);

alter table public.job_descriptions enable row level security;
create policy "job_descriptions_select" on public.job_descriptions for select using (
  public.is_super_admin() or exists (
    select 1 from public.job_roles jr 
    where jr.id = job_descriptions.job_role_id and jr.organization_id = public.auth_org_id()
  )
);
create policy "job_descriptions_modify" on public.job_descriptions for all using (
  public.is_super_admin() or (public.auth_role() in ('ADMIN','HR'))
);

alter table public.skills enable row level security;
create policy "skills_select" on public.skills for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "skills_modify" on public.skills for all using (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);

alter table public.competencies enable row level security;
create policy "competencies_select" on public.competencies for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "competencies_modify" on public.competencies for all using (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);

alter table public.kpis enable row level security;
create policy "kpis_select" on public.kpis for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
create policy "kpis_modify" on public.kpis for all using (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);

alter table public.job_role_skills enable row level security;
create policy "job_role_skills_select" on public.job_role_skills for select using (
  public.is_super_admin() or exists (
    select 1 from public.job_roles jr where jr.id = job_role_skills.job_role_id and jr.organization_id = public.auth_org_id()
  )
);
create policy "job_role_skills_modify" on public.job_role_skills for all using (
  public.is_super_admin() or (public.auth_role() in ('ADMIN','HR'))
);

alter table public.job_role_competencies enable row level security;
create policy "job_role_competencies_select" on public.job_role_competencies for select using (
  public.is_super_admin() or exists (
    select 1 from public.job_roles jr where jr.id = job_role_competencies.job_role_id and jr.organization_id = public.auth_org_id()
  )
);
create policy "job_role_competencies_modify" on public.job_role_competencies for all using (
  public.is_super_admin() or (public.auth_role() in ('ADMIN','HR'))
);

alter table public.employee_job_assignments enable row level security;
create policy "eja_select" on public.employee_job_assignments for select using (
  public.is_super_admin() or exists (
    select 1 from public.profiles p where p.id = employee_job_assignments.employee_id and p.organization_id = public.auth_org_id()
  )
);
create policy "eja_modify" on public.employee_job_assignments for all using (
  public.is_super_admin() or (public.auth_role() in ('ADMIN','HR'))
);

alter table public.employee_skills enable row level security;
create policy "employee_skills_select" on public.employee_skills for select using (
  public.is_super_admin() or exists (
    select 1 from public.profiles p where p.id = employee_skills.employee_id and p.organization_id = public.auth_org_id()
  )
);
create policy "employee_skills_insert" on public.employee_skills for insert with check (
  public.is_super_admin() or employee_id = auth.uid() or public.auth_role() in ('ADMIN','HR','MANAGER')
);
create policy "employee_skills_update" on public.employee_skills for update using (
  public.is_super_admin() or employee_id = auth.uid() or public.auth_role() in ('ADMIN','HR','MANAGER')
);
create policy "employee_skills_delete" on public.employee_skills for delete using (
  public.is_super_admin() or public.auth_role() in ('ADMIN','HR')
);

-- 8. SEED STANDARD PERMISSIONS
insert into public.permissions (module, action, code, name, description) values
  ('company', 'view', 'company:view', 'View Company Profile', 'Can view company information and settings'),
  ('company', 'manage', 'company:manage', 'Manage Company Profile', 'Can update company name, address, settings'),
  ('department', 'view', 'department:view', 'View Departments', 'Can view organizational departments'),
  ('department', 'manage', 'department:manage', 'Manage Departments', 'Can create, edit and delete departments'),
  ('team', 'view', 'team:view', 'View Teams', 'Can view organizational teams and members'),
  ('team', 'manage', 'team:manage', 'Manage Teams', 'Can create, edit and delete teams'),
  ('employee', 'view', 'employee:view', 'View Employees', 'Can view employee directory'),
  ('employee', 'manage', 'employee:manage', 'Manage Employees', 'Can create, update, offboard employees'),
  ('job_role', 'view', 'job_role:view', 'View Job Roles', 'Can view job architecture and descriptions'),
  ('job_role', 'manage', 'job_role:manage', 'Manage Job Roles', 'Can create, edit job roles and descriptions'),
  ('skill', 'view', 'skill:view', 'View Skills Matrix', 'Can view skills matrix and gap analysis'),
  ('skill', 'assess', 'skill:assess', 'Assess Skills', 'Can self-rate or manager-verify skills'),
  ('skill', 'manage', 'skill:manage', 'Manage Skills', 'Can create and configure catalog skills'),
  ('attendance', 'punch', 'attendance:punch', 'Punch Attendance', 'Can punch in and out for daily work'),
  ('attendance', 'view_all', 'attendance:view_all', 'View All Attendance', 'Can audit organization-wide attendance'),
  ('attendance', 'adjust', 'attendance:adjust', 'Adjust Attendance', 'Can correct attendance records'),
  ('leave', 'apply', 'leave:apply', 'Apply For Leave', 'Can submit leave requests'),
  ('leave', 'approve_manager', 'leave:approve_manager', 'Manager Leave Approval', 'Can approve team member leave requests'),
  ('leave', 'approve_hr', 'leave:approve_hr', 'HR Leave Approval', 'Can give final HR approval on leave requests'),
  ('task', 'view', 'task:view', 'View Tasks & Projects', 'Can view project boards and tasks'),
  ('task', 'manage', 'task:manage', 'Manage Tasks & Projects', 'Can create and assign tasks and projects'),
  ('performance', 'review', 'performance:review', 'Conduct Reviews', 'Can submit reviews and ratings'),
  ('performance', 'finalize', 'performance:finalize', 'Finalize Reviews', 'Can finalize performance review cycles'),
  ('reports', 'view', 'reports:view', 'View Reports', 'Can view and export analytics reports')
on conflict (code) do nothing;
