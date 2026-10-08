import React, { useState, useEffect } from 'react';
import {
  Briefcase,
  FileText,
  Award,
  Target,
  Plus,
  Edit3,
  Trash2,
  Loader2,
  Search,
  CheckCircle2,
  ChevronRight,
  Sparkles,
  BookOpen,
  Sliders,
  Layers,
  Star,
  ExternalLink,
} from 'lucide-react';
import {
  JobRole,
  JobDescription,
  Skill,
  Competency,
  KPI,
  Department,
  JobRoleSkill,
  JobRoleCompetency,
} from '../../types';
import { jobArchitectureService } from '../../services/jobArchitecture.service';
import { departmentService } from '../../services/department.service';
import { useToast } from '../../context/ToastContext';

type SubTab = 'ROLES' | 'DESCRIPTIONS' | 'SKILLS' | 'COMPETENCIES' | 'KPIS';

interface OrgJobArchitectureProps {
  canWrite: boolean;
}

const CAREER_LEVELS = ['Entry', 'Junior', 'Mid', 'Senior', 'Lead', 'Staff / Principal', 'Director', 'Executive'];
const EMPLOYMENT_TYPES = ['Full-time', 'Part-time', 'Contract', 'Internship', 'Temporary'];
const SKILL_CATEGORIES = ['Technical', 'Domain', 'Leadership', 'Communication', 'Tools'];
const KPI_FREQUENCIES = ['Weekly', 'Monthly', 'Quarterly', 'Bi-annual', 'Annual'];

export const OrgJobArchitecture: React.FC<OrgJobArchitectureProps> = ({ canWrite }) => {
  const { showToast } = useToast();
  const [activeSubTab, setActiveSubTab] = useState<SubTab>('ROLES');
  const [isLoading, setIsLoading] = useState(true);

  // Core domain states
  const [jobRoles, setJobRoles] = useState<JobRole[]>([]);
  const [departments, setDepartments] = useState<Department[]>([]);
  const [skills, setSkills] = useState<Skill[]>([]);
  const [competencies, setCompetencies] = useState<Competency[]>([]);
  const [kpis, setKpis] = useState<KPI[]>([]);

  // Selected entities for drilldown
  const [selectedRoleForJD, setSelectedRoleForJD] = useState<JobRole | null>(null);
  const [roleJDs, setRoleJDs] = useState<JobDescription[]>([]);
  const [selectedRoleForReqs, setSelectedRoleForReqs] = useState<JobRole | null>(null);
  const [roleSkills, setRoleSkills] = useState<JobRoleSkill[]>([]);
  const [roleCompetencies, setRoleCompetencies] = useState<JobRoleCompetency[]>([]);

  // Search filter
  const [searchQuery, setSearchQuery] = useState('');

  // Modals state
  const [modalType, setModalType] = useState<
    'ROLE' | 'JD' | 'SKILL' | 'COMPETENCY' | 'KPI' | 'ROLE_MAPPINGS' | null
  >(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Forms
  const [roleForm, setRoleForm] = useState({
    id: '',
    title: '',
    roleCode: '',
    departmentId: '',
    careerLevel: 'Mid',
    employmentType: 'Full-time',
    reportsToRoleId: '',
  });

  const [jdForm, setJdForm] = useState({
    jobRoleId: '',
    purpose: '',
    responsibilities: [''],
    requirements: [''],
    status: 'ACTIVE' as 'DRAFT' | 'ACTIVE' | 'ARCHIVED',
    effectiveFrom: new Date().toISOString().split('T')[0],
  });

  const [skillForm, setSkillForm] = useState({
    id: '',
    name: '',
    category: 'Technical',
    description: '',
  });

  const [competencyForm, setCompetencyForm] = useState({
    id: '',
    name: '',
    description: '',
    behaviors: [''],
  });

  const [kpiForm, setKpiForm] = useState({
    id: '',
    jobRoleId: '',
    name: '',
    description: '',
    metricUnit: '%',
    targetValue: '100',
    frequency: 'Quarterly',
  });

  // Load all foundational Job Architecture data
  const loadAll = async () => {
    setIsLoading(true);
    try {
      const [r, d, s, c, k] = await Promise.all([
        jobArchitectureService.getJobRoles(),
        departmentService.getDepartments(),
        jobArchitectureService.getSkills(),
        jobArchitectureService.getCompetencies(),
        jobArchitectureService.getKPIs(),
      ]);
      setJobRoles(r);
      setDepartments(d);
      setSkills(s);
      setCompetencies(c);
      setKpis(k);
    } catch (e: any) {
      console.error('Job Architecture load error:', e);
      showToast('Failed to load job architecture data', 'error');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadAll();
  }, []);

  // When selected role for JD changes, fetch its versioned JDs
  useEffect(() => {
    if (selectedRoleForJD) {
      jobArchitectureService.getJobDescriptions(selectedRoleForJD.id).then(setRoleJDs);
    }
  }, [selectedRoleForJD]);

  // When selected role for requirements mapping changes, fetch its skills & competencies
  useEffect(() => {
    if (selectedRoleForReqs) {
      Promise.all([
        jobArchitectureService.getRoleSkills(selectedRoleForReqs.id),
        jobArchitectureService.getRoleCompetencies(selectedRoleForReqs.id),
      ]).then(([rs, rc]) => {
        setRoleSkills(rs);
        setRoleCompetencies(rc);
      });
    }
  }, [selectedRoleForReqs]);

  // --- Handlers: Job Role ---
  const handleOpenRoleModal = (role?: JobRole) => {
    if (role) {
      setRoleForm({
        id: role.id,
        title: role.title,
        roleCode: role.roleCode || '',
        departmentId: role.departmentId || '',
        careerLevel: role.careerLevel || 'Mid',
        employmentType: role.employmentType || 'Full-time',
        reportsToRoleId: role.reportsToRoleId || '',
      });
    } else {
      setRoleForm({
        id: '',
        title: '',
        roleCode: '',
        departmentId: departments[0]?.id || '',
        careerLevel: 'Mid',
        employmentType: 'Full-time',
        reportsToRoleId: '',
      });
    }
    setModalType('ROLE');
  };

  const handleSaveRole = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!canWrite) return;
    setIsSubmitting(true);
    try {
      if (roleForm.id) {
        await jobArchitectureService.updateJobRole(roleForm.id, {
          title: roleForm.title,
          roleCode: roleForm.roleCode || null,
          departmentId: roleForm.departmentId || null,
          careerLevel: roleForm.careerLevel,
          employmentType: roleForm.employmentType,
          reportsToRoleId: roleForm.reportsToRoleId || null,
        });
        showToast('Job Role updated', 'success');
      } else {
        await jobArchitectureService.createJobRole({
          title: roleForm.title,
          roleCode: roleForm.roleCode || undefined,
          departmentId: roleForm.departmentId || undefined,
          careerLevel: roleForm.careerLevel,
          employmentType: roleForm.employmentType,
          reportsToRoleId: roleForm.reportsToRoleId || undefined,
        });
        showToast('Job Role created', 'success');
      }
      setModalType(null);
      const updated = await jobArchitectureService.getJobRoles();
      setJobRoles(updated);
    } catch (err: any) {
      showToast(err.message || 'Failed to save job role', 'error');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteRole = async (role: JobRole) => {
    if (!canWrite || !confirm(`Delete Job Role "${role.title}"?`)) return;
    try {
      await jobArchitectureService.deleteJobRole(role.id);
      showToast('Job Role deleted', 'success');
      const updated = await jobArchitectureService.getJobRoles();
      setJobRoles(updated);
      if (selectedRoleForJD?.id === role.id) setSelectedRoleForJD(null);
      if (selectedRoleForReqs?.id === role.id) setSelectedRoleForReqs(null);
    } catch (err: any) {
      showToast(err.message || 'Failed to delete job role', 'error');
    }
  };

  // --- Handlers: Job Description ---
  const handleOpenNewJDModal = (role: JobRole) => {
    setJdForm({
      jobRoleId: role.id,
      purpose: '',
      responsibilities: [''],
      requirements: [''],
      status: 'ACTIVE',
      effectiveFrom: new Date().toISOString().split('T')[0],
    });
    setModalType('JD');
  };

  const handleSaveJD = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!canWrite) return;
    setIsSubmitting(true);
    try {
      const cleanResp = jdForm.responsibilities.map((r) => r.trim()).filter(Boolean);
      const cleanReq = jdForm.requirements.map((r) => r.trim()).filter(Boolean);

      await jobArchitectureService.createJobDescription({
        jobRoleId: jdForm.jobRoleId,
        purpose: jdForm.purpose,
        responsibilities: cleanResp,
        requirements: cleanReq,
        status: jdForm.status,
        effectiveFrom: jdForm.effectiveFrom,
      });
      showToast('Versioned Job Description published', 'success');
      setModalType(null);
      if (selectedRoleForJD) {
        const jds = await jobArchitectureService.getJobDescriptions(selectedRoleForJD.id);
        setRoleJDs(jds);
      }
    } catch (err: any) {
      showToast(err.message || 'Failed to save job description', 'error');
    } finally {
      setIsSubmitting(false);
    }
  };

  // --- Handlers: Skill ---
  const handleOpenSkillModal = (skill?: Skill) => {
    if (skill) {
      setSkillForm({
        id: skill.id,
        name: skill.name,
        category: skill.category,
        description: skill.description || '',
      });
    } else {
      setSkillForm({
        id: '',
        name: '',
        category: 'Technical',
        description: '',
      });
    }
    setModalType('SKILL');
  };

  const handleSaveSkill = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!canWrite) return;
    setIsSubmitting(true);
    try {
      if (skillForm.id) {
        await jobArchitectureService.updateSkill(skillForm.id, {
          name: skillForm.name,
          category: skillForm.category,
          description: skillForm.description || undefined,
        });
        showToast('Skill updated', 'success');
      } else {
        await jobArchitectureService.createSkill({
          name: skillForm.name,
          category: skillForm.category,
          description: skillForm.description || undefined,
        });
        showToast('Skill created in catalog', 'success');
      }
      setModalType(null);
      const updated = await jobArchitectureService.getSkills();
      setSkills(updated);
    } catch (err: any) {
      showToast(err.message || 'Failed to save skill', 'error');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteSkill = async (skill: Skill) => {
    if (!canWrite || !confirm(`Delete Skill "${skill.name}"?`)) return;
    try {
      await jobArchitectureService.deleteSkill(skill.id);
      showToast('Skill deleted', 'success');
      const updated = await jobArchitectureService.getSkills();
      setSkills(updated);
    } catch (err: any) {
      showToast(err.message || 'Failed to delete skill', 'error');
    }
  };

  // --- Handlers: Competency ---
  const handleOpenCompetencyModal = (comp?: Competency) => {
    if (comp) {
      setCompetencyForm({
        id: comp.id,
        name: comp.name,
        description: comp.description || '',
        behaviors: comp.behaviors.length > 0 ? comp.behaviors : [''],
      });
    } else {
      setCompetencyForm({
        id: '',
        name: '',
        description: '',
        behaviors: [''],
      });
    }
    setModalType('COMPETENCY');
  };

  const handleSaveCompetency = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!canWrite) return;
    setIsSubmitting(true);
    try {
      const cleanBehaviors = competencyForm.behaviors.map((b) => b.trim()).filter(Boolean);
      if (competencyForm.id) {
        await jobArchitectureService.updateCompetency(competencyForm.id, {
          name: competencyForm.name,
          description: competencyForm.description || undefined,
          behaviors: cleanBehaviors,
        });
        showToast('Competency updated', 'success');
      } else {
        await jobArchitectureService.createCompetency({
          name: competencyForm.name,
          description: competencyForm.description || undefined,
          behaviors: cleanBehaviors,
        });
        showToast('Competency created', 'success');
      }
      setModalType(null);
      const updated = await jobArchitectureService.getCompetencies();
      setCompetencies(updated);
    } catch (err: any) {
      showToast(err.message || 'Failed to save competency', 'error');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteCompetency = async (comp: Competency) => {
    if (!canWrite || !confirm(`Delete Competency "${comp.name}"?`)) return;
    try {
      await jobArchitectureService.deleteCompetency(comp.id);
      showToast('Competency deleted', 'success');
      const updated = await jobArchitectureService.getCompetencies();
      setCompetencies(updated);
    } catch (err: any) {
      showToast(err.message || 'Failed to delete competency', 'error');
    }
  };

  // --- Handlers: KPI ---
  const handleOpenKPIModal = (kpi?: KPI) => {
    if (kpi) {
      setKpiForm({
        id: kpi.id,
        jobRoleId: kpi.jobRoleId || '',
        name: kpi.name,
        description: kpi.description || '',
        metricUnit: kpi.metricUnit || '%',
        targetValue: kpi.targetValue || '100',
        frequency: kpi.frequency || 'Quarterly',
      });
    } else {
      setKpiForm({
        id: '',
        jobRoleId: selectedRoleForJD?.id || '',
        name: '',
        description: '',
        metricUnit: '%',
        targetValue: '100',
        frequency: 'Quarterly',
      });
    }
    setModalType('KPI');
  };

  const handleSaveKPI = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!canWrite) return;
    setIsSubmitting(true);
    try {
      if (kpiForm.id) {
        await jobArchitectureService.updateKPI(kpiForm.id, {
          jobRoleId: kpiForm.jobRoleId || null,
          name: kpiForm.name,
          description: kpiForm.description || undefined,
          metricUnit: kpiForm.metricUnit || undefined,
          targetValue: kpiForm.targetValue || undefined,
          frequency: kpiForm.frequency,
        });
        showToast('KPI updated', 'success');
      } else {
        await jobArchitectureService.createKPI({
          jobRoleId: kpiForm.jobRoleId || undefined,
          name: kpiForm.name,
          description: kpiForm.description || undefined,
          metricUnit: kpiForm.metricUnit || undefined,
          targetValue: kpiForm.targetValue || undefined,
          frequency: kpiForm.frequency,
        });
        showToast('KPI defined', 'success');
      }
      setModalType(null);
      const updated = await jobArchitectureService.getKPIs();
      setKpis(updated);
    } catch (err: any) {
      showToast(err.message || 'Failed to save KPI', 'error');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteKPI = async (kpi: KPI) => {
    if (!canWrite || !confirm(`Delete KPI "${kpi.name}"?`)) return;
    try {
      await jobArchitectureService.deleteKPI(kpi.id);
      showToast('KPI deleted', 'success');
      const updated = await jobArchitectureService.getKPIs();
      setKpis(updated);
    } catch (err: any) {
      showToast(err.message || 'Failed to delete KPI', 'error');
    }
  };

  // --- Handlers: Role Requirements Mappings (Skills & Competencies) ---
  const handleOpenMappingsModal = (role: JobRole) => {
    setSelectedRoleForReqs(role);
    setModalType('ROLE_MAPPINGS');
  };

  const handleSaveMappings = async () => {
    if (!selectedRoleForReqs || !canWrite) return;
    setIsSubmitting(true);
    try {
      await jobArchitectureService.setRoleSkills(
        selectedRoleForReqs.id,
        roleSkills.map((s) => ({
          skillId: s.skillId,
          requiredLevel: s.requiredLevel,
          isMandatory: s.isMandatory,
        }))
      );
      await jobArchitectureService.setRoleCompetencies(
        selectedRoleForReqs.id,
        roleCompetencies.map((c) => ({
          competencyId: c.competencyId,
          expectedLevel: c.expectedLevel,
        }))
      );
      showToast('Role requirements updated', 'success');
      setModalType(null);
    } catch (err: any) {
      showToast(err.message || 'Failed to save requirements', 'error');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header Banner */}
      <div className="bg-gradient-to-r from-indigo-900 via-slate-900 to-indigo-950 rounded-[2rem] p-6 md:p-8 text-white relative overflow-hidden shadow-xl">
        <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
          <div className="space-y-2 max-w-xl">
            <div className="inline-flex items-center gap-2 px-3 py-1 bg-white/10 rounded-full text-xs font-semibold uppercase tracking-wider text-indigo-300">
              <Sparkles size={14} /> Job Architecture Engine (Phase 7)
            </div>
            <h2 className="text-2xl md:text-3xl font-bold tracking-tight">
              Job Roles, Descriptions & Capabilities
            </h2>
            <p className="text-sm text-slate-300">
              Structured definition of enterprise job roles, versioned responsibilities, skills matrix, core competencies, and measurable KPIs.
            </p>
          </div>
        </div>

        {/* Sub-Tabs Selector */}
        <div className="mt-6 pt-6 border-t border-white/10 flex gap-2 overflow-x-auto no-scrollbar">
          {[
            { id: 'ROLES', label: 'Job Roles', count: jobRoles.length, icon: Briefcase },
            { id: 'DESCRIPTIONS', label: 'Job Descriptions', count: roleJDs.length, icon: FileText },
            { id: 'SKILLS', label: 'Skills Matrix', count: skills.length, icon: Award },
            { id: 'COMPETENCIES', label: 'Competencies', count: competencies.length, icon: BookOpen },
            { id: 'KPIS', label: 'Role KPIs', count: kpis.length, icon: Target },
          ].map((tab) => {
            const Icon = tab.icon;
            const isCur = activeSubTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveSubTab(tab.id as SubTab)}
                className={`px-4 py-2.5 rounded-xl font-semibold text-xs uppercase tracking-wider flex items-center gap-2 whitespace-nowrap transition-all ${
                  isCur
                    ? 'bg-white text-indigo-900 shadow-md'
                    : 'bg-white/10 text-white/80 hover:bg-white/20'
                }`}
              >
                <Icon size={14} />
                {tab.label}
                <span
                  className={`text-[10px] px-1.5 py-0.2 rounded-full font-bold ${
                    isCur ? 'bg-indigo-100 text-indigo-900' : 'bg-white/10 text-white'
                  }`}
                >
                  {tab.count}
                </span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Main Content Area */}
      {isLoading ? (
        <div className="py-20 flex flex-col items-center justify-center text-slate-400">
          <Loader2 className="w-8 h-8 text-indigo-600 animate-spin mb-3" />
          <p className="text-xs font-semibold uppercase tracking-wider">Loading Job Architecture...</p>
        </div>
      ) : (
        <div>
          {/* ========================================================================= */}
          {/* SUB-TAB: JOB ROLES */}
          {/* ========================================================================= */}
          {activeSubTab === 'ROLES' && (
            <div className="space-y-4">
              <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
                <div className="relative w-full sm:w-80">
                  <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
                  <input
                    type="text"
                    placeholder="Search job roles or codes..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="w-full pl-10 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500/20"
                  />
                </div>

                <button
                  onClick={() => handleOpenRoleModal()}
                  disabled={!canWrite}
                  className="w-full sm:w-auto px-5 py-2.5 bg-primary text-white text-xs font-semibold uppercase tracking-widest rounded-xl hover:bg-primary/90 flex items-center justify-center gap-2 shadow-sm"
                >
                  <Plus size={16} /> New Job Role
                </button>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {jobRoles
                  .filter((r) => {
                    const q = searchQuery.toLowerCase();
                    return (
                      r.title.toLowerCase().includes(q) ||
                      (r.roleCode && r.roleCode.toLowerCase().includes(q)) ||
                      (r.departmentName && r.departmentName.toLowerCase().includes(q))
                    );
                  })
                  .map((role) => (
                    <div
                      key={role.id}
                      className="p-5 bg-white border border-slate-200/80 rounded-2xl shadow-sm hover:border-indigo-300 transition-all flex flex-col justify-between"
                    >
                      <div className="space-y-3">
                        <div className="flex items-start justify-between gap-2">
                          <div>
                            <span className="text-[10px] font-bold text-indigo-600 bg-indigo-50 px-2 py-0.5 rounded uppercase tracking-wider">
                              {role.departmentName || 'General'}
                            </span>
                            <h3 className="font-bold text-slate-900 text-base mt-1">{role.title}</h3>
                          </div>
                          {role.roleCode && (
                            <span className="font-mono text-xs text-slate-400 bg-slate-100 px-2 py-0.5 rounded">
                              {role.roleCode}
                            </span>
                          )}
                        </div>

                        <div className="flex flex-wrap gap-2 text-xs">
                          <span className="px-2 py-0.5 bg-slate-100 text-slate-700 rounded-md font-medium">
                            Level: {role.careerLevel}
                          </span>
                          <span className="px-2 py-0.5 bg-slate-100 text-slate-700 rounded-md font-medium">
                            {role.employmentType}
                          </span>
                        </div>

                        {role.reportsToRoleTitle && (
                          <div className="text-xs text-slate-500 flex items-center gap-1">
                            <span className="font-medium text-slate-400">Reports to:</span>
                            <span className="font-semibold text-slate-700">{role.reportsToRoleTitle}</span>
                          </div>
                        )}
                      </div>

                      <div className="mt-5 pt-4 border-t border-slate-100 flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <button
                            onClick={() => {
                              setSelectedRoleForJD(role);
                              setActiveSubTab('DESCRIPTIONS');
                            }}
                            className="text-xs font-semibold text-indigo-600 hover:text-indigo-800 flex items-center gap-1"
                          >
                            <FileText size={14} /> JD
                          </button>
                          <span className="text-slate-300">&bull;</span>
                          <button
                            onClick={() => handleOpenMappingsModal(role)}
                            className="text-xs font-semibold text-indigo-600 hover:text-indigo-800 flex items-center gap-1"
                          >
                            <Sliders size={14} /> Requirements
                          </button>
                        </div>

                        <div className="flex items-center gap-1">
                          <button
                            onClick={() => handleOpenRoleModal(role)}
                            className="p-1.5 text-slate-400 hover:text-primary rounded-lg"
                          >
                            <Edit3 size={15} />
                          </button>
                          <button
                            onClick={() => handleDeleteRole(role)}
                            className="p-1.5 text-slate-400 hover:text-rose-500 rounded-lg"
                          >
                            <Trash2 size={15} />
                          </button>
                        </div>
                      </div>
                    </div>
                  ))}
              </div>
            </div>
          )}

          {/* ========================================================================= */}
          {/* SUB-TAB: JOB DESCRIPTIONS */}
          {/* ========================================================================= */}
          {activeSubTab === 'DESCRIPTIONS' && (
            <div className="space-y-6">
              <div className="p-4 bg-slate-50 border border-slate-200 rounded-2xl flex flex-col sm:flex-row items-center justify-between gap-4">
                <div className="flex items-center gap-3 w-full sm:w-auto">
                  <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
                    Active Role:
                  </span>
                  <select
                    value={selectedRoleForJD?.id || ''}
                    onChange={(e) => {
                      const found = jobRoles.find((r) => r.id === e.target.value) || null;
                      setSelectedRoleForJD(found);
                    }}
                    className="flex-1 sm:w-72 px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm font-semibold focus:outline-none focus:ring-2 focus:ring-indigo-500/20"
                  >
                    <option value="">Select a Job Role...</option>
                    {jobRoles.map((r) => (
                      <option key={r.id} value={r.id}>
                        {r.title} ({r.departmentName || 'General'})
                      </option>
                    ))}
                  </select>
                </div>

                {selectedRoleForJD && (
                  <button
                    onClick={() => handleOpenNewJDModal(selectedRoleForJD)}
                    disabled={!canWrite}
                    className="w-full sm:w-auto px-4 py-2 bg-indigo-600 text-white rounded-xl text-xs font-semibold uppercase tracking-wider flex items-center justify-center gap-1.5 hover:bg-indigo-700"
                  >
                    <Plus size={15} /> Author New Version
                  </button>
                )}
              </div>

              {!selectedRoleForJD ? (
                <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center text-slate-400">
                  <FileText size={40} className="mx-auto mb-2 opacity-50" />
                  <p className="text-sm font-medium">Please select a job role above to inspect or create versioned Job Descriptions.</p>
                </div>
              ) : roleJDs.length === 0 ? (
                <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center space-y-3">
                  <FileText size={40} className="mx-auto text-slate-300" />
                  <p className="text-sm text-slate-600 font-semibold">
                    No Job Descriptions found for &quot;{selectedRoleForJD.title}&quot;
                  </p>
                  <button
                    onClick={() => handleOpenNewJDModal(selectedRoleForJD)}
                    disabled={!canWrite}
                    className="px-4 py-2 bg-primary text-white rounded-xl text-xs font-semibold uppercase tracking-wider inline-flex items-center gap-2"
                  >
                    <Plus size={15} /> Create Version 1 JD
                  </button>
                </div>
              ) : (
                <div className="space-y-4">
                  {roleJDs.map((jd) => (
                    <div
                      key={jd.id}
                      className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm space-y-4"
                    >
                      <div className="flex items-center justify-between border-b border-slate-100 pb-3">
                        <div className="flex items-center gap-3">
                          <span className="font-bold text-lg text-slate-900">
                            Version {jd.version}
                          </span>
                          {jd.isCurrent && (
                            <span className="px-2.5 py-0.5 bg-emerald-50 text-emerald-700 text-xs font-bold rounded-full">
                              Current Active
                            </span>
                          )}
                          <span className="px-2.5 py-0.5 bg-slate-100 text-slate-600 text-xs font-semibold rounded-full">
                            Status: {jd.status}
                          </span>
                        </div>
                        <div className="text-xs text-slate-400">
                          Effective: {jd.effectiveFrom} {jd.effectiveTo ? `to ${jd.effectiveTo}` : ''}
                        </div>
                      </div>

                      {jd.purpose && (
                        <div>
                          <div className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-1">
                            Role Purpose
                          </div>
                          <p className="text-sm text-slate-700 bg-slate-50 p-3 rounded-xl border border-slate-100">
                            {jd.purpose}
                          </p>
                        </div>
                      )}

                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                          <div className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
                            Key Responsibilities ({jd.responsibilities.length})
                          </div>
                          <ul className="space-y-1.5 list-disc list-inside text-xs text-slate-700 bg-slate-50/50 p-3 rounded-xl border border-slate-100">
                            {jd.responsibilities.map((r, i) => (
                              <li key={i}>{r}</li>
                            ))}
                          </ul>
                        </div>

                        <div>
                          <div className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
                            Core Requirements ({jd.requirements.length})
                          </div>
                          <ul className="space-y-1.5 list-disc list-inside text-xs text-slate-700 bg-slate-50/50 p-3 rounded-xl border border-slate-100">
                            {jd.requirements.map((req, i) => (
                              <li key={i}>{req}</li>
                            ))}
                          </ul>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* ========================================================================= */}
          {/* SUB-TAB: SKILLS MATRIX */}
          {/* ========================================================================= */}
          {activeSubTab === 'SKILLS' && (
            <div className="space-y-4">
              <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
                <div className="relative w-full sm:w-80">
                  <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
                  <input
                    type="text"
                    placeholder="Search skills catalog..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="w-full pl-10 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500/20"
                  />
                </div>

                <button
                  onClick={() => handleOpenSkillModal()}
                  disabled={!canWrite}
                  className="w-full sm:w-auto px-5 py-2.5 bg-primary text-white text-xs font-semibold uppercase tracking-widest rounded-xl hover:bg-primary/90 flex items-center justify-center gap-2 shadow-sm"
                >
                  <Plus size={16} /> Add Skill
                </button>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
                {skills
                  .filter((s) => s.name.toLowerCase().includes(searchQuery.toLowerCase()))
                  .map((skill) => (
                    <div
                      key={skill.id}
                      className="p-4 bg-white border border-slate-200 rounded-2xl shadow-sm hover:border-slate-300 transition-all flex flex-col justify-between"
                    >
                      <div>
                        <div className="flex items-center justify-between gap-2 mb-1.5">
                          <span className="text-[10px] font-bold text-slate-500 bg-slate-100 px-2 py-0.5 rounded uppercase">
                            {skill.category}
                          </span>
                          <div className="flex items-center gap-1">
                            <button
                              onClick={() => handleOpenSkillModal(skill)}
                              className="p-1 text-slate-400 hover:text-primary"
                            >
                              <Edit3 size={14} />
                            </button>
                            <button
                              onClick={() => handleDeleteSkill(skill)}
                              className="p-1 text-slate-400 hover:text-rose-500"
                            >
                              <Trash2 size={14} />
                            </button>
                          </div>
                        </div>
                        <h4 className="font-bold text-slate-900 text-sm">{skill.name}</h4>
                        {skill.description && (
                          <p className="text-xs text-slate-500 mt-1 line-clamp-2">{skill.description}</p>
                        )}
                      </div>
                    </div>
                  ))}
              </div>
            </div>
          )}

          {/* ========================================================================= */}
          {/* SUB-TAB: COMPETENCIES */}
          {/* ========================================================================= */}
          {activeSubTab === 'COMPETENCIES' && (
            <div className="space-y-4">
              <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
                <div className="relative w-full sm:w-80">
                  <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
                  <input
                    type="text"
                    placeholder="Search competencies..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="w-full pl-10 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500/20"
                  />
                </div>

                <button
                  onClick={() => handleOpenCompetencyModal()}
                  disabled={!canWrite}
                  className="w-full sm:w-auto px-5 py-2.5 bg-primary text-white text-xs font-semibold uppercase tracking-widest rounded-xl hover:bg-primary/90 flex items-center justify-center gap-2 shadow-sm"
                >
                  <Plus size={16} /> Add Competency
                </button>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {competencies
                  .filter((c) => c.name.toLowerCase().includes(searchQuery.toLowerCase()))
                  .map((comp) => (
                    <div
                      key={comp.id}
                      className="p-5 bg-white border border-slate-200 rounded-2xl shadow-sm space-y-3"
                    >
                      <div className="flex items-start justify-between">
                        <div>
                          <h4 className="font-bold text-slate-900 text-base">{comp.name}</h4>
                          {comp.description && (
                            <p className="text-xs text-slate-500 mt-0.5">{comp.description}</p>
                          )}
                        </div>
                        <div className="flex items-center gap-1">
                          <button
                            onClick={() => handleOpenCompetencyModal(comp)}
                            className="p-1.5 text-slate-400 hover:text-primary"
                          >
                            <Edit3 size={15} />
                          </button>
                          <button
                            onClick={() => handleDeleteCompetency(comp)}
                            className="p-1.5 text-slate-400 hover:text-rose-500"
                          >
                            <Trash2 size={15} />
                          </button>
                        </div>
                      </div>

                      {comp.behaviors.length > 0 && (
                        <div>
                          <span className="text-[10px] font-bold uppercase tracking-wider text-slate-400">
                            Observable Behaviors:
                          </span>
                          <ul className="mt-1 space-y-1 list-disc list-inside text-xs text-slate-700 bg-slate-50 p-2.5 rounded-xl border border-slate-100">
                            {comp.behaviors.map((b, i) => (
                              <li key={i}>{b}</li>
                            ))}
                          </ul>
                        </div>
                      )}
                    </div>
                  ))}
              </div>
            </div>
          )}

          {/* ========================================================================= */}
          {/* SUB-TAB: KPIS */}
          {/* ========================================================================= */}
          {activeSubTab === 'KPIS' && (
            <div className="space-y-4">
              <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
                <div className="relative w-full sm:w-80">
                  <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
                  <input
                    type="text"
                    placeholder="Search KPIs..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="w-full pl-10 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500/20"
                  />
                </div>

                <button
                  onClick={() => handleOpenKPIModal()}
                  disabled={!canWrite}
                  className="w-full sm:w-auto px-5 py-2.5 bg-primary text-white text-xs font-semibold uppercase tracking-widest rounded-xl hover:bg-primary/90 flex items-center justify-center gap-2 shadow-sm"
                >
                  <Plus size={16} /> Define KPI
                </button>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {kpis
                  .filter((k) => k.name.toLowerCase().includes(searchQuery.toLowerCase()))
                  .map((kpi) => (
                    <div
                      key={kpi.id}
                      className="p-5 bg-white border border-slate-200 rounded-2xl shadow-sm flex flex-col justify-between"
                    >
                      <div className="space-y-2">
                        <div className="flex items-start justify-between">
                          <span className="text-[10px] font-bold text-slate-500 bg-slate-100 px-2 py-0.5 rounded uppercase">
                            {kpi.frequency}
                          </span>
                          <div className="flex items-center gap-1">
                            <button
                              onClick={() => handleOpenKPIModal(kpi)}
                              className="p-1 text-slate-400 hover:text-primary"
                            >
                              <Edit3 size={14} />
                            </button>
                            <button
                              onClick={() => handleDeleteKPI(kpi)}
                              className="p-1 text-slate-400 hover:text-rose-500"
                            >
                              <Trash2 size={14} />
                            </button>
                          </div>
                        </div>

                        <h4 className="font-bold text-slate-900 text-sm">{kpi.name}</h4>
                        {kpi.description && (
                          <p className="text-xs text-slate-500">{kpi.description}</p>
                        )}

                        {kpi.jobRoleTitle && (
                          <div className="text-[11px] text-slate-400">
                            Role: <span className="font-medium text-slate-700">{kpi.jobRoleTitle}</span>
                          </div>
                        )}
                      </div>

                      <div className="mt-4 pt-3 border-t border-slate-100 flex items-center justify-between text-xs font-semibold">
                        <span className="text-slate-400">Target Value:</span>
                        <span className="text-indigo-600 font-mono text-sm">
                          {kpi.targetValue} {kpi.metricUnit}
                        </span>
                      </div>
                    </div>
                  ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* ========================================================================= */}
      {/* MODAL: JOB ROLE FORM */}
      {/* ========================================================================= */}
      {modalType === 'ROLE' && (
        <div className="fixed inset-0 z-50 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-lg w-full p-6 shadow-2xl border border-slate-100 animate-in zoom-in-95 duration-200">
            <h3 className="text-lg font-bold text-slate-900 mb-4">
              {roleForm.id ? 'Edit Job Role' : 'Create Job Role'}
            </h3>
            <form onSubmit={handleSaveRole} className="space-y-4">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                  Job Title *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Senior Software Engineer"
                  value={roleForm.title}
                  onChange={(e) => setRoleForm({ ...roleForm, title: e.target.value })}
                  className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-indigo-500/20"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                    Role Code
                  </label>
                  <input
                    type="text"
                    placeholder="e.g. ENG-SWE-3"
                    value={roleForm.roleCode}
                    onChange={(e) => setRoleForm({ ...roleForm, roleCode: e.target.value.toUpperCase() })}
                    className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm font-mono focus:ring-2 focus:ring-indigo-500/20"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                    Department
                  </label>
                  <select
                    value={roleForm.departmentId}
                    onChange={(e) => setRoleForm({ ...roleForm, departmentId: e.target.value })}
                    className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:ring-2 focus:ring-indigo-500/20"
                  >
                    <option value="">General / None</option>
                    {departments.map((d) => (
                      <option key={d.id} value={d.id}>
                        {d.name}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                    Career Level
                  </label>
                  <select
                    value={roleForm.careerLevel}
                    onChange={(e) => setRoleForm({ ...roleForm, careerLevel: e.target.value })}
                    className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:ring-2 focus:ring-indigo-500/20"
                  >
                    {CAREER_LEVELS.map((lvl) => (
                      <option key={lvl} value={lvl}>
                        {lvl}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                    Employment Type
                  </label>
                  <select
                    value={roleForm.employmentType}
                    onChange={(e) => setRoleForm({ ...roleForm, employmentType: e.target.value })}
                    className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:ring-2 focus:ring-indigo-500/20"
                  >
                    {EMPLOYMENT_TYPES.map((type) => (
                      <option key={type} value={type}>
                        {type}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                  Reports To Job Role
                </label>
                <select
                  value={roleForm.reportsToRoleId}
                  onChange={(e) => setRoleForm({ ...roleForm, reportsToRoleId: e.target.value })}
                  className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:ring-2 focus:ring-indigo-500/20"
                >
                  <option value="">None / Executive</option>
                  {jobRoles
                    .filter((r) => r.id !== roleForm.id)
                    .map((r) => (
                      <option key={r.id} value={r.id}>
                        {r.title} ({r.departmentName || 'General'})
                      </option>
                    ))}
                </select>
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setModalType(null)}
                  className="px-4 py-2 border border-slate-200 text-slate-600 rounded-xl text-xs font-semibold uppercase"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="px-5 py-2 bg-primary text-white rounded-xl text-xs font-semibold uppercase tracking-wider flex items-center gap-1.5"
                >
                  {isSubmitting && <Loader2 size={14} className="animate-spin" />}
                  Save Role
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* MODAL: JOB DESCRIPTION VERSION FORM */}
      {/* ========================================================================= */}
      {modalType === 'JD' && (
        <div className="fixed inset-0 z-50 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-2xl w-full p-6 shadow-2xl border border-slate-100 max-h-[90vh] overflow-y-auto animate-in zoom-in-95 duration-200">
            <h3 className="text-lg font-bold text-slate-900 mb-1">
              Author Job Description Version
            </h3>
            <p className="text-xs text-slate-500 mb-4">
              Creating next version for &quot;{selectedRoleForJD?.title}&quot;
            </p>

            <form onSubmit={handleSaveJD} className="space-y-4">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                  Purpose Statement
                </label>
                <textarea
                  rows={2}
                  placeholder="Primary objective and mission of this role within the organization..."
                  value={jdForm.purpose}
                  onChange={(e) => setJdForm({ ...jdForm, purpose: e.target.value })}
                  className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-indigo-500/20"
                />
              </div>

              {/* Responsibilities */}
              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className="text-xs font-bold uppercase tracking-wider text-slate-500">
                    Responsibilities
                  </label>
                  <button
                    type="button"
                    onClick={() => setJdForm({ ...jdForm, responsibilities: [...jdForm.responsibilities, ''] })}
                    className="text-xs font-semibold text-indigo-600 hover:text-indigo-800"
                  >
                    + Add Item
                  </button>
                </div>
                <div className="space-y-2">
                  {jdForm.responsibilities.map((r, i) => (
                    <div key={i} className="flex items-center gap-2">
                      <input
                        type="text"
                        placeholder={`Responsibility #${i + 1}`}
                        value={r}
                        onChange={(e) => {
                          const next = [...jdForm.responsibilities];
                          next[i] = e.target.value;
                          setJdForm({ ...jdForm, responsibilities: next });
                        }}
                        className="flex-1 px-3 py-1.5 border border-slate-200 rounded-lg text-xs"
                      />
                      {jdForm.responsibilities.length > 1 && (
                        <button
                          type="button"
                          onClick={() => {
                            const next = jdForm.responsibilities.filter((_, idx) => idx !== i);
                            setJdForm({ ...jdForm, responsibilities: next });
                          }}
                          className="p-1 text-slate-400 hover:text-rose-500"
                        >
                          <Trash2 size={14} />
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              </div>

              {/* Requirements */}
              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className="text-xs font-bold uppercase tracking-wider text-slate-500">
                    Qualifications & Requirements
                  </label>
                  <button
                    type="button"
                    onClick={() => setJdForm({ ...jdForm, requirements: [...jdForm.requirements, ''] })}
                    className="text-xs font-semibold text-indigo-600 hover:text-indigo-800"
                  >
                    + Add Item
                  </button>
                </div>
                <div className="space-y-2">
                  {jdForm.requirements.map((req, i) => (
                    <div key={i} className="flex items-center gap-2">
                      <input
                        type="text"
                        placeholder={`Requirement #${i + 1}`}
                        value={req}
                        onChange={(e) => {
                          const next = [...jdForm.requirements];
                          next[i] = e.target.value;
                          setJdForm({ ...jdForm, requirements: next });
                        }}
                        className="flex-1 px-3 py-1.5 border border-slate-200 rounded-lg text-xs"
                      />
                      {jdForm.requirements.length > 1 && (
                        <button
                          type="button"
                          onClick={() => {
                            const next = jdForm.requirements.filter((_, idx) => idx !== i);
                            setJdForm({ ...jdForm, requirements: next });
                          }}
                          className="p-1 text-slate-400 hover:text-rose-500"
                        >
                          <Trash2 size={14} />
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3 pt-2">
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                    Status
                  </label>
                  <select
                    value={jdForm.status}
                    onChange={(e) => setJdForm({ ...jdForm, status: e.target.value as any })}
                    className="w-full px-3 py-2 border border-slate-200 rounded-xl text-xs bg-white"
                  >
                    <option value="ACTIVE">Active (Current)</option>
                    <option value="DRAFT">Draft</option>
                    <option value="ARCHIVED">Archived</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                    Effective From
                  </label>
                  <input
                    type="date"
                    value={jdForm.effectiveFrom}
                    onChange={(e) => setJdForm({ ...jdForm, effectiveFrom: e.target.value })}
                    className="w-full px-3 py-2 border border-slate-200 rounded-xl text-xs"
                  />
                </div>
              </div>

              <div className="flex items-center justify-end gap-2 pt-4 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setModalType(null)}
                  className="px-4 py-2 border border-slate-200 text-slate-600 rounded-xl text-xs font-semibold uppercase"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="px-5 py-2 bg-indigo-600 text-white rounded-xl text-xs font-semibold uppercase tracking-wider flex items-center gap-1.5 hover:bg-indigo-700"
                >
                  {isSubmitting && <Loader2 size={14} className="animate-spin" />}
                  Publish JD Version
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* MODAL: SKILL FORM */}
      {/* ========================================================================= */}
      {modalType === 'SKILL' && (
        <div className="fixed inset-0 z-50 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-100 animate-in zoom-in-95 duration-200">
            <h3 className="text-lg font-bold text-slate-900 mb-4">
              {skillForm.id ? 'Edit Skill' : 'Add Skill to Catalog'}
            </h3>
            <form onSubmit={handleSaveSkill} className="space-y-4">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                  Skill Name *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. React.js, Financial Modeling, Conflict Resolution"
                  value={skillForm.name}
                  onChange={(e) => setSkillForm({ ...skillForm, name: e.target.value })}
                  className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                  Category
                </label>
                <select
                  value={skillForm.category}
                  onChange={(e) => setSkillForm({ ...skillForm, category: e.target.value })}
                  className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm bg-white"
                >
                  {SKILL_CATEGORIES.map((cat) => (
                    <option key={cat} value={cat}>
                      {cat}
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
                  placeholder="Proficiency scope or context..."
                  value={skillForm.description}
                  onChange={(e) => setSkillForm({ ...skillForm, description: e.target.value })}
                  className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm"
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setModalType(null)}
                  className="px-4 py-2 border border-slate-200 text-slate-600 rounded-xl text-xs font-semibold uppercase"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="px-5 py-2 bg-primary text-white rounded-xl text-xs font-semibold uppercase tracking-wider flex items-center gap-1.5"
                >
                  {isSubmitting && <Loader2 size={14} className="animate-spin" />}
                  Save Skill
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* MODAL: COMPETENCY FORM */}
      {/* ========================================================================= */}
      {modalType === 'COMPETENCY' && (
        <div className="fixed inset-0 z-50 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-lg w-full p-6 shadow-2xl border border-slate-100 animate-in zoom-in-95 duration-200">
            <h3 className="text-lg font-bold text-slate-900 mb-4">
              {competencyForm.id ? 'Edit Competency' : 'Define Competency'}
            </h3>
            <form onSubmit={handleSaveCompetency} className="space-y-4">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                  Competency Name *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Strategic Thinking, Customer Empathy"
                  value={competencyForm.name}
                  onChange={(e) => setCompetencyForm({ ...competencyForm, name: e.target.value })}
                  className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                  Description
                </label>
                <textarea
                  rows={2}
                  placeholder="Overview of this core competency..."
                  value={competencyForm.description}
                  onChange={(e) => setCompetencyForm({ ...competencyForm, description: e.target.value })}
                  className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm"
                />
              </div>

              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className="text-xs font-bold uppercase tracking-wider text-slate-500">
                    Observable Behaviors
                  </label>
                  <button
                    type="button"
                    onClick={() =>
                      setCompetencyForm({
                        ...competencyForm,
                        behaviors: [...competencyForm.behaviors, ''],
                      })
                    }
                    className="text-xs font-semibold text-indigo-600 hover:text-indigo-800"
                  >
                    + Add Behavior
                  </button>
                </div>
                <div className="space-y-2">
                  {competencyForm.behaviors.map((b, i) => (
                    <div key={i} className="flex items-center gap-2">
                      <input
                        type="text"
                        placeholder={`Behavior indicator #${i + 1}`}
                        value={b}
                        onChange={(e) => {
                          const next = [...competencyForm.behaviors];
                          next[i] = e.target.value;
                          setCompetencyForm({ ...competencyForm, behaviors: next });
                        }}
                        className="flex-1 px-3 py-1.5 border border-slate-200 rounded-lg text-xs"
                      />
                      {competencyForm.behaviors.length > 1 && (
                        <button
                          type="button"
                          onClick={() => {
                            const next = competencyForm.behaviors.filter((_, idx) => idx !== i);
                            setCompetencyForm({ ...competencyForm, behaviors: next });
                          }}
                          className="p-1 text-slate-400 hover:text-rose-500"
                        >
                          <Trash2 size={14} />
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setModalType(null)}
                  className="px-4 py-2 border border-slate-200 text-slate-600 rounded-xl text-xs font-semibold uppercase"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="px-5 py-2 bg-primary text-white rounded-xl text-xs font-semibold uppercase tracking-wider flex items-center gap-1.5"
                >
                  {isSubmitting && <Loader2 size={14} className="animate-spin" />}
                  Save Competency
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* MODAL: KPI FORM */}
      {/* ========================================================================= */}
      {modalType === 'KPI' && (
        <div className="fixed inset-0 z-50 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-100 animate-in zoom-in-95 duration-200">
            <h3 className="text-lg font-bold text-slate-900 mb-4">
              {kpiForm.id ? 'Edit KPI' : 'Define Key Performance Indicator'}
            </h3>
            <form onSubmit={handleSaveKPI} className="space-y-4">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                  KPI Name *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Customer Satisfaction Score, Sprint Velocity"
                  value={kpiForm.name}
                  onChange={(e) => setKpiForm({ ...kpiForm, name: e.target.value })}
                  className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                  Associated Job Role (Optional)
                </label>
                <select
                  value={kpiForm.jobRoleId}
                  onChange={(e) => setKpiForm({ ...kpiForm, jobRoleId: e.target.value })}
                  className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm bg-white"
                >
                  <option value="">Org-Wide / Cross-Functional</option>
                  {jobRoles.map((r) => (
                    <option key={r.id} value={r.id}>
                      {r.title} ({r.departmentName || 'General'})
                    </option>
                  ))}
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                    Metric Unit
                  </label>
                  <input
                    type="text"
                    placeholder="%, USD, score, count"
                    value={kpiForm.metricUnit}
                    onChange={(e) => setKpiForm({ ...kpiForm, metricUnit: e.target.value })}
                    className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                    Target Value
                  </label>
                  <input
                    type="text"
                    placeholder="e.g. 95, 100k"
                    value={kpiForm.targetValue}
                    onChange={(e) => setKpiForm({ ...kpiForm, targetValue: e.target.value })}
                    className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                  Evaluation Frequency
                </label>
                <select
                  value={kpiForm.frequency}
                  onChange={(e) => setKpiForm({ ...kpiForm, frequency: e.target.value })}
                  className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm bg-white"
                >
                  {KPI_FREQUENCIES.map((freq) => (
                    <option key={freq} value={freq}>
                      {freq}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">
                  Description / Metric Formula
                </label>
                <textarea
                  rows={2}
                  placeholder="Calculation details or criteria..."
                  value={kpiForm.description}
                  onChange={(e) => setKpiForm({ ...kpiForm, description: e.target.value })}
                  className="w-full px-3.5 py-2 border border-slate-200 rounded-xl text-sm"
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setModalType(null)}
                  className="px-4 py-2 border border-slate-200 text-slate-600 rounded-xl text-xs font-semibold uppercase"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="px-5 py-2 bg-primary text-white rounded-xl text-xs font-semibold uppercase tracking-wider flex items-center gap-1.5"
                >
                  {isSubmitting && <Loader2 size={14} className="animate-spin" />}
                  Save KPI
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* MODAL: ROLE REQUIREMENTS MAPPINGS (SKILLS & COMPETENCIES) */}
      {/* ========================================================================= */}
      {modalType === 'ROLE_MAPPINGS' && selectedRoleForReqs && (
        <div className="fixed inset-0 z-50 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-2xl w-full p-6 shadow-2xl border border-slate-100 max-h-[90vh] overflow-y-auto animate-in zoom-in-95 duration-200 space-y-6">
            <div>
              <h3 className="text-lg font-bold text-slate-900">
                Requirements Mapping: {selectedRoleForReqs.title}
              </h3>
              <p className="text-xs text-slate-500">
                Define the mandatory skills matrix and required competency levels (1-5) for this position.
              </p>
            </div>

            {/* Skills Requirements Section */}
            <div className="space-y-3">
              <div className="flex items-center justify-between border-b border-slate-100 pb-2">
                <h4 className="text-xs font-bold uppercase tracking-wider text-slate-700 flex items-center gap-1.5">
                  <Award size={14} className="text-indigo-600" /> Required Skills ({roleSkills.length})
                </h4>
                <div className="flex items-center gap-2">
                  <select
                    id="add-skill-select"
                    className="text-xs border border-slate-200 rounded-lg px-2 py-1 bg-white"
                    onChange={(e) => {
                      const skillId = e.target.value;
                      if (!skillId) return;
                      const s = skills.find((sk) => sk.id === skillId);
                      if (s && !roleSkills.some((rs) => rs.skillId === skillId)) {
                        setRoleSkills([
                          ...roleSkills,
                          {
                            id: 'temp-' + Date.now(),
                            jobRoleId: selectedRoleForReqs.id,
                            skillId: s.id,
                            skillName: s.name,
                            category: s.category,
                            requiredLevel: 3,
                            isMandatory: true,
                          },
                        ]);
                      }
                      e.target.value = '';
                    }}
                  >
                    <option value="">+ Add Skill...</option>
                    {skills
                      .filter((s) => !roleSkills.some((rs) => rs.skillId === s.id))
                      .map((s) => (
                        <option key={s.id} value={s.id}>
                          {s.name} ({s.category})
                        </option>
                      ))}
                  </select>
                </div>
              </div>

              <div className="space-y-2">
                {roleSkills.map((rs, idx) => (
                  <div
                    key={rs.skillId}
                    className="p-3 bg-slate-50 border border-slate-100 rounded-xl flex items-center justify-between gap-3 text-xs"
                  >
                    <div className="font-semibold text-slate-800">
                      {rs.skillName || skills.find((s) => s.id === rs.skillId)?.name || 'Skill'}
                      <span className="text-[10px] text-slate-400 block font-normal">
                        {rs.category || skills.find((s) => s.id === rs.skillId)?.category}
                      </span>
                    </div>

                    <div className="flex items-center gap-4">
                      <div className="flex items-center gap-1">
                        <span className="text-[10px] text-slate-400 uppercase font-bold">Level:</span>
                        <select
                          value={rs.requiredLevel}
                          onChange={(e) => {
                            const next = [...roleSkills];
                            next[idx].requiredLevel = Number(e.target.value);
                            setRoleSkills(next);
                          }}
                          className="border border-slate-200 rounded px-1.5 py-0.5 bg-white font-semibold text-indigo-700"
                        >
                          <option value={1}>1 - Beginner</option>
                          <option value={2}>2 - Intermediate</option>
                          <option value={3}>3 - Proficient</option>
                          <option value={4}>4 - Advanced</option>
                          <option value={5}>5 - Expert</option>
                        </select>
                      </div>

                      <label className="flex items-center gap-1.5 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={rs.isMandatory}
                          onChange={(e) => {
                            const next = [...roleSkills];
                            next[idx].isMandatory = e.target.checked;
                            setRoleSkills(next);
                          }}
                          className="rounded text-indigo-600 focus:ring-0"
                        />
                        <span className="text-[11px] text-slate-600 font-medium">Mandatory</span>
                      </label>

                      <button
                        onClick={() => setRoleSkills(roleSkills.filter((_, i) => i !== idx))}
                        className="p-1 text-slate-400 hover:text-rose-500"
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </div>
                ))}
                {roleSkills.length === 0 && (
                  <p className="text-xs text-slate-400 text-center py-2">No required skills mapped yet.</p>
                )}
              </div>
            </div>

            {/* Competency Requirements Section */}
            <div className="space-y-3">
              <div className="flex items-center justify-between border-b border-slate-100 pb-2">
                <h4 className="text-xs font-bold uppercase tracking-wider text-slate-700 flex items-center gap-1.5">
                  <BookOpen size={14} className="text-indigo-600" /> Expected Competencies (
                  {roleCompetencies.length})
                </h4>
                <select
                  className="text-xs border border-slate-200 rounded-lg px-2 py-1 bg-white"
                  onChange={(e) => {
                    const compId = e.target.value;
                    if (!compId) return;
                    const c = competencies.find((comp) => comp.id === compId);
                    if (c && !roleCompetencies.some((rc) => rc.competencyId === compId)) {
                      setRoleCompetencies([
                        ...roleCompetencies,
                        {
                          id: 'temp-' + Date.now(),
                          jobRoleId: selectedRoleForReqs.id,
                          competencyId: c.id,
                          competencyName: c.name,
                          expectedLevel: 3,
                        },
                      ]);
                    }
                    e.target.value = '';
                  }}
                >
                  <option value="">+ Add Competency...</option>
                  {competencies
                    .filter((c) => !roleCompetencies.some((rc) => rc.competencyId === c.id))
                    .map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                </select>
              </div>

              <div className="space-y-2">
                {roleCompetencies.map((rc, idx) => (
                  <div
                    key={rc.competencyId}
                    className="p-3 bg-slate-50 border border-slate-100 rounded-xl flex items-center justify-between gap-3 text-xs"
                  >
                    <div className="font-semibold text-slate-800">
                      {rc.competencyName ||
                        competencies.find((c) => c.id === rc.competencyId)?.name ||
                        'Competency'}
                    </div>

                    <div className="flex items-center gap-4">
                      <div className="flex items-center gap-1">
                        <span className="text-[10px] text-slate-400 uppercase font-bold">Level:</span>
                        <select
                          value={rc.expectedLevel}
                          onChange={(e) => {
                            const next = [...roleCompetencies];
                            next[idx].expectedLevel = Number(e.target.value);
                            setRoleCompetencies(next);
                          }}
                          className="border border-slate-200 rounded px-1.5 py-0.5 bg-white font-semibold text-indigo-700"
                        >
                          <option value={1}>1 - Developing</option>
                          <option value={2}>2 - Capable</option>
                          <option value={3}>3 - Solid Practitioner</option>
                          <option value={4}>4 - Role Model</option>
                          <option value={5}>5 - Visionary</option>
                        </select>
                      </div>

                      <button
                        onClick={() =>
                          setRoleCompetencies(roleCompetencies.filter((_, i) => i !== idx))
                        }
                        className="p-1 text-slate-400 hover:text-rose-500"
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </div>
                ))}
                {roleCompetencies.length === 0 && (
                  <p className="text-xs text-slate-400 text-center py-2">
                    No competencies mapped yet.
                  </p>
                )}
              </div>
            </div>

            <div className="flex items-center justify-end gap-2 pt-4 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setModalType(null)}
                className="px-4 py-2 border border-slate-200 text-slate-600 rounded-xl text-xs font-semibold uppercase"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleSaveMappings}
                disabled={isSubmitting}
                className="px-5 py-2 bg-indigo-600 text-white rounded-xl text-xs font-semibold uppercase tracking-wider flex items-center gap-1.5 hover:bg-indigo-700"
              >
                {isSubmitting && <Loader2 size={14} className="animate-spin" />}
                Save Requirements
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
