# COMPANY OS --- MASTER PROJECT CONTEXT

## Scalable HR, Work Management, Attendance & Performance Platform

**Prepared by:** Talha Jalal\
**Project Name:** Company OS\
**Foundation:** OpenHRApp\
**Primary Attendance Device:** ZKTeco MB460\
**Architecture Goal:** Scalable production system\
**Status:** Master development specification

------------------------------------------------------------------------

# 1. PROJECT PURPOSE

Company OS is a unified internal business platform that extends
OpenHRApp into a complete **HR Management + Work Management +
Attendance + Performance + Company Operations System**.

The platform must work well for a small organization today while being
architected so that the company can scale substantially without
requiring a major rewrite.

The system should unify:

-   Employee and HR management
-   Job Roles and Job Descriptions
-   Organization and team structure
-   Attendance
-   ZKTeco MB460 integration
-   Multiple attendance devices
-   Shifts and attendance rules
-   Leave management
-   Tasks and projects
-   WIP / Kanban
-   Employee self-service
-   Skills
-   Goals
-   Self-assessment
-   Manager assessment
-   Performance reviews
-   Notifications
-   Company announcements
-   Documents
-   Dashboards
-   Reports
-   Audit logs
-   Administration
-   PWA/mobile workflows
-   Future AI assistance

The product should feel like a modern internal **Company OS**, not an
outdated standalone HRMS.

------------------------------------------------------------------------

# 2. PRODUCT VISION

The core relationship of the platform is:

**PEOPLE → JOB ROLES → WORK → RESULTS → PERFORMANCE**

Supported by:

**ATTENDANCE → HR OPERATIONS → MANAGEMENT → ANALYTICS**

The platform should answer:

### Employee

-   What is my role?
-   What am I responsible for?
-   What tasks do I have?
-   What is my current WIP?
-   What are my goals?
-   What skills do I need?
-   What is my attendance?
-   What leave do I have?
-   What do I need to submit for performance review?

### Manager / Team Lead

-   Who is on my team?
-   What is everyone working on?
-   What is blocked?
-   What is overdue?
-   Who has too much WIP?
-   What are the team's goals?
-   How are team members progressing?
-   What needs review?

### HR

-   Who works here?
-   What role does each employee have?
-   What is their attendance?
-   What leave do they have?
-   What documents and records exist?
-   What skills and development needs exist?
-   What performance reviews are due?

### Admin / Leadership

-   What is happening across the company?
-   What teams exist?
-   What work is progressing?
-   What attendance issues exist?
-   What projects are active?
-   What goals are being achieved?
-   Where are operational bottlenecks?

------------------------------------------------------------------------

# 3. CORE DESIGN PRINCIPLE

## EXTEND + REFACTOR + INTEGRATE

Do not unnecessarily rebuild OpenHRApp.

Before changing anything:

1.  Inspect the entire repository.
2.  Inspect the complete `assets/` folder.
3.  Inspect database schema.
4.  Inspect migrations.
5.  Inspect RLS policies.
6.  Inspect authentication.
7.  Inspect routes.
8.  Inspect components.
9.  Inspect edge functions.
10. Inspect notifications.
11. Inspect reports.
12. Inspect PWA/mobile behavior.
13. Identify reusable existing functionality.
14. Identify technical debt.
15. Identify conflicts with the new architecture.

Only then plan modifications.

------------------------------------------------------------------------

# 4. NON-NEGOTIABLE RULES

Do NOT:

-   Rewrite working functionality without a reason.
-   Delete useful existing functionality.
-   Replace the database blindly.
-   Add unnecessary dependencies.
-   Put attendance-device communication directly in the browser.
-   Expose Supabase service-role keys to the frontend.
-   Trust frontend permissions as the security boundary.
-   Destroy raw attendance events.
-   Invent undocumented ZKTeco protocols.
-   Create arbitrary employee productivity scores.
-   Use attendance as a punishment mechanism.
-   Add invasive monitoring.
-   Automatically make employment decisions using AI.
-   Hardcode company IDs, employee IDs, secrets or configuration.
-   Introduce AI before the core system is stable.
-   Design only for today's employee count.

------------------------------------------------------------------------

# 5. SCALABILITY REQUIREMENT

The original system may begin with approximately 11 employees, but the
architecture must support growth.

The system should be designed so the company can grow from:

**10 → 50 → 100 → 500+ employees**

without redesigning the entire platform.

This does NOT mean overengineering the system like a massive enterprise
ERP.

It means:

-   Proper relational modeling
-   Organization-aware data
-   Flexible roles
-   Scalable permissions
-   Multiple departments
-   Multiple teams
-   Multiple managers
-   Multiple attendance devices
-   Device-to-employee mapping
-   Background synchronization
-   Reliable queues/retries
-   Indexed database queries
-   Pagination
-   Search/filtering
-   Audit history
-   Versioned job descriptions
-   Historical organizational relationships
-   Modular services
-   Secure API boundaries

------------------------------------------------------------------------

# 6. TECHNOLOGY STACK

## Frontend

-   React
-   TypeScript
-   Tailwind CSS
-   Modern responsive UI
-   PWA support

## Backend

-   Supabase
-   PostgreSQL
-   Supabase Auth
-   Supabase Storage
-   Supabase Edge Functions where appropriate
-   Server-side validation
-   Row Level Security

## Attendance Integration

Primary device:

**ZKTeco MB460**

Communication architecture:

**MB460 → Local Attendance Connector → Secure API → Supabase → Company
OS**

The browser must NOT communicate directly with the attendance machine.

------------------------------------------------------------------------

# 7. ZKTECO MB460 INTEGRATION

## 7.1 Primary Attendance Hardware

The system is designed to integrate with:

**ZKTeco MB460**

The MB460 supports network communication suitable for integration and
attendance transaction retrieval.

However, the exact firmware, enabled communication modes and supported
protocol must be verified against the actual deployed device.

Never assume undocumented protocol behavior.

------------------------------------------------------------------------

# 8. ATTENDANCE ARCHITECTURE

## Recommended architecture

``` text
                    ┌─────────────────────────┐
                    │       Company OS        │
                    │ React + Supabase        │
                    └────────────┬────────────┘
                                 │ HTTPS
                                 ▼
                    ┌─────────────────────────┐
                    │ Attendance API / Queue  │
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │ Local Attendance        │
                    │ Connector Service       │
                    └────────────┬────────────┘
                                 │ LAN / TCP/IP
                                 ▼
                    ┌─────────────────────────┐
                    │ ZKTeco MB460             │
                    └─────────────────────────┘
```

The connector is responsible for:

-   Device communication
-   Device discovery/configuration
-   Reading transactions
-   User/device mapping
-   Deduplication
-   Queueing
-   Retry handling
-   Connection monitoring
-   Sync status
-   Error reporting
-   Secure upload to Company OS
-   Device health reporting

------------------------------------------------------------------------

# 9. MULTI-DEVICE SCALABILITY

The architecture MUST NOT assume that the company will always have one
MB460.

Instead, create a device abstraction.

Example:

``` text
Company
 ├── Device 01 — MB460 — Head Office
 ├── Device 02 — MB460 — Branch Office
 ├── Device 03 — MB460 — Factory
 └── Device 04 — Future Device
```

Each device should have:

-   Device ID
-   Device name
-   Device type
-   Model
-   Serial number
-   Location
-   IP address
-   Port
-   Connection status
-   Last successful sync
-   Last heartbeat
-   Enabled/disabled status
-   Timezone
-   Configuration metadata
-   Connector status

The system should eventually allow different supported ZKTeco devices
without redesigning the attendance database.

------------------------------------------------------------------------

# 10. LOCAL ATTENDANCE CONNECTOR

The local connector is a small service installed on a company-controlled
computer/server.

Responsibilities:

1.  Connect to configured attendance devices.
2.  Authenticate using the required device communication method.
3.  Retrieve attendance transactions.
4.  Detect duplicates.
5.  Map device users to Company OS employees.
6.  Queue unsynchronized events.
7.  Retry failed synchronization.
8.  Upload events securely.
9.  Report device health.
10. Maintain sync logs.

The connector should continue operating safely during temporary internet
outages.

Example:

``` text
MB460
  ↓
Connector receives event
  ↓
Local queue
  ↓
Internet unavailable
  ↓
Event remains queued
  ↓
Internet restored
  ↓
Event uploaded
  ↓
Server deduplicates
  ↓
Raw event stored
```

------------------------------------------------------------------------

# 11. RAW ATTENDANCE DATA

Raw attendance events are immutable source records.

Example:

``` text
attendance_raw_events

id
organization_id
device_id
device_user_id
employee_id
event_timestamp
event_type
verification_method
source
received_at
external_event_id
raw_payload
created_at
```

Never silently overwrite or delete the original event.

This provides:

-   Auditability
-   Troubleshooting
-   Recalculation
-   Device reconciliation
-   Historical accuracy

------------------------------------------------------------------------

# 12. CALCULATED ATTENDANCE

Raw events should be transformed into attendance sessions.

Example:

``` text
attendance_sessions

id
organization_id
employee_id
work_date
check_in
check_out
status
late_minutes
early_leave_minutes
worked_minutes
overtime_minutes
shift_id
calculation_version
created_at
updated_at
```

The system should be able to recalculate derived attendance without
destroying source events.

------------------------------------------------------------------------

# 13. ATTENDANCE FEATURES

Support:

-   Check-in
-   Check-out
-   Present
-   Absent
-   Late
-   Early departure
-   Half-day
-   Overtime
-   Leave
-   Holiday
-   Missing checkout
-   Manual correction
-   HR adjustment
-   Attendance notes
-   Audit trail
-   Daily attendance
-   Monthly attendance
-   Team attendance
-   Company attendance
-   Attendance reports

------------------------------------------------------------------------

# 14. SHIFTS & ATTENDANCE RULES

Support configurable:

-   Shift start
-   Shift end
-   Grace period
-   Breaks
-   Weekends
-   Holidays
-   Overtime
-   Late thresholds
-   Early departure rules
-   Missing checkout handling
-   Half-day rules
-   Multiple shifts
-   Employee-specific shift assignment
-   Team-specific shift assignment

Do not hardcode company attendance rules.

------------------------------------------------------------------------

# 15. JOB ARCHITECTURE / JOB DESCRIPTION

Job Description is a first-class system module.

Structure:

``` text
Company
  ↓
Department
  ↓
Team
  ↓
Job Role
  ↓
Job Description
  ↓
Employee Assignment
```

A Job Role should include:

-   Job title
-   Internal role name
-   Department
-   Team
-   Reports-to
-   Career level
-   Employment type
-   Role purpose
-   Responsibilities
-   Required qualifications
-   Preferred qualifications
-   Required skills
-   Preferred skills
-   Experience requirements
-   Competencies
-   KPIs
-   Expected outcomes
-   Development expectations
-   Effective date
-   Version
-   Status

------------------------------------------------------------------------

# 16. VERSIONED JOB DESCRIPTIONS

Job descriptions must support versioning.

Example:

``` text
Software Engineer
Version 1
Effective: Jan 2026

Software Engineer
Version 2
Effective: Aug 2026
```

Historical employee assignments should continue referencing the
appropriate role/version.

This prevents changes to a current JD from rewriting historical
expectations.

------------------------------------------------------------------------

# 17. JOB ROLE → SKILLS

Required job skills should connect directly to the Skills Matrix.

Example:

``` text
Job Role: Frontend Developer

Required Skills:
- JavaScript — Level 3+
- React — Level 3+
- TypeScript — Level 2+
- Git — Level 2+
```

The system can then compare:

``` text
Required Skill Level
        ↓
Employee Skill Level
        ↓
Skill Gap
        ↓
Development Goal
```

------------------------------------------------------------------------

# 18. JOB ROLE → KPIs

Each role may have measurable KPIs.

Examples:

-   Task completion quality
-   Delivery reliability
-   Project contribution
-   Customer response time
-   Defect rate
-   Goal achievement
-   Role-specific operational indicators

KPIs must be configurable by role.

Avoid creating a universal productivity score.

------------------------------------------------------------------------

# 19. PEOPLE / EMPLOYEE MANAGEMENT

Employee profiles should support:

### Personal

-   Name
-   Contact information
-   Address where appropriate
-   Emergency contact where appropriate
-   Profile photo

### Employment

-   Employee ID
-   Joining date
-   Department
-   Team
-   Designation
-   Job role
-   Manager
-   Team lead
-   Employment status
-   Employment type

### Professional

-   Skills
-   Certifications
-   Training
-   Experience
-   Education
-   Documents

### Attendance

-   Attendance device IDs
-   Device mappings
-   Shift
-   Attendance history

------------------------------------------------------------------------

# 20. ORGANIZATION STRUCTURE

Support:

``` text
Organization
 ├── Departments
 │    ├── Teams
 │    │    ├── Employees
 │    │    └── Team Lead
 │    └── Department Manager
 └── Leadership
```

Employees can have:

-   Department
-   Team
-   Manager
-   Team Lead
-   Job Role

Historical organizational relationships must be preserved.

------------------------------------------------------------------------

# 21. ROLES & PERMISSIONS

Roles:

### Super Admin

Full system access.

### Admin

Operational administration.

### HR

People, attendance, leave, performance and HR operations.

### Manager

Scoped access to team members and team work.

### Team Lead

Scoped team work and WIP visibility.

### Employee

Self-service access.

Permissions must be enforced through:

-   Backend
-   Supabase RLS
-   Server-side authorization
-   Role/scope validation

Frontend visibility is NOT the security boundary.

------------------------------------------------------------------------

# 22. TASK MANAGEMENT

Tasks should support:

-   Title
-   Description
-   Project
-   Department
-   Team
-   Assignee
-   Creator
-   Priority
-   Status
-   Start date
-   Due date
-   Estimated effort
-   Progress
-   Tags
-   Attachments
-   Comments
-   Subtasks
-   Work updates
-   Status history

------------------------------------------------------------------------

# 23. WIP / KANBAN

Primary workflow:

``` text
BACKLOG
   ↓
TODO
   ↓
IN PROGRESS
   ↓
REVIEW
   ↓
COMPLETED
```

Additional states:

-   BLOCKED
-   ON HOLD
-   CANCELLED

Managers should see:

-   Current WIP
-   Blocked work
-   Overdue work
-   Review queue
-   Upcoming deadlines
-   Workload distribution

WIP is a workflow metric, not an employee surveillance metric.

------------------------------------------------------------------------

# 24. PROJECT MANAGEMENT

Projects should contain:

-   Project information
-   Project owner
-   Members
-   Tasks
-   Milestones
-   Deadlines
-   Progress
-   Status
-   Files
-   Comments
-   Activity history

------------------------------------------------------------------------

# 25. WORKLOAD MANAGEMENT

Workload should consider:

-   Active tasks
-   Estimated effort
-   Due dates
-   WIP
-   Overdue work
-   Blocked work
-   Project participation

Do NOT automatically label employees as:

-   Lazy
-   Unproductive
-   Poor performers

based solely on task quantity.

------------------------------------------------------------------------

# 26. EMPLOYEE SELF-SERVICE

Employee portal:

-   My Profile
-   My Attendance
-   My Leave
-   My Tasks
-   My Projects
-   My WIP
-   My Goals
-   My Skills
-   My Performance
-   My Documents
-   Notifications
-   Company Announcements

------------------------------------------------------------------------

# 27. LEAVE MANAGEMENT

Support:

-   Leave types
-   Leave balances
-   Leave requests
-   Approval workflow
-   Manager approval
-   HR approval where required
-   Leave history
-   Leave calendar
-   Notifications
-   Holiday calendar

Leave workflows should be configurable.

------------------------------------------------------------------------

# 28. SKILLS MATRIX

Skill levels:

**1--5**

Support:

-   Employee self-rating
-   Manager verification
-   Skill history
-   Required skill level from JD
-   Current employee level
-   Skill gaps
-   Development recommendations

Example:

``` text
JD Requirement: React Level 4
Employee Level: React Level 3
Gap: 1 level
```

------------------------------------------------------------------------

# 29. GOAL MANAGEMENT

Goals may exist at:

-   Company
-   Department
-   Team
-   Employee

Each goal should contain:

-   Title
-   Description
-   Metric
-   Target
-   Due date
-   Progress
-   Status
-   Comments
-   Owner
-   Related job role
-   Related project/task where applicable

------------------------------------------------------------------------

# 30. PERFORMANCE MANAGEMENT

Workflow:

``` text
Employee
   ↓
Self Assessment
   ↓
Manager Review
   ↓
HR Review
   ↓
Finalized
```

Performance evaluation should consider:

-   Job Description
-   Responsibilities
-   Skills
-   Goals
-   Work outcomes
-   Project participation
-   Manager feedback
-   Development areas

------------------------------------------------------------------------

# 31. SELF-ASSESSMENT

Employees should be able to:

-   Start draft
-   Save draft
-   Complete questions
-   Add comments
-   Submit
-   View historical assessments

------------------------------------------------------------------------

# 32. MANAGER ASSESSMENT

Managers should be able to:

-   Review employee self-assessment
-   Evaluate role expectations
-   Evaluate goals
-   Evaluate skills
-   Add comments
-   Identify development areas
-   Submit review

------------------------------------------------------------------------

# 33. HR FINALIZATION

HR should be able to:

-   Review performance
-   Verify workflow completion
-   Finalize review
-   Preserve historical records
-   Lock finalized reviews
-   Make controlled amendments
-   Maintain audit trail

------------------------------------------------------------------------

# 34. PERFORMANCE HISTORY

Performance history should support:

-   Quarterly reviews
-   Annual reviews
-   Goals
-   Skills
-   Ratings
-   Comments
-   Development plans
-   Final status
-   Historical job role/version

------------------------------------------------------------------------

# 35. NOTIFICATIONS

Notifications should cover:

-   Task assignments
-   Task status changes
-   Comments
-   Due dates
-   Overdue work
-   Leave requests
-   Leave approvals
-   Attendance issues
-   Performance deadlines
-   Goal updates
-   Announcements
-   Administrative events

For scale, notifications should be designed so bulk notifications do not
block normal application requests.

------------------------------------------------------------------------

# 36. COMPANY ANNOUNCEMENTS

Support:

-   Company-wide announcements
-   Department announcements
-   Team announcements
-   Scheduled publishing
-   Priority
-   Attachments
-   Read/unread state

------------------------------------------------------------------------

# 37. DOCUMENT MANAGEMENT

Use Supabase Storage.

Support:

-   Employee documents
-   Company documents
-   HR documents
-   Performance documents
-   Project files

Private documents must remain private.

Use secure access policies and signed URLs where appropriate.

------------------------------------------------------------------------

# 38. AUDIT LOGGING

Audit sensitive actions:

-   Employee changes
-   Role changes
-   Permission changes
-   Attendance adjustments
-   Leave approvals
-   Performance finalization
-   Document access/actions where appropriate
-   Administrative changes
-   Job description changes
-   Organization changes

Audit records should contain:

-   Actor
-   Action
-   Entity
-   Entity ID
-   Timestamp
-   Previous state where appropriate
-   New state where appropriate
-   Metadata

------------------------------------------------------------------------

# 39. DASHBOARDS

## Company Dashboard

Show:

-   Total employees
-   Attendance overview
-   Leave overview
-   Active projects
-   WIP
-   Overdue tasks
-   Goals
-   Performance cycle status
-   Device health
-   Important alerts

## Team Dashboard

Show:

-   Team members
-   Current WIP
-   Blocked work
-   Overdue work
-   Workload
-   Goals
-   Attendance summary
-   Upcoming deadlines

## Employee Dashboard

Show:

-   Today's attendance
-   My tasks
-   My WIP
-   My goals
-   My leave
-   My skills
-   Performance status
-   Notifications

------------------------------------------------------------------------

# 40. ATTENDANCE DEVICE DASHBOARD

Administration should show:

``` text
Device
Status
Location
IP
Last Sync
Last Heartbeat
Queued Events
Total Events
Connector Status
```

Example:

``` text
MB460 — Head Office
ONLINE
Last Sync: 10 seconds ago
Queue: 0
Connector: Healthy
```

If a device stops communicating:

``` text
MB460 — Head Office
OFFLINE
Last Sync: 18 minutes ago
Status: Warning
```

------------------------------------------------------------------------

# 41. REPORTING

Reports:

-   Employee report
-   Attendance report
-   Late report
-   Overtime report
-   Leave report
-   Task report
-   WIP report
-   Project report
-   Workload report
-   Goal report
-   Skills report
-   Performance report
-   Device/sync report

Exports:

-   CSV
-   PDF

Large datasets should use pagination and server-side filtering.

------------------------------------------------------------------------

# 42. COMPANY CALENDAR

Calendar can include:

-   Holidays
-   Leave
-   Project deadlines
-   Task deadlines
-   Performance deadlines
-   Company events
-   Announcements

------------------------------------------------------------------------

# 43. DATABASE ARCHITECTURE

Conceptual entities:

## Organization

-   organizations
-   departments
-   teams
-   designations
-   employee_managers

## People

-   users
-   employees
-   employee_documents
-   employee_experiences
-   employee_training

## Job Architecture

-   job_roles
-   job_role_versions
-   job_role_responsibilities
-   job_role_skills
-   job_role_kpis
-   job_role_competencies
-   employee_job_assignments
-   career_levels

## Skills

-   skills
-   employee_skills
-   skill_assessments

## Work

-   projects
-   project_members
-   tasks
-   task_subtasks
-   task_comments
-   task_attachments
-   task_status_history
-   task_work_updates

## Attendance

-   attendance_devices
-   device_user_mappings
-   attendance_raw_events
-   attendance_sessions
-   attendance_adjustments
-   attendance_sync_logs
-   shifts
-   shift_assignments
-   holidays

## Leave

-   leave_types
-   leave_balances
-   leave_requests
-   leave_approvals

## Goals

-   goals
-   goal_updates
-   goal_comments

## Performance

-   performance_cycles
-   self_assessments
-   manager_assessments
-   performance_reviews
-   performance_history

## Platform

-   notifications
-   announcements
-   documents
-   audit_logs
-   system_settings

------------------------------------------------------------------------

# 44. MULTI-TENANT / ORGANIZATION-READY DESIGN

Even if Company OS initially serves one company, the core schema should
use an `organization_id` on organization-owned entities where
appropriate.

Example:

``` text
organizations
    ↓
departments
teams
employees
projects
tasks
devices
attendance
leave
goals
performance
```

This allows future organizational expansion without rewriting every
table.

Do not implement unnecessary enterprise multi-tenancy complexity before
it is needed, but avoid hardcoding the entire system around one company
ID.

------------------------------------------------------------------------

# 45. DATABASE PERFORMANCE

As the company scales:

Use:

-   Foreign keys
-   Appropriate indexes
-   Composite indexes for frequent filters
-   Pagination
-   Server-side search
-   Server-side filtering
-   Efficient joins
-   Query limits
-   Background processing for expensive operations

Avoid loading entire employee/task/attendance tables into the browser.

Attendance tables should be designed with high event volume in mind.

------------------------------------------------------------------------

# 46. DATA RETENTION

Raw attendance data should be retained according to company policy.

Do not delete raw events simply because attendance sessions have been
calculated.

Historical:

-   Attendance
-   Organization
-   Job roles
-   Job description versions
-   Goals
-   Skills
-   Performance reviews
-   Audit logs

must remain reconstructable.

------------------------------------------------------------------------

# 47. FAILURE HANDLING

The system must tolerate:

-   Device offline
-   Internet outage
-   Connector crash
-   Duplicate transactions
-   API timeout
-   Database temporary failure
-   Invalid employee mapping
-   Invalid device mapping
-   Partial synchronization

Use:

-   Retry
-   Queue
-   Idempotency
-   Logging
-   Monitoring
-   Dead-letter/error state where appropriate
-   Manual recovery tools

------------------------------------------------------------------------

# 48. SECURITY

Required:

-   Supabase Auth
-   Strong authentication
-   Role-based permissions
-   Row Level Security
-   Server-side authorization
-   Private storage
-   Secure API endpoints
-   No service-role keys in frontend
-   Input validation
-   Audit logging
-   Secure secrets management

Employee information must only be visible to authorized users.

------------------------------------------------------------------------

# 49. PWA / MOBILE

Prioritize mobile access for:

-   Attendance viewing
-   Leave requests
-   Task updates
-   Work updates
-   Notifications
-   Goals
-   Self-assessment
-   Employee profile

The interface should remain responsive on desktop, tablet and mobile.

------------------------------------------------------------------------

# 50. UX PRINCIPLES

The UI should be:

-   Modern
-   Professional
-   Clean
-   Fast
-   Information-dense
-   Easy to understand
-   Responsive
-   Consistent

Useful interface patterns:

-   Cards
-   Tables
-   Charts
-   Kanban
-   Timelines
-   Calendars
-   Progress bars
-   Status badges
-   Activity feeds

Avoid:

-   Old-fashioned HRMS styling
-   Excessive forms
-   Unnecessary animations
-   Clutter
-   Duplicate information
-   Hidden workflows

------------------------------------------------------------------------

# 51. NAVIGATION

Recommended navigation:

``` text
Dashboard

People
  ├── Employees
  ├── Departments
  ├── Teams
  ├── Job Roles
  ├── Job Descriptions
  └── Skills

Work
  ├── My Work
  ├── Tasks
  ├── Projects
  └── WIP / Kanban

Attendance
  ├── Overview
  ├── My Attendance
  ├── Team Attendance
  ├── Devices
  └── Rules / Shifts

Leave

Performance
  ├── Goals
  ├── Skills
  ├── Self Assessment
  ├── Manager Reviews
  └── Performance History

Reports

Company

Administration

AI — Future
```

Navigation must be role-aware.

------------------------------------------------------------------------

# 52. DEVELOPMENT PHASES

## Phase 0 --- Repository Audit

No modifications.

Inspect:

-   Repository
-   Assets
-   Database
-   Migrations
-   RLS
-   Auth
-   Routes
-   Components
-   Edge Functions
-   Notifications
-   Reports
-   PWA

Output:

**AUDIT COMPLETE --- NO FILES MODIFIED.**

------------------------------------------------------------------------

## Phase 1 --- Foundation

Implement/verify:

-   Auth
-   Employees
-   Organization
-   Departments
-   Teams
-   Roles
-   Permissions
-   RLS
-   Navigation

------------------------------------------------------------------------

## Phase 2 --- Attendance

Implement:

-   MB460 integration
-   Local connector
-   Device management
-   Raw events
-   Device mapping
-   Sync
-   Retry
-   Attendance sessions
-   Shifts
-   Rules
-   Corrections
-   Attendance dashboards

------------------------------------------------------------------------

## Phase 3 --- Work Management

Implement:

-   Projects
-   Tasks
-   Subtasks
-   Status workflow
-   Comments
-   Work updates
-   Attachments
-   WIP
-   Kanban
-   Workload

------------------------------------------------------------------------

## Phase 4 --- HR Operations

Implement:

-   Leave
-   Notifications
-   Announcements
-   Documents
-   Calendar

------------------------------------------------------------------------

## Phase 5 --- Job Architecture

Implement:

-   Job Roles
-   JD versions
-   Responsibilities
-   Required skills
-   Preferred skills
-   Competencies
-   KPIs
-   Employee job assignments
-   Career levels where useful

------------------------------------------------------------------------

## Phase 6 --- Performance

Implement:

-   Skills matrix
-   Goals
-   Self-assessment
-   Manager assessment
-   HR review
-   Finalization
-   Performance history

------------------------------------------------------------------------

## Phase 7 --- Analytics

Implement:

-   Company dashboards
-   Team dashboards
-   Employee dashboards
-   Reports
-   CSV/PDF exports
-   Audit visibility
-   Device health analytics

------------------------------------------------------------------------

## Phase 8 --- Production Hardening

Implement:

-   Responsive improvements
-   PWA
-   Performance optimization
-   Error handling
-   Empty states
-   Loading states
-   Security review
-   RLS review
-   Database index review
-   Automated tests
-   Production build verification

------------------------------------------------------------------------

## Phase 9 --- AI

Only after the platform is stable.

Possible AI capabilities:

-   Employee/work summaries
-   Project summaries
-   Meeting/action summaries
-   Goal progress summaries
-   Skill-gap suggestions
-   Performance review assistance
-   HR reporting assistance
-   Attendance anomaly explanation

AI must remain assistive.

AI must NOT:

-   Automatically terminate employees
-   Automatically punish employees
-   Automatically assign performance ratings
-   Make employment decisions
-   Replace manager/HR judgment

------------------------------------------------------------------------

# 53. TESTING

Test:

## Authentication

-   Login
-   Logout
-   Session expiry
-   Password recovery
-   Unauthorized access

## Permissions

Test every role against every protected module.

## Attendance

-   Device connection
-   Device offline
-   Duplicate events
-   Missing checkout
-   Late arrival
-   Early departure
-   Overtime
-   Leave
-   Manual correction
-   Sync retry

## Work

-   Task creation
-   Assignment
-   Status transitions
-   WIP
-   Blocked tasks
-   Overdue tasks
-   Comments
-   Attachments
-   Permissions

## Performance

-   Self-assessment
-   Manager review
-   HR finalization
-   Historical records
-   Locked reviews

## Security

-   RLS
-   API authorization
-   Storage access
-   Role escalation attempts
-   Organization boundary checks

------------------------------------------------------------------------

# 54. DEFINITION OF DONE

A feature is NOT complete merely because the UI exists.

A feature is complete only when:

-   UI exists
-   Database exists
-   Backend behavior exists
-   Permissions exist
-   RLS exists
-   Persistence works
-   History works where required
-   Loading state works
-   Error state works
-   Empty state works
-   Mobile behavior works where appropriate
-   Validation works
-   Tests exist
-   Production build succeeds

------------------------------------------------------------------------

# 55. NON-GOALS

The platform is NOT intended to become:

-   Payroll system
-   Accounting system
-   Recruitment ATS
-   Full ERP
-   Enterprise BI platform
-   Invasive employee surveillance platform

No:

-   Keylogging
-   Hidden tracking
-   Webcam monitoring
-   Screenshot surveillance
-   Browser monitoring

Employee work visibility is limited to:

-   Assigned work
-   Task progress
-   Deadlines
-   WIP
-   Workload
-   Project participation
-   Goals
-   Performance
-   Skills

------------------------------------------------------------------------

# 56. PRODUCT PRIORITY

Priority order:

1.  Authentication
2.  Employee management
3.  Organization
4.  Roles / RLS
5.  MB460 attendance integration
6.  Attendance processing
7.  Shifts / rules
8.  Tasks
9.  Projects
10. WIP / Kanban
11. Leave
12. Notifications
13. Calendar
14. Job Architecture / JD
15. Skills
16. Goals
17. Self-assessment
18. Performance
19. Reports
20. Analytics
21. Audit
22. PWA
23. AI

------------------------------------------------------------------------

# 57. SCALING STRATEGY

The company should be able to add:

### Employees

``` text
Employee 001
Employee 002
...
Employee N
```

### Departments

``` text
Engineering
Design
Marketing
Sales
HR
Operations
Finance
...
```

### Teams

``` text
Frontend
Backend
Mobile
Creative
Sales Team
Support
...
```

### Devices

``` text
MB460 — HQ
MB460 — Branch A
MB460 — Branch B
Future ZKTeco Device
```

The application should not require code changes simply because another
employee, department, team or device is added.

------------------------------------------------------------------------

# 58. FUTURE DEVICE ABSTRACTION

The attendance integration should use a device adapter/service model.

Conceptually:

``` text
Attendance Service
      │
      ├── ZKTeco Adapter
      │      ├── MB460
      │      └── Future ZKTeco Models
      │
      └── Future Device Adapters
```

This allows Company OS to support additional attendance hardware later.

The exact protocol implementation should be isolated from the
HR/attendance business logic.

------------------------------------------------------------------------

# 59. ATTENDANCE DATA FLOW

``` text
Employee
   ↓
MB460
   ↓
Attendance Transaction
   ↓
Local Connector
   ↓
Deduplication
   ↓
Queue
   ↓
Secure API
   ↓
Raw Attendance Event
   ↓
Attendance Processing
   ↓
Attendance Session
   ↓
Leave / Shift / Holiday Rules
   ↓
Attendance Status
   ↓
Dashboard / Reports
```

------------------------------------------------------------------------

# 60. JOB + WORK + PERFORMANCE DATA FLOW

``` text
Job Description
      ↓
Responsibilities
      ↓
Required Skills / KPIs
      ↓
Employee Job Assignment
      ↓
Goals
      ↓
Tasks / Projects
      ↓
WIP / Work Progress
      ↓
Results / Outcomes
      ↓
Skills Assessment
      ↓
Self Assessment
      ↓
Manager Review
      ↓
HR Review
      ↓
Performance History
```

This is the central business logic of Company OS.

------------------------------------------------------------------------

# 61. MANAGEMENT PHILOSOPHY

The system should provide evidence, not arbitrary judgment.

For example:

Instead of:

> Employee Productivity Score: 62%

show:

-   12 active tasks
-   3 overdue
-   2 blocked
-   7 completed this month
-   84% completed on time
-   2 active projects
-   1 pending review
-   Goal progress: 72%
-   Skill gap: React Level 3 → Level 4

Managers can then make informed decisions.

------------------------------------------------------------------------

# 62. AI PHILOSOPHY

AI should summarize and assist.

Example:

> "The Engineering team has 18 active tasks. Four are blocked, three are
> overdue, and two are awaiting review. The largest workload
> concentration is currently in Project X."

AI should cite underlying data where practical.

AI must not silently invent facts.

------------------------------------------------------------------------

# 63. OPERATIONAL RELIABILITY

The system must favor reliability over complexity.

Important principles:

-   Idempotent attendance ingestion
-   Retryable background work
-   Safe migrations
-   Backups
-   Auditability
-   Error logs
-   Device health monitoring
-   Database constraints
-   Server-side validation
-   Clear failure states

------------------------------------------------------------------------

# 64. MIGRATION DISCIPLINE

Every database change should:

1.  Be represented by a migration.
2.  Be reviewed.
3.  Preserve existing data.
4.  Include appropriate indexes.
5.  Include RLS policies where necessary.
6.  Avoid destructive operations unless explicitly justified.
7.  Be tested against existing functionality.

Never blindly replace the production database.

------------------------------------------------------------------------

# 65. AI CODING AGENT WORKFLOW

For every development task:

### Step 1

Read `PROJECT_CONTEXT.md`.

### Step 2

Inspect the existing implementation.

### Step 3

Understand the data flow.

### Step 4

Identify the smallest safe change.

### Step 5

Plan implementation.

### Step 6

Implement in small increments.

### Step 7

Run tests/build.

### Step 8

Review permissions and RLS.

### Step 9

Review mobile behavior.

### Step 10

Report exactly what changed.

Never modify unrelated systems.

------------------------------------------------------------------------

# 66. FIRST TASK FOR A NEW DEVELOPMENT SESSION

Before writing code:

1.  Read this entire document.
2.  Inspect the repository.
3.  Inspect database schema.
4.  Inspect migrations.
5.  Inspect RLS.
6.  Inspect authentication.
7.  Inspect the UI.
8.  Inspect routes.
9.  Inspect services.
10. Inspect attendance integration.
11. Inspect all relevant assets.
12. Identify what already exists.
13. Identify what is missing.
14. Produce a technical audit.
15. Do NOT modify files during the initial audit.

End the audit with:

**AUDIT COMPLETE --- NO FILES MODIFIED.**

------------------------------------------------------------------------

# 67. FINAL SYSTEM ARCHITECTURE

``` text
                         COMPANY OS
                              │
       ┌──────────────────────┼──────────────────────┐
       │                      │                      │
     PEOPLE                  WORK                 HR
       │                      │                      │
 Employees                Projects               Leave
 Departments              Tasks                  Documents
 Teams                    WIP                    Announcements
 Job Roles                Kanban                 Calendar
 Job Descriptions         Workload
 Skills                   Progress
       │                      │
       └──────────────┬───────┘
                      │
                 PERFORMANCE
                      │
             Goals / Skills / Reviews
                      │
                 MANAGEMENT
                      │
          Dashboards / Reports / Audit
                      │
                   ATTENDANCE
                      │
                 ZKTeco MB460
                      │
              Local Connector
                      │
                  Supabase
                      │
                 Future AI
```

------------------------------------------------------------------------

# 68. FINAL PRODUCT DEFINITION

Company OS is:

> **A scalable internal Company Operating System combining HR, Job
> Architecture, Attendance, Work Management, WIP, Employee Self-Service,
> Skills, Goals, Performance and Management Analytics in one secure
> platform.**

It should begin simple enough for the current organization but be
architected so that growth does not force a rewrite.

The **ZKTeco MB460** is the primary attendance device, connected through
a dedicated local attendance connector rather than directly through the
browser.

The most important organizational relationship is:

**People → Job Roles → Work → Results → Performance**

The most important technical relationship is:

**MB460 → Connector → Secure API → Supabase → Attendance Engine →
Company OS**

The most important development rule is:

**Understand the existing system before changing it.**

------------------------------------------------------------------------

# 69. PREPARED BY

**Talha Jalal**

**Company OS --- Master Project Context**
