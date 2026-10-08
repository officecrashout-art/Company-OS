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
-- CRON SCHEDULES (guarded if pg_cron extension is active)
-- ============================================================
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    -- NOTIFICATION CLEANUP — Daily 3 AM UTC
    perform cron.schedule(
      'notification-cleanup',
      '0 3 * * *',
      'delete from public.notifications where created < now() - interval ''30 days'';'
    );

    -- SELFIE CLEANUP — Daily 2 AM UTC
    perform cron.schedule(
      'selfie-cleanup',
      '0 2 * * *',
      'update public.attendance set selfie = null, updated = now() where date < current_date - interval ''30 days'' and selfie is not null;'
    );
  end if;
exception when others then null;
end;
$$;
