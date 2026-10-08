import React, { useState, useEffect } from 'react';
import {
  Shield,
  Lock,
  Plus,
  Check,
  CheckCircle2,
  X,
  AlertCircle,
  Loader2,
  Key,
  Layers,
  Search,
} from 'lucide-react';
import { RoleEntity, Permission } from '../../types';
import { roleService } from '../../services/role.service';
import { useToast } from '../../context/ToastContext';

interface OrgRolesPermissionsProps {
  canWrite: boolean;
}

export const OrgRolesPermissions: React.FC<OrgRolesPermissionsProps> = ({ canWrite }) => {
  const { showToast } = useToast();
  const [roles, setRoles] = useState<RoleEntity[]>([]);
  const [permissions, setPermissions] = useState<Permission[]>([]);
  const [selectedRole, setSelectedRole] = useState<RoleEntity | null>(null);
  const [assignedPermissionIds, setAssignedPermissionIds] = useState<Set<string>>(new Set());

  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  // New Role Modal
  const [showRoleModal, setShowRoleModal] = useState(false);
  const [newRoleForm, setNewRoleForm] = useState({ name: '', code: '', description: '' });

  const loadData = async () => {
    setIsLoading(true);
    try {
      const [r, p] = await Promise.all([roleService.getRoles(), roleService.getPermissions()]);
      setRoles(r);
      setPermissions(p);
      if (r.length > 0 && !selectedRole) {
        setSelectedRole(r[0]);
      }
    } catch (e: any) {
      console.error('Failed to load roles and permissions:', e);
      showToast('Could not load roles/permissions', 'error');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  // When selected role changes, load its assigned permissions
  useEffect(() => {
    if (!selectedRole) return;
    roleService.getRolePermissions(selectedRole.id).then((pids) => {
      setAssignedPermissionIds(new Set(pids));
    });
  }, [selectedRole]);

  const handleTogglePermission = (permissionId: string) => {
    if (!canWrite) return;
    const next = new Set(assignedPermissionIds);
    if (next.has(permissionId)) {
      next.delete(permissionId);
    } else {
      next.add(permissionId);
    }
    setAssignedPermissionIds(next);
  };

  const handleSaveRolePermissions = async () => {
    if (!selectedRole || !canWrite) return;
    setIsSaving(true);
    try {
      await roleService.setRolePermissions(selectedRole.id, Array.from(assignedPermissionIds));
      showToast(`Permissions for ${selectedRole.name} updated successfully`, 'success');
    } catch (e: any) {
      console.error('Failed to save role permissions:', e);
      showToast(e.message || 'Failed to update permissions', 'error');
    } finally {
      setIsSaving(false);
    }
  };

  const handleCreateRole = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!canWrite) return;
    if (!newRoleForm.name.trim() || !newRoleForm.code.trim()) {
      showToast('Role name and code are required', 'warning');
      return;
    }
    setIsSaving(true);
    try {
      const created = await roleService.createRole({
        name: newRoleForm.name,
        code: newRoleForm.code,
        description: newRoleForm.description || undefined,
      });
      showToast('Custom role created', 'success');
      setShowRoleModal(false);
      setNewRoleForm({ name: '', code: '', description: '' });
      const updatedRoles = await roleService.getRoles();
      setRoles(updatedRoles);
      if (created) setSelectedRole(created);
    } catch (e: any) {
      showToast(e.message || 'Failed to create role', 'error');
    } finally {
      setIsSaving(false);
    }
  };

  // Group permissions by module
  const groupedPermissions = permissions.reduce((acc, p) => {
    if (!acc[p.module]) acc[p.module] = [];
    acc[p.module].push(p);
    return acc;
  }, {} as Record<string, Permission[]>);

  const modules = Object.keys(groupedPermissions);

  return (
    <div className="space-y-6">
      {/* Header Banner */}
      <div className="bg-gradient-to-r from-slate-900 via-indigo-950 to-slate-900 rounded-[2rem] p-6 md:p-8 text-white relative overflow-hidden shadow-xl">
        <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
          <div className="space-y-2 max-w-xl">
            <div className="inline-flex items-center gap-2 px-3 py-1 bg-white/10 rounded-full text-xs font-semibold uppercase tracking-wider text-emerald-300">
              <Shield size={14} /> Role-Based Access Control (RBAC)
            </div>
            <h2 className="text-2xl md:text-3xl font-bold tracking-tight">
              Roles &amp; Granular Permissions
            </h2>
            <p className="text-sm text-slate-300">
              Manage enterprise authority matrices. Grant or restrict permissions across all core modules for system roles and custom business roles.
            </p>
          </div>

          <button
            onClick={() => setShowRoleModal(true)}
            disabled={!canWrite}
            className="px-5 py-3 bg-primary hover:bg-primary/90 text-white font-semibold text-xs uppercase tracking-widest rounded-xl transition-all shadow-md flex items-center justify-center gap-2 disabled:opacity-50"
          >
            <Plus size={16} /> New Custom Role
          </button>
        </div>
      </div>

      {isLoading ? (
        <div className="py-20 flex flex-col items-center justify-center text-slate-400">
          <Loader2 className="w-8 h-8 text-primary animate-spin mb-3" />
          <p className="text-xs font-semibold uppercase tracking-wider">Loading RBAC Matrix...</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
          {/* Roles Selector Sidebar */}
          <div className="lg:col-span-1 space-y-3">
            <div className="text-xs font-bold uppercase tracking-wider text-slate-400 px-1">
              Select Role ({roles.length})
            </div>

            <div className="space-y-2">
              {roles.map((role) => {
                const isSelected = selectedRole?.id === role.id;
                return (
                  <button
                    key={role.id}
                    onClick={() => setSelectedRole(role)}
                    className={`w-full text-left p-4 rounded-2xl border transition-all flex flex-col gap-1 ${
                      isSelected
                        ? 'bg-primary text-white border-primary shadow-md'
                        : 'bg-white text-slate-800 border-slate-200 hover:border-slate-300'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <span className="font-bold text-sm">{role.name}</span>
                      <span
                        className={`text-[9px] px-2 py-0.5 rounded-full font-mono font-bold uppercase ${
                          isSelected
                            ? 'bg-white/20 text-white'
                            : role.isSystem
                            ? 'bg-slate-100 text-slate-600'
                            : 'bg-emerald-50 text-emerald-700'
                        }`}
                      >
                        {role.code}
                      </span>
                    </div>
                    {role.description && (
                      <p
                        className={`text-xs line-clamp-2 ${
                          isSelected ? 'text-white/80' : 'text-slate-500'
                        }`}
                      >
                        {role.description}
                      </p>
                    )}
                  </button>
                );
              })}
            </div>
          </div>

          {/* Permissions Matrix */}
          <div className="lg:col-span-3 space-y-4">
            {selectedRole && (
              <div className="p-5 bg-white border border-slate-200 rounded-2xl shadow-sm flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="text-base font-bold text-slate-900">
                      Permissions for: <span className="text-primary">{selectedRole.name}</span>
                    </h3>
                    {selectedRole.isSystem && (
                      <span className="text-[10px] font-bold uppercase px-2 py-0.5 bg-slate-100 text-slate-600 rounded">
                        System Built-in
                      </span>
                    )}
                  </div>
                  <p className="text-xs text-slate-500 mt-0.5">
                    {assignedPermissionIds.size} of {permissions.length} permissions granted
                  </p>
                </div>

                <button
                  onClick={handleSaveRolePermissions}
                  disabled={!canWrite || isSaving}
                  className="px-5 py-2.5 bg-primary text-white text-xs font-semibold uppercase tracking-widest rounded-xl hover:bg-primary/90 flex items-center gap-1.5 shadow-sm disabled:opacity-50"
                >
                  {isSaving && <Loader2 size={14} className="animate-spin" />}
                  Save Changes
                </button>
              </div>
            )}

            {/* Modules Grid */}
            <div className="space-y-4">
              {modules.map((mod) => {
                const modPerms = groupedPermissions[mod] || [];
                const allSelected = modPerms.every((p) => assignedPermissionIds.has(p.id));

                return (
                  <div
                    key={mod}
                    className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden"
                  >
                    <div className="px-5 py-3.5 bg-slate-50 border-b border-slate-100 flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Lock size={14} className="text-primary" />
                        <h4 className="text-xs font-bold uppercase tracking-wider text-slate-700">
                          {mod} Module
                        </h4>
                        <span className="text-[10px] text-slate-400 font-semibold">
                          ({modPerms.length} actions)
                        </span>
                      </div>

                      <button
                        type="button"
                        onClick={() => {
                          if (!canWrite) return;
                          const next = new Set(assignedPermissionIds);
                          if (allSelected) {
                            modPerms.forEach((p) => next.delete(p.id));
                          } else {
                            modPerms.forEach((p) => next.add(p.id));
                          }
                          setAssignedPermissionIds(next);
                        }}
                        className="text-xs font-semibold text-primary hover:underline"
                      >
                        {allSelected ? 'Deselect All' : 'Select All'}
                      </button>
                    </div>

                    <div className="p-4 grid grid-cols-1 md:grid-cols-2 gap-3">
                      {modPerms.map((perm) => {
                        const isGranted = assignedPermissionIds.has(perm.id);
                        return (
                          <label
                            key={perm.id}
                            className={`p-3 rounded-xl border transition-all flex items-start gap-3 cursor-pointer ${
                              isGranted
                                ? 'bg-primary/5 border-primary/30 text-slate-900'
                                : 'bg-slate-50/50 border-slate-200 text-slate-600 hover:border-slate-300'
                            }`}
                          >
                            <input
                              type="checkbox"
                              checked={isGranted}
                              onChange={() => handleTogglePermission(perm.id)}
                              className="mt-0.5 rounded text-primary focus:ring-0"
                            />
                            <div className="space-y-0.5">
                              <div className="text-xs font-bold flex items-center gap-1.5">
                                {perm.name}
                                <span className="font-mono text-[9px] text-slate-400 font-normal">
                                  ({perm.code})
                                </span>
                              </div>
                              {perm.description && (
                                <p className="text-[11px] text-slate-500">{perm.description}</p>
                              )}
                            </div>
                          </label>
                        );
                      })}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* New Custom Role Modal */}
      {showRoleModal && (
        <div className="fixed inset-0 z-50 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-100 animate-in zoom-in-95 duration-200">
            <h3 className="text-lg font-bold text-slate-900 mb-4">Create Custom Role</h3>
            <form onSubmit={handleCreateRole} className="space-y-4">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                  Role Name *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Lead Auditor, Payroll Officer"
                  value={newRoleForm.name}
                  onChange={(e) => setNewRoleForm({ ...newRoleForm, name: e.target.value })}
                  className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                  Role Code *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. AUDITOR, PAYROLL"
                  value={newRoleForm.code}
                  onChange={(e) =>
                    setNewRoleForm({ ...newRoleForm, code: e.target.value.toUpperCase() })
                  }
                  className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm font-mono"
                />
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                  Description
                </label>
                <textarea
                  rows={2}
                  placeholder="Responsibility scope..."
                  value={newRoleForm.description}
                  onChange={(e) => setNewRoleForm({ ...newRoleForm, description: e.target.value })}
                  className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm"
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setShowRoleModal(false)}
                  className="px-4 py-2 border border-slate-200 text-slate-600 rounded-xl text-xs font-semibold uppercase"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSaving}
                  className="px-5 py-2 bg-primary text-white rounded-xl text-xs font-semibold uppercase tracking-wider flex items-center gap-1.5"
                >
                  {isSaving && <Loader2 size={14} className="animate-spin" />}
                  Create Role
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
