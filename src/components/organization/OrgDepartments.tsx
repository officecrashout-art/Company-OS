import React, { useState, useEffect } from 'react';
import {
  Building2,
  FolderTree,
  Users,
  UserCheck,
  Plus,
  Edit3,
  Trash2,
  ChevronRight,
  Loader2,
  Layers,
  ArrowRight,
  Shield,
  Briefcase,
  Search,
} from 'lucide-react';
import { Department, Employee, Team } from '../../types';
import { departmentService } from '../../services/department.service';
import { useToast } from '../../context/ToastContext';

interface OrgDepartmentsProps {
  employees: Employee[];
  teams: Team[];
  canWrite: boolean;
  onSyncDepartments?: (names: string[]) => void;
}

export const OrgDepartments: React.FC<OrgDepartmentsProps> = ({
  employees,
  teams,
  canWrite,
  onSyncDepartments,
}) => {
  const { showToast } = useToast();
  const [departments, setDepartments] = useState<Department[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  // Modal State
  const [showModal, setShowModal] = useState(false);
  const [editingDept, setEditingDept] = useState<Department | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    code: '',
    description: '',
    managerId: '',
    parentId: '',
    displayOrder: 0,
  });

  const loadDepartments = async () => {
    setIsLoading(true);
    try {
      const data = await departmentService.getDepartments();
      setDepartments(data);
    } catch (e: any) {
      console.error('Failed to load departments:', e);
      showToast('Could not load departments', 'error');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadDepartments();
  }, []);

  const openCreateModal = () => {
    setEditingDept(null);
    setFormData({
      name: '',
      code: '',
      description: '',
      managerId: '',
      parentId: '',
      displayOrder: departments.length * 10,
    });
    setShowModal(true);
  };

  const openEditModal = (dept: Department) => {
    setEditingDept(dept);
    setFormData({
      name: dept.name,
      code: dept.code || '',
      description: dept.description || '',
      managerId: dept.managerId || '',
      parentId: dept.parentId || '',
      displayOrder: dept.displayOrder || 0,
    });
    setShowModal(true);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!canWrite) {
      showToast('Action not allowed with current permissions/subscription', 'warning');
      return;
    }
    if (!formData.name.trim()) {
      showToast('Department name is required', 'warning');
      return;
    }

    setIsSubmitting(true);
    try {
      if (editingDept) {
        await departmentService.updateDepartment(editingDept.id, {
          name: formData.name,
          code: formData.code || undefined,
          description: formData.description || undefined,
          managerId: formData.managerId || null,
          parentId: formData.parentId || null,
          displayOrder: Number(formData.displayOrder) || 0,
        });
        showToast('Department updated successfully', 'success');
      } else {
        await departmentService.createDepartment({
          name: formData.name,
          code: formData.code || undefined,
          description: formData.description || undefined,
          managerId: formData.managerId || undefined,
          parentId: formData.parentId || undefined,
          displayOrder: Number(formData.displayOrder) || 0,
        });
        showToast('Department created successfully', 'success');
      }

      setShowModal(false);
      await loadDepartments();

      // Trigger legacy sync if callback provided
      if (onSyncDepartments) {
        const refreshed = await departmentService.getDepartments();
        onSyncDepartments(refreshed.map((d) => d.name));
      }
    } catch (e: any) {
      console.error('Error saving department:', e);
      showToast(e.message || 'Failed to save department', 'error');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async (dept: Department) => {
    if (!canWrite) {
      showToast('Action not allowed', 'warning');
      return;
    }
    if (!confirm(`Are you sure you want to delete department "${dept.name}"?`)) return;

    try {
      await departmentService.deleteDepartment(dept.id);
      showToast('Department deleted', 'success');
      await loadDepartments();
      if (onSyncDepartments) {
        const refreshed = await departmentService.getDepartments();
        onSyncDepartments(refreshed.map((d) => d.name));
      }
    } catch (e: any) {
      console.error('Failed to delete department:', e);
      showToast(e.message || 'Failed to delete department', 'error');
    }
  };

  // Filtered list
  const filteredDepartments = departments.filter((d) => {
    const q = searchQuery.toLowerCase();
    return (
      d.name.toLowerCase().includes(q) ||
      (d.code && d.code.toLowerCase().includes(q)) ||
      (d.description && d.description.toLowerCase().includes(q))
    );
  });

  // Calculate top-level vs sub-departments
  const topLevelDepts = filteredDepartments.filter((d) => !d.parentId);
  const subDeptsMap = new Map<string, Department[]>();
  filteredDepartments.forEach((d) => {
    if (d.parentId) {
      const arr = subDeptsMap.get(d.parentId) || [];
      arr.push(d);
      subDeptsMap.set(d.parentId, arr);
    }
  });

  return (
    <div className="space-y-6">
      {/* Overview & Hierarchy Banner */}
      <div className="bg-gradient-to-r from-slate-900 via-indigo-950 to-slate-900 rounded-[2rem] p-6 md:p-8 text-white relative overflow-hidden shadow-xl">
        <div className="absolute top-0 right-0 w-96 h-96 bg-primary/10 rounded-full blur-3xl pointer-events-none" />
        <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
          <div className="space-y-2 max-w-xl">
            <div className="inline-flex items-center gap-2 px-3 py-1 bg-white/10 rounded-full text-xs font-semibold uppercase tracking-wider text-primary-light">
              <FolderTree size={14} /> Organizational Model (Phase 7)
            </div>
            <h2 className="text-2xl md:text-3xl font-bold tracking-tight">
              Company Structure & Departments
            </h2>
            <p className="text-sm text-slate-300">
              Establish the formal enterprise hierarchy: Company &rarr; Departments &rarr; Teams &rarr; Employees.
            </p>
          </div>

          <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
            <button
              onClick={openCreateModal}
              disabled={!canWrite}
              className="px-5 py-3 bg-primary hover:bg-primary/90 text-white font-semibold text-xs uppercase tracking-widest rounded-xl transition-all shadow-md flex items-center justify-center gap-2 disabled:opacity-50"
            >
              <Plus size={16} /> Add Department
            </button>
          </div>
        </div>

        {/* Visual Breadcrumb Cascade */}
        <div className="mt-6 pt-6 border-t border-white/10 grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div className="p-3 bg-white/5 rounded-xl border border-white/10">
            <div className="text-[10px] uppercase font-bold text-slate-400 tracking-wider">Tier 1</div>
            <div className="text-sm font-semibold flex items-center gap-1.5 mt-0.5">
              <Building2 size={16} className="text-primary-light" /> Company
            </div>
            <div className="text-[11px] text-slate-400 mt-1">Tenant Organization</div>
          </div>
          <div className="p-3 bg-white/5 rounded-xl border border-white/10">
            <div className="text-[10px] uppercase font-bold text-slate-400 tracking-wider">Tier 2</div>
            <div className="text-sm font-semibold flex items-center gap-1.5 mt-0.5">
              <FolderTree size={16} className="text-emerald-400" /> Departments ({departments.length})
            </div>
            <div className="text-[11px] text-slate-400 mt-1">Divisions & Functions</div>
          </div>
          <div className="p-3 bg-white/5 rounded-xl border border-white/10">
            <div className="text-[10px] uppercase font-bold text-slate-400 tracking-wider">Tier 3</div>
            <div className="text-sm font-semibold flex items-center gap-1.5 mt-0.5">
              <Users size={16} className="text-sky-400" /> Teams ({teams.length})
            </div>
            <div className="text-[11px] text-slate-400 mt-1">Execution Squads</div>
          </div>
          <div className="p-3 bg-white/5 rounded-xl border border-white/10">
            <div className="text-[10px] uppercase font-bold text-slate-400 tracking-wider">Tier 4</div>
            <div className="text-sm font-semibold flex items-center gap-1.5 mt-0.5">
              <UserCheck size={16} className="text-amber-400" /> Employees ({employees.length})
            </div>
            <div className="text-[11px] text-slate-400 mt-1">Talent Roster</div>
          </div>
        </div>
      </div>

      {/* Search & Stats Bar */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
        <div className="relative w-full sm:w-80">
          <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
          <input
            type="text"
            placeholder="Search departments..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
          />
        </div>
        <div className="text-xs text-slate-500 font-medium">
          Showing <span className="font-bold text-slate-800">{filteredDepartments.length}</span> departments
        </div>
      </div>

      {/* Departments Grid & Tree */}
      {isLoading ? (
        <div className="py-20 flex flex-col items-center justify-center text-slate-400">
          <Loader2 className="w-8 h-8 text-primary animate-spin mb-3" />
          <p className="text-xs font-semibold uppercase tracking-wider">Loading Departments...</p>
        </div>
      ) : filteredDepartments.length === 0 ? (
        <div className="bg-white rounded-3xl border border-slate-200 p-12 text-center space-y-4 shadow-sm">
          <FolderTree size={40} className="mx-auto text-slate-300" />
          <div className="space-y-1">
            <h3 className="text-base font-semibold text-slate-800">No departments configured</h3>
            <p className="text-sm text-slate-500 max-w-sm mx-auto">
              Create your organization&apos;s departments (e.g. Engineering, Sales, Human Resources) to establish your hierarchy.
            </p>
          </div>
          <button
            onClick={openCreateModal}
            disabled={!canWrite}
            className="px-5 py-2.5 bg-primary text-white text-xs font-semibold uppercase tracking-widest rounded-xl hover:bg-primary/90 transition-all inline-flex items-center gap-2"
          >
            <Plus size={16} /> Create First Department
          </button>
        </div>
      ) : (
        <div className="space-y-4">
          {topLevelDepts.map((dept) => {
            const childDepts = subDeptsMap.get(dept.id) || [];
            const linkedTeams = teams.filter((t) => t.departmentId === dept.id || t.department === dept.name);
            const deptEmps = employees.filter((e) => e.departmentId === dept.id || e.department === dept.name);

            return (
              <div
                key={dept.id}
                className="bg-white rounded-2xl border border-slate-200/80 shadow-sm p-5 hover:border-slate-300 transition-all"
              >
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                  <div className="space-y-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="font-bold text-slate-900 text-lg">{dept.name}</span>
                      {dept.code && (
                        <span className="px-2 py-0.5 bg-slate-100 text-slate-700 rounded-md font-mono text-xs font-semibold">
                          {dept.code}
                        </span>
                      )}
                      {!dept.isActive && (
                        <span className="px-2 py-0.5 bg-amber-50 text-amber-700 rounded-md text-[10px] font-semibold uppercase">
                          Inactive
                        </span>
                      )}
                    </div>
                    {dept.description && (
                      <p className="text-xs text-slate-500 max-w-2xl">{dept.description}</p>
                    )}
                  </div>

                  <div className="flex items-center gap-1 self-end sm:self-center">
                    <button
                      onClick={() => openEditModal(dept)}
                      className="p-2 text-slate-400 hover:text-primary rounded-lg transition-colors"
                      title="Edit Department"
                    >
                      <Edit3 size={16} />
                    </button>
                    <button
                      onClick={() => handleDelete(dept)}
                      className="p-2 text-slate-400 hover:text-rose-500 rounded-lg transition-colors"
                      title="Delete Department"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                </div>

                {/* Metadata Pills */}
                <div className="mt-4 pt-3 border-t border-slate-100 flex flex-wrap items-center gap-4 text-xs text-slate-600">
                  <div className="flex items-center gap-1.5">
                    <UserCheck size={14} className="text-primary" />
                    <span>
                      Head / Manager:{' '}
                      <span className="font-semibold text-slate-800">
                        {dept.managerName || 'Unassigned'}
                      </span>
                    </span>
                  </div>
                  <div className="flex items-center gap-1.5">
                    <Users size={14} className="text-sky-500" />
                    <span>
                      Teams:{' '}
                      <span className="font-semibold text-slate-800">{linkedTeams.length}</span>
                    </span>
                  </div>
                  <div className="flex items-center gap-1.5">
                    <Briefcase size={14} className="text-amber-500" />
                    <span>
                      Employees:{' '}
                      <span className="font-semibold text-slate-800">{deptEmps.length}</span>
                    </span>
                  </div>
                </div>

                {/* Sub-departments (Child Nodes) */}
                {childDepts.length > 0 && (
                  <div className="mt-4 pt-3 pl-4 border-l-2 border-primary/20 space-y-2">
                    <div className="text-[10px] font-bold text-slate-400 uppercase tracking-wider flex items-center gap-1">
                      <FolderTree size={12} /> Sub-Departments ({childDepts.length})
                    </div>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                      {childDepts.map((sub) => {
                        const subTeams = teams.filter((t) => t.departmentId === sub.id || t.department === sub.name);
                        return (
                          <div
                            key={sub.id}
                            className="p-3 bg-slate-50 border border-slate-100 rounded-xl flex items-center justify-between"
                          >
                            <div>
                              <div className="font-semibold text-slate-800 text-xs flex items-center gap-1.5">
                                {sub.name}
                                {sub.code && (
                                  <span className="font-mono text-[10px] text-slate-500 bg-white px-1.5 py-0.5 rounded border border-slate-200">
                                    {sub.code}
                                  </span>
                                )}
                              </div>
                              <div className="text-[10px] text-slate-400 mt-0.5">
                                {subTeams.length} teams &bull; Manager: {sub.managerName || 'None'}
                              </div>
                            </div>
                            <div className="flex items-center gap-1">
                              <button
                                onClick={() => openEditModal(sub)}
                                className="p-1.5 text-slate-400 hover:text-primary"
                              >
                                <Edit3 size={14} />
                              </button>
                              <button
                                onClick={() => handleDelete(sub)}
                                className="p-1.5 text-slate-400 hover:text-rose-500"
                              >
                                <Trash2 size={14} />
                              </button>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      {/* Add / Edit Department Modal */}
      {showModal && (
        <div className="fixed inset-0 z-50 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-lg w-full p-6 shadow-2xl border border-slate-100 animate-in zoom-in-95 duration-200">
            <h3 className="text-lg font-bold text-slate-900 mb-4">
              {editingDept ? 'Edit Department' : 'Create Department'}
            </h3>

            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                  Department Name *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Engineering, Sales, Operations"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                    Code / Abbreviation
                  </label>
                  <input
                    type="text"
                    placeholder="e.g. ENG, HR, MKT"
                    value={formData.code}
                    onChange={(e) => setFormData({ ...formData, code: e.target.value.toUpperCase() })}
                    className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm font-mono focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                    Display Order
                  </label>
                  <input
                    type="number"
                    value={formData.displayOrder}
                    onChange={(e) => setFormData({ ...formData, displayOrder: Number(e.target.value) })}
                    className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                  Parent Department (Optional)
                </label>
                <select
                  value={formData.parentId}
                  onChange={(e) => setFormData({ ...formData, parentId: e.target.value })}
                  className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
                >
                  <option value="">None (Top-Level Department)</option>
                  {departments
                    .filter((d) => !editingDept || d.id !== editingDept.id)
                    .map((d) => (
                      <option key={d.id} value={d.id}>
                        {d.name} {d.code ? `(${d.code})` : ''}
                      </option>
                    ))}
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                  Department Head / Manager
                </label>
                <select
                  value={formData.managerId}
                  onChange={(e) => setFormData({ ...formData, managerId: e.target.value })}
                  className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
                >
                  <option value="">Select Manager...</option>
                  {employees.map((emp) => (
                    <option key={emp.id} value={emp.id}>
                      {emp.name} &bull; {emp.designation || 'Staff'} ({emp.email})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                  Description
                </label>
                <textarea
                  rows={2}
                  placeholder="Purpose and mandate of this department..."
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  className="px-4 py-2 border border-slate-200 text-slate-600 rounded-xl text-xs font-semibold uppercase tracking-wider hover:bg-slate-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="px-5 py-2 bg-primary text-white rounded-xl text-xs font-semibold uppercase tracking-wider hover:bg-primary/90 disabled:opacity-50 flex items-center gap-1.5"
                >
                  {isSubmitting && <Loader2 size={14} className="animate-spin" />}
                  {editingDept ? 'Update' : 'Create'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
