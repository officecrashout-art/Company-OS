import { supabase, isSupabaseConfigured } from './supabase';
import { apiClient, resolveOrgId } from './api.client';
import {
  JobRole,
  JobDescription,
  Skill,
  Competency,
  KPI,
  JobRoleSkill,
  JobRoleCompetency,
  EmployeeSkill,
  EmployeeJobAssignment,
} from '../types';

let cachedJobRoles: JobRole[] | null = null;
let cachedSkills: Skill[] | null = null;
let cachedCompetencies: Competency[] | null = null;
let cachedKPIs: KPI[] | null = null;
let lastCacheTime = 0;
const CACHE_TTL = 3 * 60 * 1000;

export const jobArchitectureService = {
  clearCache() {
    cachedJobRoles = null;
    cachedSkills = null;
    cachedCompetencies = null;
    cachedKPIs = null;
    lastCacheTime = 0;
  },

  // =========================================================================
  // JOB ROLES
  // =========================================================================

  async getJobRoles(departmentId?: string): Promise<JobRole[]> {
    if (cachedJobRoles && Date.now() - lastCacheTime < CACHE_TTL && !departmentId) {
      return cachedJobRoles;
    }
    if (!isSupabaseConfigured()) return [];

    const orgId = await resolveOrgId();
    try {
      let query = supabase
        .from('job_roles')
        .select(`
          *,
          department:departments!department_id(id, name),
          reports_to:job_roles!reports_to_role_id(id, title)
        `)
        .order('title', { ascending: true });

      if (orgId) {
        query = query.eq('organization_id', orgId);
      }
      if (departmentId) {
        query = query.eq('department_id', departmentId);
      }

      const { data, error } = await query;
      if (error) {
        console.warn('[JobArchitecture] job_roles query failed:', error.message);
        return [];
      }

      const roles: JobRole[] = (data || []).map((row: any) => ({
        id: row.id,
        organizationId: row.organization_id,
        departmentId: row.department_id || undefined,
        departmentName: row.department?.name || undefined,
        title: row.title,
        roleCode: row.role_code || undefined,
        careerLevel: row.career_level || 'Mid',
        employmentType: row.employment_type || 'Full-time',
        reportsToRoleId: row.reports_to_role_id || undefined,
        reportsToRoleTitle: row.reports_to?.title || undefined,
        isActive: row.is_active ?? true,
        created: row.created,
        updated: row.updated,
      }));

      if (!departmentId) {
        cachedJobRoles = roles;
        lastCacheTime = Date.now();
      }

      return roles;
    } catch (e: any) {
      console.warn('[JobArchitecture] Failed to fetch job roles:', e?.message || e);
      return [];
    }
  },

  async createJobRole(data: {
    departmentId?: string;
    title: string;
    roleCode?: string;
    careerLevel?: string;
    employmentType?: string;
    reportsToRoleId?: string;
  }): Promise<JobRole | null> {
    if (!isSupabaseConfigured()) return null;
    const orgId = await resolveOrgId();
    if (!orgId) throw new Error('No active organization found');

    const payload = {
      organization_id: orgId,
      department_id: data.departmentId || null,
      title: data.title.trim(),
      role_code: data.roleCode?.trim() || null,
      career_level: data.careerLevel || 'Mid',
      employment_type: data.employmentType || 'Full-time',
      reports_to_role_id: data.reportsToRoleId || null,
      is_active: true,
    };

    const { data: inserted, error } = await supabase
      .from('job_roles')
      .insert(payload)
      .select()
      .single();

    if (error) throw error;

    jobArchitectureService.clearCache();
    apiClient.notify();
    return inserted as JobRole;
  },

  async updateJobRole(
    id: string,
    updates: Partial<{
      departmentId: string | null;
      title: string;
      roleCode: string | null;
      careerLevel: string;
      employmentType: string;
      reportsToRoleId: string | null;
      isActive: boolean;
    }>
  ): Promise<void> {
    if (!isSupabaseConfigured()) return;

    const payload: any = {};
    if (updates.departmentId !== undefined) payload.department_id = updates.departmentId;
    if (updates.title !== undefined) payload.title = updates.title.trim();
    if (updates.roleCode !== undefined) payload.role_code = updates.roleCode?.trim() || null;
    if (updates.careerLevel !== undefined) payload.career_level = updates.careerLevel;
    if (updates.employmentType !== undefined) payload.employment_type = updates.employmentType;
    if (updates.reportsToRoleId !== undefined) payload.reports_to_role_id = updates.reportsToRoleId;
    if (updates.isActive !== undefined) payload.is_active = updates.isActive;

    const { error } = await supabase.from('job_roles').update(payload).eq('id', id);
    if (error) throw error;

    jobArchitectureService.clearCache();
    apiClient.notify();
  },

  async deleteJobRole(id: string): Promise<void> {
    if (!isSupabaseConfigured()) return;

    const { error } = await supabase.from('job_roles').delete().eq('id', id);
    if (error) throw error;

    jobArchitectureService.clearCache();
    apiClient.notify();
  },

  // =========================================================================
  // JOB DESCRIPTIONS (VERSIONED)
  // =========================================================================

  async getJobDescriptions(jobRoleId: string): Promise<JobDescription[]> {
    if (!isSupabaseConfigured()) return [];

    try {
      const { data, error } = await supabase
        .from('job_descriptions')
        .select('*')
        .eq('job_role_id', jobRoleId)
        .order('version', { ascending: false });

      if (error) {
        console.warn('[JobArchitecture] job_descriptions query failed:', error.message);
        return [];
      }

      return (data || []).map((row: any) => ({
        id: row.id,
        jobRoleId: row.job_role_id,
        version: row.version,
        purpose: row.purpose || undefined,
        responsibilities: Array.isArray(row.responsibilities) ? row.responsibilities : [],
        requirements: Array.isArray(row.requirements) ? row.requirements : [],
        effectiveFrom: row.effective_from,
        effectiveTo: row.effective_to || undefined,
        isCurrent: !!row.is_current,
        status: row.status || 'ACTIVE',
        created: row.created,
        updated: row.updated,
      }));
    } catch (e: any) {
      console.warn('[JobArchitecture] Failed to fetch job descriptions:', e?.message || e);
      return [];
    }
  },

  async getCurrentJobDescription(jobRoleId: string): Promise<JobDescription | null> {
    const list = await jobArchitectureService.getJobDescriptions(jobRoleId);
    return list.find((d) => d.isCurrent) || list[0] || null;
  },

  async createJobDescription(data: {
    jobRoleId: string;
    purpose?: string;
    responsibilities: string[];
    requirements: string[];
    status?: 'DRAFT' | 'ACTIVE' | 'ARCHIVED';
    effectiveFrom?: string;
    effectiveTo?: string;
  }): Promise<JobDescription | null> {
    if (!isSupabaseConfigured()) return null;

    // Get max existing version for this role
    const existing = await jobArchitectureService.getJobDescriptions(data.jobRoleId);
    const nextVersion = existing.length > 0 ? Math.max(...existing.map((e) => e.version)) + 1 : 1;
    const isNewActive = (data.status || 'ACTIVE') === 'ACTIVE';

    if (isNewActive) {
      // Mark previous versions as not current
      await supabase
        .from('job_descriptions')
        .update({ is_current: false })
        .eq('job_role_id', data.jobRoleId);
    }

    const payload = {
      job_role_id: data.jobRoleId,
      version: nextVersion,
      purpose: data.purpose?.trim() || null,
      responsibilities: data.responsibilities,
      requirements: data.requirements,
      status: data.status || 'ACTIVE',
      is_current: isNewActive,
      effective_from: data.effectiveFrom || new Date().toISOString().split('T')[0],
      effective_to: data.effectiveTo || null,
    };

    const { data: inserted, error } = await supabase
      .from('job_descriptions')
      .insert(payload)
      .select()
      .single();

    if (error) throw error;
    apiClient.notify();
    return inserted as JobDescription;
  },

  // =========================================================================
  // SKILLS MATRIX CATALOG
  // =========================================================================

  async getSkills(category?: string): Promise<Skill[]> {
    if (cachedSkills && Date.now() - lastCacheTime < CACHE_TTL && !category) {
      return cachedSkills;
    }
    if (!isSupabaseConfigured()) return [];

    const orgId = await resolveOrgId();
    try {
      let query = supabase
        .from('skills')
        .select('*')
        .order('category', { ascending: true })
        .order('name', { ascending: true });

      if (orgId) {
        query = query.eq('organization_id', orgId);
      }
      if (category) {
        query = query.eq('category', category);
      }

      const { data, error } = await query;
      if (error) {
        console.warn('[JobArchitecture] skills query failed:', error.message);
        return [];
      }

      const skills: Skill[] = (data || []).map((row: any) => ({
        id: row.id,
        organizationId: row.organization_id,
        name: row.name,
        category: row.category,
        description: row.description || undefined,
        isActive: row.is_active ?? true,
        created: row.created,
        updated: row.updated,
      }));

      if (!category) {
        cachedSkills = skills;
      }
      return skills;
    } catch (e: any) {
      console.warn('[JobArchitecture] Failed to fetch skills:', e?.message || e);
      return [];
    }
  },

  async createSkill(data: {
    name: string;
    category?: string;
    description?: string;
  }): Promise<Skill | null> {
    if (!isSupabaseConfigured()) return null;
    const orgId = await resolveOrgId();
    if (!orgId) throw new Error('No active organization found');

    const payload = {
      organization_id: orgId,
      name: data.name.trim(),
      category: data.category?.trim() || 'Technical',
      description: data.description?.trim() || null,
      is_active: true,
    };

    const { data: inserted, error } = await supabase
      .from('skills')
      .insert(payload)
      .select()
      .single();

    if (error) throw error;

    cachedSkills = null;
    apiClient.notify();
    return inserted as Skill;
  },

  async updateSkill(
    id: string,
    updates: Partial<{ name: string; category: string; description: string; isActive: boolean }>
  ): Promise<void> {
    if (!isSupabaseConfigured()) return;

    const payload: any = {};
    if (updates.name !== undefined) payload.name = updates.name.trim();
    if (updates.category !== undefined) payload.category = updates.category.trim();
    if (updates.description !== undefined) payload.description = updates.description?.trim() || null;
    if (updates.isActive !== undefined) payload.is_active = updates.isActive;

    const { error } = await supabase.from('skills').update(payload).eq('id', id);
    if (error) throw error;

    cachedSkills = null;
    apiClient.notify();
  },

  async deleteSkill(id: string): Promise<void> {
    if (!isSupabaseConfigured()) return;
    const { error } = await supabase.from('skills').delete().eq('id', id);
    if (error) throw error;
    cachedSkills = null;
    apiClient.notify();
  },

  // =========================================================================
  // COMPETENCIES
  // =========================================================================

  async getCompetencies(): Promise<Competency[]> {
    if (cachedCompetencies && Date.now() - lastCacheTime < CACHE_TTL) {
      return cachedCompetencies;
    }
    if (!isSupabaseConfigured()) return [];

    const orgId = await resolveOrgId();
    try {
      let query = supabase
        .from('competencies')
        .select('*')
        .order('name', { ascending: true });

      if (orgId) {
        query = query.eq('organization_id', orgId);
      }

      const { data, error } = await query;
      if (error) {
        console.warn('[JobArchitecture] competencies query failed:', error.message);
        return [];
      }

      const competencies: Competency[] = (data || []).map((row: any) => ({
        id: row.id,
        organizationId: row.organization_id,
        name: row.name,
        description: row.description || undefined,
        behaviors: Array.isArray(row.behaviors) ? row.behaviors : [],
        isActive: row.is_active ?? true,
        created: row.created,
        updated: row.updated,
      }));

      cachedCompetencies = competencies;
      return competencies;
    } catch (e: any) {
      console.warn('[JobArchitecture] Failed to fetch competencies:', e?.message || e);
      return [];
    }
  },

  async createCompetency(data: {
    name: string;
    description?: string;
    behaviors?: string[];
  }): Promise<Competency | null> {
    if (!isSupabaseConfigured()) return null;
    const orgId = await resolveOrgId();
    if (!orgId) throw new Error('No active organization found');

    const payload = {
      organization_id: orgId,
      name: data.name.trim(),
      description: data.description?.trim() || null,
      behaviors: data.behaviors || [],
      is_active: true,
    };

    const { data: inserted, error } = await supabase
      .from('competencies')
      .insert(payload)
      .select()
      .single();

    if (error) throw error;

    cachedCompetencies = null;
    apiClient.notify();
    return inserted as Competency;
  },

  async updateCompetency(
    id: string,
    updates: Partial<{ name: string; description: string; behaviors: string[]; isActive: boolean }>
  ): Promise<void> {
    if (!isSupabaseConfigured()) return;

    const payload: any = {};
    if (updates.name !== undefined) payload.name = updates.name.trim();
    if (updates.description !== undefined) payload.description = updates.description?.trim() || null;
    if (updates.behaviors !== undefined) payload.behaviors = updates.behaviors;
    if (updates.isActive !== undefined) payload.is_active = updates.isActive;

    const { error } = await supabase.from('competencies').update(payload).eq('id', id);
    if (error) throw error;

    cachedCompetencies = null;
    apiClient.notify();
  },

  async deleteCompetency(id: string): Promise<void> {
    if (!isSupabaseConfigured()) return;
    const { error } = await supabase.from('competencies').delete().eq('id', id);
    if (error) throw error;
    cachedCompetencies = null;
    apiClient.notify();
  },

  // =========================================================================
  // KPIS
  // =========================================================================

  async getKPIs(jobRoleId?: string): Promise<KPI[]> {
    if (cachedKPIs && Date.now() - lastCacheTime < CACHE_TTL && !jobRoleId) {
      return cachedKPIs;
    }
    if (!isSupabaseConfigured()) return [];

    const orgId = await resolveOrgId();
    try {
      let query = supabase
        .from('kpis')
        .select(`
          *,
          job_role:job_roles!job_role_id(id, title)
        `)
        .order('name', { ascending: true });

      if (orgId) {
        query = query.eq('organization_id', orgId);
      }
      if (jobRoleId) {
        query = query.eq('job_role_id', jobRoleId);
      }

      const { data, error } = await query;
      if (error) {
        console.warn('[JobArchitecture] kpis query failed:', error.message);
        return [];
      }

      const kpis: KPI[] = (data || []).map((row: any) => ({
        id: row.id,
        organizationId: row.organization_id,
        jobRoleId: row.job_role_id || undefined,
        jobRoleTitle: row.job_role?.title || undefined,
        name: row.name,
        description: row.description || undefined,
        metricUnit: row.metric_unit || undefined,
        targetValue: row.target_value || undefined,
        frequency: row.frequency || 'Quarterly',
        isActive: row.is_active ?? true,
        created: row.created,
        updated: row.updated,
      }));

      if (!jobRoleId) {
        cachedKPIs = kpis;
      }
      return kpis;
    } catch (e: any) {
      console.warn('[JobArchitecture] Failed to fetch KPIs:', e?.message || e);
      return [];
    }
  },

  async createKPI(data: {
    jobRoleId?: string;
    name: string;
    description?: string;
    metricUnit?: string;
    targetValue?: string;
    frequency?: string;
  }): Promise<KPI | null> {
    if (!isSupabaseConfigured()) return null;
    const orgId = await resolveOrgId();
    if (!orgId) throw new Error('No active organization found');

    const payload = {
      organization_id: orgId,
      job_role_id: data.jobRoleId || null,
      name: data.name.trim(),
      description: data.description?.trim() || null,
      metric_unit: data.metricUnit?.trim() || null,
      target_value: data.targetValue?.trim() || null,
      frequency: data.frequency || 'Quarterly',
      is_active: true,
    };

    const { data: inserted, error } = await supabase
      .from('kpis')
      .insert(payload)
      .select()
      .single();

    if (error) throw error;

    cachedKPIs = null;
    apiClient.notify();
    return inserted as KPI;
  },

  async updateKPI(
    id: string,
    updates: Partial<{
      jobRoleId: string | null;
      name: string;
      description: string;
      metricUnit: string;
      targetValue: string;
      frequency: string;
      isActive: boolean;
    }>
  ): Promise<void> {
    if (!isSupabaseConfigured()) return;

    const payload: any = {};
    if (updates.jobRoleId !== undefined) payload.job_role_id = updates.jobRoleId;
    if (updates.name !== undefined) payload.name = updates.name.trim();
    if (updates.description !== undefined) payload.description = updates.description?.trim() || null;
    if (updates.metricUnit !== undefined) payload.metric_unit = updates.metricUnit?.trim() || null;
    if (updates.targetValue !== undefined) payload.target_value = updates.targetValue?.trim() || null;
    if (updates.frequency !== undefined) payload.frequency = updates.frequency;
    if (updates.isActive !== undefined) payload.is_active = updates.isActive;

    const { error } = await supabase.from('kpis').update(payload).eq('id', id);
    if (error) throw error;

    cachedKPIs = null;
    apiClient.notify();
  },

  async deleteKPI(id: string): Promise<void> {
    if (!isSupabaseConfigured()) return;
    const { error } = await supabase.from('kpis').delete().eq('id', id);
    if (error) throw error;
    cachedKPIs = null;
    apiClient.notify();
  },

  // =========================================================================
  // JOB ROLE SKILLS & COMPETENCY MAPPINGS
  // =========================================================================

  async getRoleSkills(jobRoleId: string): Promise<JobRoleSkill[]> {
    if (!isSupabaseConfigured()) return [];
    try {
      const { data, error } = await supabase
        .from('job_role_skills')
        .select(`
          *,
          skill:skills!skill_id(id, name, category)
        `)
        .eq('job_role_id', jobRoleId);

      if (error) throw error;
      return (data || []).map((row: any) => ({
        id: row.id,
        jobRoleId: row.job_role_id,
        skillId: row.skill_id,
        skillName: row.skill?.name || undefined,
        category: row.skill?.category || undefined,
        requiredLevel: row.required_level,
        isMandatory: row.is_mandatory,
      }));
    } catch (e: any) {
      console.warn('[JobArchitecture] Failed to get role skills:', e?.message || e);
      return [];
    }
  },

  async setRoleSkills(
    jobRoleId: string,
    skills: { skillId: string; requiredLevel: number; isMandatory: boolean }[]
  ): Promise<void> {
    if (!isSupabaseConfigured()) return;

    // Delete existing
    await supabase.from('job_role_skills').delete().eq('job_role_id', jobRoleId);

    if (skills.length > 0) {
      const rows = skills.map((s) => ({
        job_role_id: jobRoleId,
        skill_id: s.skillId,
        required_level: s.requiredLevel,
        is_mandatory: s.isMandatory,
      }));
      const { error } = await supabase.from('job_role_skills').insert(rows);
      if (error) throw error;
    }

    apiClient.notify();
  },

  async getRoleCompetencies(jobRoleId: string): Promise<JobRoleCompetency[]> {
    if (!isSupabaseConfigured()) return [];
    try {
      const { data, error } = await supabase
        .from('job_role_competencies')
        .select(`
          *,
          competency:competencies!competency_id(id, name)
        `)
        .eq('job_role_id', jobRoleId);

      if (error) throw error;
      return (data || []).map((row: any) => ({
        id: row.id,
        jobRoleId: row.job_role_id,
        competencyId: row.competency_id,
        competencyName: row.competency?.name || undefined,
        expectedLevel: row.expected_level,
      }));
    } catch (e: any) {
      console.warn('[JobArchitecture] Failed to get role competencies:', e?.message || e);
      return [];
    }
  },

  async setRoleCompetencies(
    jobRoleId: string,
    competencies: { competencyId: string; expectedLevel: number }[]
  ): Promise<void> {
    if (!isSupabaseConfigured()) return;

    await supabase.from('job_role_competencies').delete().eq('job_role_id', jobRoleId);

    if (competencies.length > 0) {
      const rows = competencies.map((c) => ({
        job_role_id: jobRoleId,
        competency_id: c.competencyId,
        expected_level: c.expectedLevel,
      }));
      const { error } = await supabase.from('job_role_competencies').insert(rows);
      if (error) throw error;
    }

    apiClient.notify();
  },

  // =========================================================================
  // EMPLOYEE SKILLS & JOB ASSIGNMENTS
  // =========================================================================

  async getEmployeeSkills(employeeId: string): Promise<EmployeeSkill[]> {
    if (!isSupabaseConfigured()) return [];
    try {
      const { data, error } = await supabase
        .from('employee_skills')
        .select(`
          *,
          skill:skills!skill_id(id, name, category)
        `)
        .eq('employee_id', employeeId);

      if (error) throw error;
      return (data || []).map((row: any) => ({
        id: row.id,
        employeeId: row.employee_id,
        skillId: row.skill_id,
        skillName: row.skill?.name || undefined,
        category: row.skill?.category || undefined,
        selfRating: row.self_rating || undefined,
        managerRating: row.manager_rating || undefined,
        verifiedBy: row.verified_by || undefined,
        verifiedAt: row.verified_at || undefined,
      }));
    } catch (e: any) {
      console.warn('[JobArchitecture] Failed to fetch employee skills:', e?.message || e);
      return [];
    }
  },

  async upsertEmployeeSkill(
    employeeId: string,
    skillId: string,
    data: { selfRating?: number; managerRating?: number; verifiedBy?: string }
  ): Promise<void> {
    if (!isSupabaseConfigured()) return;

    const payload: any = {
      employee_id: employeeId,
      skill_id: skillId,
    };
    if (data.selfRating !== undefined) payload.self_rating = data.selfRating;
    if (data.managerRating !== undefined) payload.manager_rating = data.managerRating;
    if (data.verifiedBy !== undefined) {
      payload.verified_by = data.verifiedBy;
      payload.verified_at = new Date().toISOString();
    }

    const { error } = await supabase
      .from('employee_skills')
      .upsert(payload, { onConflict: 'employee_id,skill_id' });

    if (error) throw error;
    apiClient.notify();
  },

  async getEmployeeAssignments(employeeId: string): Promise<EmployeeJobAssignment[]> {
    if (!isSupabaseConfigured()) return [];
    try {
      const { data, error } = await supabase
        .from('employee_job_assignments')
        .select(`
          *,
          job_role:job_roles!job_role_id(id, title)
        `)
        .eq('employee_id', employeeId)
        .order('start_date', { ascending: false });

      if (error) throw error;
      return (data || []).map((row: any) => ({
        id: row.id,
        employeeId: row.employee_id,
        jobRoleId: row.job_role_id,
        jobRoleTitle: row.job_role?.title || undefined,
        jobDescriptionId: row.job_description_id || undefined,
        startDate: row.start_date,
        endDate: row.end_date || undefined,
        isPrimary: row.is_primary,
      }));
    } catch (e: any) {
      console.warn('[JobArchitecture] Failed to fetch employee assignments:', e?.message || e);
      return [];
    }
  },

  async assignEmployeeJobRole(data: {
    employeeId: string;
    jobRoleId: string;
    jobDescriptionId?: string;
    startDate?: string;
    isPrimary?: boolean;
  }): Promise<void> {
    if (!isSupabaseConfigured()) return;

    const isPrimary = data.isPrimary ?? true;
    if (isPrimary) {
      // Demote previous primary assignments
      await supabase
        .from('employee_job_assignments')
        .update({ is_primary: false })
        .eq('employee_id', data.employeeId);
    }

    const payload = {
      employee_id: data.employeeId,
      job_role_id: data.jobRoleId,
      job_description_id: data.jobDescriptionId || null,
      start_date: data.startDate || new Date().toISOString().split('T')[0],
      is_primary: isPrimary,
    };

    const { error } = await supabase.from('employee_job_assignments').insert(payload);
    if (error) throw error;
    apiClient.notify();
  },
};
