import fs from 'fs';
import path from 'path';

const migrationsDir = 'supabase/migrations';
const files = fs.readdirSync(migrationsDir).filter(f => f.endsWith('.sql')).sort();

let totalSql = `-- ============================================================
-- OpenHRApp / Company OS — Complete Consolidated Database Setup
-- Idempotent & Fault-Tolerant: Safe to run on fresh or partially migrated DB
-- Contains all migrations (0001 through 0038)
-- ============================================================

`;

for (const f of files) {
  let content = fs.readFileSync(path.join(migrationsDir, f), 'utf8');

  // 1. Ensure create table if not exists
  content = content.replace(/create table (?!if not exists )/gi, 'create table if not exists ');

  // 2. Ensure create index if not exists
  content = content.replace(/create index (?!if not exists )/gi, 'create index if not exists ');
  content = content.replace(/create unique index (?!if not exists )/gi, 'create unique index if not exists ');

  // 3. Make constraints in 0001 idempotent
  content = content.replace(
    /alter table public\.profiles\s+add constraint fk_profiles_team_id foreign key \(team_id\) references public\.teams\(id\) on delete set null;/gi,
    () => `do $$ begin alter table public.profiles add constraint fk_profiles_team_id foreign key (team_id) references public.teams(id) on delete set null; exception when duplicate_object then null; end $$;`
  );
  content = content.replace(
    /alter table public\.profiles\s+add constraint fk_profiles_shift_id foreign key \(shift_id\) references public\.shifts\(id\) on delete set null;/gi,
    () => `do $$ begin alter table public.profiles add constraint fk_profiles_shift_id foreign key (shift_id) references public.shifts(id) on delete set null; exception when duplicate_object then null; end $$;`
  );

  // 4. Ensure triggers have drop trigger if exists beforehand
  content = content.replace(
    /(?<!drop trigger if exists [^\n]+\n)create trigger\s+([a-zA-Z0-9_]+)\s+([a-zA-Z\s]+)\s+on\s+([^\s;]+)/gi,
    (match, trgName, timing, tableName) => {
      return `drop trigger if exists ${trgName} on ${tableName};\ncreate trigger ${trgName} ${timing} on ${tableName}`;
    }
  );

  // 5. Ensure create policy has drop policy if exists beforehand if not already preceded by drop policy
  content = content.replace(
    /(?:drop policy if exists\s+"?[^"]+"?\s+on\s+[^;]+;\s*)*create policy\s+"?([a-zA-Z0-9_]+)"?\s+on\s+([^\s]+)\s+for\s+([^\s]+)/gi,
    (match, polName, tableName, polAction) => {
      return `drop policy if exists "${polName}" on ${tableName};\ncreate policy "${polName}" on ${tableName} for ${polAction}`;
    }
  );

  // 6. Double check: fix any remaining text = uuid comparisons
  content = content.replace(/employee_id = auth\.uid\(\)(?!::text)/g, 'employee_id = auth.uid()::text');

  totalSql += `-- ------------------------------------------------------------\n`;
  totalSql += `-- Migration: ${f}\n`;
  totalSql += `-- ------------------------------------------------------------\n\n`;
  totalSql += content.trim() + '\n\n';
}

fs.writeFileSync('scripts/setup-complete-company-os-database.sql', totalSql);
console.log(`Successfully generated scripts/setup-complete-company-os-database.sql (${totalSql.length} characters)`);

// Validation: verify no single $ delimiters in DO blocks
const singleDollarMatches = totalSql.match(/\bdo\s+\$(?!\$)/g) || [];
const singleDollarEndMatches = totalSql.match(/\bend\s+\$(?!\$);/g) || [];
if (singleDollarMatches.length > 0 || singleDollarEndMatches.length > 0) {
  console.error(`WARNING: Found unescaped dollar blocks: do=${singleDollarMatches.length}, end=${singleDollarEndMatches.length}`);
} else {
  console.log('Verification PASSED: All DO block dollar signs are properly doubled ($$).');
}
