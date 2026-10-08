import { supabase, isSupabaseConfigured } from './supabase';
import { apiClient, resolveOrgId } from './api.client';
import { Department } from '../types';

let cachedDepartments: Department[] | null = null;
let cacheTimestamp = 0;
const CACHE_TTL = 3 * 60 * 1000;

export const departmentService = {
  clearCache() {
    cachedDepartments = null;
    cacheTimestamp = 0;
  },

  async getDepartments(): Promise<Department[]> {
    if (cachedDepartments && Date.now() - cacheTimestamp < CACHE_TTL) {
      return cachedDepartments;
    }
    if (!isSupabaseConfigured()) return [];

    const orgId = await resolveOrgId();
    try {
      let query = supabase
        .from('departments')
        .select(`
          *,
          manager:profiles!manager_id(id, name),
          parent:departments!parent_id(id, name)
        `)
        .order('display_order', { ascending: true })
        .order('name', { ascending: true });

      if (orgId) {
        query = query.eq('organization_id', orgId);
      }

      const { data, error } = await query;
      if (error) {
        // Fallback gracefully if table not yet migrated
        console.warn('[DepartmentService] departments table query error, falling back:', error.message);
        return [];
      }

      const departments: Department[] = (data || []).map((row: any) => ({
        id: row.id,
        organizationId: row.organization_id,
        name: row.name,
        code: row.code || undefined,
        description: row.description || undefined,
        managerId: row.manager_id || undefined,
        managerName: row.manager?.name || undefined,
        parentId: row.parent_id || undefined,
        parentName: row.parent?.name || undefined,
        isActive: row.is_active ?? true,
        displayOrder: row.display_order || 0,
        created: row.created,
        updated: row.updated,
      }));

      cachedDepartments = departments;
      cacheTimestamp = Date.now();
      return departments;
    } catch (e: any) {
      console.warn('[DepartmentService] Failed to fetch departments:', e?.message || e);
      return [];
    }
  },

  async createDepartment(data: {
    name: string;
    code?: string;
    description?: string;
    managerId?: string;
    parentId?: string;
    displayOrder?: number;
  }): Promise<Department | null> {
    if (!isSupabaseConfigured()) return null;
    const orgId = await resolveOrgId();
    if (!orgId) throw new Error('No active organization found');

    const payload: any = {
      organization_id: orgId,
      name: data.name.trim(),
      code: data.code?.trim() || null,
      description: data.description?.trim() || null,
      manager_id: data.managerId || null,
      parent_id: data.parentId || null,
      display_order: data.displayOrder ?? 0,
      is_active: true,
    };

    const { data: inserted, error } = await supabase
      .from('departments')
      .insert(payload)
      .select()
      .single();

    if (error) throw error;

    departmentService.clearCache();
    apiClient.notify();
    return inserted as Department;
  },

  async updateDepartment(
    id: string,
    updates: Partial<{
      name: string;
      code: string;
      description: string;
      managerId: string | null;
      parentId: string | null;
      isActive: boolean;
      displayOrder: number;
    }>
  ): Promise<void> {
    if (!isSupabaseConfigured()) return;

    const payload: any = {};
    if (updates.name !== undefined) payload.name = updates.name.trim();
    if (updates.code !== undefined) payload.code = updates.code?.trim() || null;
    if (updates.description !== undefined) payload.description = updates.description?.trim() || null;
    if (updates.managerId !== undefined) payload.manager_id = updates.managerId || null;
    if (updates.parentId !== undefined) payload.parent_id = updates.parentId || null;
    if (updates.isActive !== undefined) payload.is_active = updates.isActive;
    if (updates.displayOrder !== undefined) payload.display_order = updates.displayOrder;

    const { error } = await supabase
      .from('departments')
      .update(payload)
      .eq('id', id);

    if (error) throw error;

    departmentService.clearCache();
    apiClient.notify();
  },

  async deleteDepartment(id: string): Promise<void> {
    if (!isSupabaseConfigured()) return;

    const { error } = await supabase
      .from('departments')
      .delete()
      .eq('id', id);

    if (error) throw error;

    departmentService.clearCache();
    apiClient.notify();
  },
};
