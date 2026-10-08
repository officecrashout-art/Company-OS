import { supabase, isSupabaseConfigured } from './supabase';
import { apiClient, resolveOrgId } from './api.client';
import { RoleEntity, Permission, RolePermission } from '../types';

let cachedRoles: RoleEntity[] | null = null;
let cachedPermissions: Permission[] | null = null;

export const roleService = {
  clearCache() {
    cachedRoles = null;
    cachedPermissions = null;
  },

  async getRoles(): Promise<RoleEntity[]> {
    if (cachedRoles) return cachedRoles;
    if (!isSupabaseConfigured()) return [];

    const orgId = await resolveOrgId();
    try {
      let query = supabase
        .from('roles')
        .select('*')
        .order('is_system', { ascending: false })
        .order('name', { ascending: true });

      if (orgId) {
        query = query.or(`organization_id.eq.${orgId},organization_id.is.null`);
      }

      const { data, error } = await query;
      if (error) {
        console.warn('[RoleService] roles query failed (may not be migrated yet):', error.message);
        return [];
      }

      const roles: RoleEntity[] = (data || []).map((r: any) => ({
        id: r.id,
        organizationId: r.organization_id || undefined,
        name: r.name,
        code: r.code,
        description: r.description || undefined,
        isSystem: !!r.is_system,
        created: r.created,
        updated: r.updated,
      }));

      cachedRoles = roles;
      return roles;
    } catch (e: any) {
      console.warn('[RoleService] Failed to fetch roles:', e?.message || e);
      return [];
    }
  },

  async getPermissions(): Promise<Permission[]> {
    if (cachedPermissions) return cachedPermissions;
    if (!isSupabaseConfigured()) return [];

    try {
      const { data, error } = await supabase
        .from('permissions')
        .select('*')
        .order('module', { ascending: true })
        .order('name', { ascending: true });

      if (error) {
        console.warn('[RoleService] permissions query failed:', error.message);
        return [];
      }

      const permissions: Permission[] = (data || []).map((p: any) => ({
        id: p.id,
        module: p.module,
        action: p.action,
        code: p.code,
        name: p.name,
        description: p.description || undefined,
        created: p.created,
      }));

      cachedPermissions = permissions;
      return permissions;
    } catch (e: any) {
      console.warn('[RoleService] Failed to fetch permissions:', e?.message || e);
      return [];
    }
  },

  async getRolePermissions(roleId: string): Promise<string[]> {
    if (!isSupabaseConfigured()) return [];
    try {
      const { data, error } = await supabase
        .from('role_permissions')
        .select('permission_id')
        .eq('role_id', roleId);

      if (error) throw error;
      return (data || []).map((row: any) => row.permission_id);
    } catch (e: any) {
      console.warn('[RoleService] Failed to fetch role permissions:', e?.message || e);
      return [];
    }
  },

  async setRolePermissions(roleId: string, permissionIds: string[]): Promise<void> {
    if (!isSupabaseConfigured()) return;

    // Delete existing
    const { error: delError } = await supabase
      .from('role_permissions')
      .delete()
      .eq('role_id', roleId);

    if (delError) throw delError;

    if (permissionIds.length > 0) {
      const rows = permissionIds.map((pid) => ({
        role_id: roleId,
        permission_id: pid,
      }));
      const { error: insError } = await supabase
        .from('role_permissions')
        .insert(rows);

      if (insError) throw insError;
    }

    apiClient.notify();
  },

  async createRole(data: { name: string; code: string; description?: string }): Promise<RoleEntity | null> {
    if (!isSupabaseConfigured()) return null;
    const orgId = await resolveOrgId();
    if (!orgId) throw new Error('No active organization found');

    const payload = {
      organization_id: orgId,
      name: data.name.trim(),
      code: data.code.trim().toUpperCase(),
      description: data.description?.trim() || null,
      is_system: false,
    };

    const { data: inserted, error } = await supabase
      .from('roles')
      .insert(payload)
      .select()
      .single();

    if (error) throw error;

    roleService.clearCache();
    apiClient.notify();
    return inserted as RoleEntity;
  },

  async deleteRole(id: string): Promise<void> {
    if (!isSupabaseConfigured()) return;

    const { error } = await supabase
      .from('roles')
      .delete()
      .eq('id', id);

    if (error) throw error;

    roleService.clearCache();
    apiClient.notify();
  },
};
