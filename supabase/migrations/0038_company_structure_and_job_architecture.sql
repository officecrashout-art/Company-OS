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

drop policy if exists "departments_select" on public.departments;
create policy "departments_select" on public.departments for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
drop policy if exists "departments_insert" on public.departments;
create policy "departments_insert" on public.departments for insert with check (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);
drop policy if exists "departments_update" on public.departments;
create policy "departments_update" on public.departments for update using (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);
drop policy if exists "departments_delete" on public.departments;
create policy "departments_delete" on public.departments for delete using (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);

-- 7b. Roles
alter table public.roles enable row level security;

drop policy if exists "roles_select" on public.roles;
create policy "roles_select" on public.roles for select using (
  public.is_super_admin() or organization_id = public.auth_org_id() or organization_id is null
);
drop policy if exists "roles_insert" on public.roles;
create policy "roles_insert" on public.roles for insert with check (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);
drop policy if exists "roles_update" on public.roles;
create policy "roles_update" on public.roles for update using (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR') and not is_system)
);
drop policy if exists "roles_delete" on public.roles;
create policy "roles_delete" on public.roles for delete using (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR') and not is_system)
);

-- 7c. Permissions (read-only for all authenticated, manageable by super admin)
alter table public.permissions enable row level security;

drop policy if exists "permissions_select" on public.permissions;
create policy "permissions_select" on public.permissions for select using (true);
drop policy if exists "permissions_modify" on public.permissions;
create policy "permissions_modify" on public.permissions for all using (public.is_super_admin());

-- 7d. Role Permissions
alter table public.role_permissions enable row level security;

drop policy if exists "role_permissions_select" on public.role_permissions;
create policy "role_permissions_select" on public.role_permissions for select using (
  public.is_super_admin() or exists (
    select 1 from public.roles r 
    where r.id = role_permissions.role_id 
      and (r.organization_id = public.auth_org_id() or r.organization_id is null)
  )
);
drop policy if exists "role_permissions_modify" on public.role_permissions;
create policy "role_permissions_modify" on public.role_permissions for all using (
  public.is_super_admin() or (public.auth_role() in ('ADMIN','HR'))
);

-- 7e. Job Architecture RLS
alter table public.job_roles enable row level security;
drop policy if exists "job_roles_select" on public.job_roles;
create policy "job_roles_select" on public.job_roles for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
drop policy if exists "job_roles_modify" on public.job_roles;
create policy "job_roles_modify" on public.job_roles for all using (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);

alter table public.job_descriptions enable row level security;
drop policy if exists "job_descriptions_select" on public.job_descriptions;
create policy "job_descriptions_select" on public.job_descriptions for select using (
  public.is_super_admin() or exists (
    select 1 from public.job_roles jr 
    where jr.id = job_descriptions.job_role_id and jr.organization_id = public.auth_org_id()
  )
);
drop policy if exists "job_descriptions_modify" on public.job_descriptions;
create policy "job_descriptions_modify" on public.job_descriptions for all using (
  public.is_super_admin() or (public.auth_role() in ('ADMIN','HR'))
);

alter table public.skills enable row level security;
drop policy if exists "skills_select" on public.skills;
create policy "skills_select" on public.skills for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
drop policy if exists "skills_modify" on public.skills;
create policy "skills_modify" on public.skills for all using (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);

alter table public.competencies enable row level security;
drop policy if exists "competencies_select" on public.competencies;
create policy "competencies_select" on public.competencies for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
drop policy if exists "competencies_modify" on public.competencies;
create policy "competencies_modify" on public.competencies for all using (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);

alter table public.kpis enable row level security;
drop policy if exists "kpis_select" on public.kpis;
create policy "kpis_select" on public.kpis for select using (
  public.is_super_admin() or organization_id = public.auth_org_id()
);
drop policy if exists "kpis_modify" on public.kpis;
create policy "kpis_modify" on public.kpis for all using (
  public.is_super_admin() or (organization_id = public.auth_org_id() and public.auth_role() in ('ADMIN','HR'))
);

alter table public.job_role_skills enable row level security;
drop policy if exists "job_role_skills_select" on public.job_role_skills;
create policy "job_role_skills_select" on public.job_role_skills for select using (
  public.is_super_admin() or exists (
    select 1 from public.job_roles jr where jr.id = job_role_skills.job_role_id and jr.organization_id = public.auth_org_id()
  )
);
drop policy if exists "job_role_skills_modify" on public.job_role_skills;
create policy "job_role_skills_modify" on public.job_role_skills for all using (
  public.is_super_admin() or (public.auth_role() in ('ADMIN','HR'))
);

alter table public.job_role_competencies enable row level security;
drop policy if exists "job_role_competencies_select" on public.job_role_competencies;
create policy "job_role_competencies_select" on public.job_role_competencies for select using (
  public.is_super_admin() or exists (
    select 1 from public.job_roles jr where jr.id = job_role_competencies.job_role_id and jr.organization_id = public.auth_org_id()
  )
);
drop policy if exists "job_role_competencies_modify" on public.job_role_competencies;
create policy "job_role_competencies_modify" on public.job_role_competencies for all using (
  public.is_super_admin() or (public.auth_role() in ('ADMIN','HR'))
);

alter table public.employee_job_assignments enable row level security;
drop policy if exists "eja_select" on public.employee_job_assignments;
create policy "eja_select" on public.employee_job_assignments for select using (
  public.is_super_admin() or exists (
    select 1 from public.profiles p where p.id::text = employee_job_assignments.employee_id::text and p.organization_id = public.auth_org_id()
  )
);
drop policy if exists "eja_modify" on public.employee_job_assignments;
create policy "eja_modify" on public.employee_job_assignments for all using (
  public.is_super_admin() or (public.auth_role() in ('ADMIN','HR'))
);

alter table public.employee_skills enable row level security;
drop policy if exists "employee_skills_select" on public.employee_skills;
create policy "employee_skills_select" on public.employee_skills for select using (
  public.is_super_admin() or exists (
    select 1 from public.profiles p where p.id::text = employee_skills.employee_id::text and p.organization_id = public.auth_org_id()
  )
);
drop policy if exists "employee_skills_insert" on public.employee_skills;
create policy "employee_skills_insert" on public.employee_skills for insert with check (
  public.is_super_admin() or employee_id::text = auth.uid()::text or public.auth_role() in ('ADMIN','HR','MANAGER')
);
drop policy if exists "employee_skills_update" on public.employee_skills;
create policy "employee_skills_update" on public.employee_skills for update using (
  public.is_super_admin() or employee_id::text = auth.uid()::text or public.auth_role() in ('ADMIN','HR','MANAGER')
);
drop policy if exists "employee_skills_delete" on public.employee_skills;
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
