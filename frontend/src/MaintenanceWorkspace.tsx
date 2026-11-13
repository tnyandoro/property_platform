import { useEffect, useMemo, useState } from 'react'
import { CalendarDays, Check, ChevronDown, ChevronLeft, ChevronRight, Clock3, FileText, History, Plus, Search, Wrench, X } from 'lucide-react'
import { api, responseError } from './api'
import {
  activePropertyAssignments,
  calendarGridDates,
  filterMaintenanceRequests,
  localDateString,
  maintenanceCalendarEvents,
  maintenanceAssignee,
  maintenanceLocation,
  scheduleLocation,
  sortMaintenanceRequests,
  summarizeMaintenanceCosts,
} from './maintenance/logic'
import type {
  MaintenanceFinancialEntry,
  MaintenanceParty,
  MaintenancePortfolioContext,
  MaintenanceRequest,
  MaintenanceSchedule,
  MaintenanceView,
} from './maintenance/types'

const views: Array<{ id: MaintenanceView; label: string }> = [
  { id: 'overview', label: 'Overview' },
  { id: 'work_orders', label: 'Work orders' },
  { id: 'upcoming', label: 'Upcoming' },
  { id: 'in_progress', label: 'In progress' },
  { id: 'completed', label: 'Completed' },
  { id: 'history', label: 'History' },
  { id: 'costs', label: 'Costs' },
  { id: 'calendar', label: 'Calendar' },
  { id: 'schedules', label: 'Schedules' },
]

const categories = [
  'painting_decorating',
  'general_repairs',
  'plumbing_drainage',
  'electrical',
  'installations_replacements',
  'roofing_waterproofing',
  'structural_repairs',
  'fumigation_pest_control',
  'tree_pruning_landscaping',
  'cleaning_grounds_maintenance',
  'hvac_air_conditioning',
  'generator_pump_equipment_servicing',
  'security_systems',
  'compliance_safety',
  'preventative_maintenance',
  'improvements_upgrades',
  'other',
]

const classifications = [
  'undetermined',
  'wear_and_tear',
  'accidental_damage',
  'negligence',
  'misuse',
  'structural_deterioration',
  'preventative_maintenance',
  'breakdown',
  'improvement',
  'compliance_safety',
  'other',
]

const activeStatuses = ['open', 'acknowledged', 'awaiting_approval', 'approved', 'scheduled', 'in_progress']
const terminalStatuses = ['resolved', 'closed', 'rejected', 'cancelled']
const today = () => localDateString()
const readable = (value?: string | null) => value ? value.replace(/_/g, ' ') : 'Not recorded'
const money = (currency: string, value?: number | string | null) =>
  value == null || value === '' ? 'Not recorded' : `${currency} ${Number(value).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
const moneyTotals = (totals: Record<string, number>) =>
  Object.entries(totals).map(([currency, value]) => money(currency, value)).join(' · ') || 'Not recorded'

type Props = {
  propertyId: string
  portfolio: MaintenancePortfolioContext
}

export function MaintenanceWorkspace({ propertyId, portfolio }: Props) {
  const [requests, setRequests] = useState<MaintenanceRequest[]>([])
  const [schedules, setSchedules] = useState<MaintenanceSchedule[]>([])
  const [parties, setParties] = useState<MaintenanceParty[]>([])
  const [view, setView] = useState<MaintenanceView>('overview')
  const [calendarMonth, setCalendarMonth] = useState(() => {
    const current = new Date()
    return new Date(current.getFullYear(), current.getMonth(), 1)
  })
  const [calendarDate, setCalendarDate] = useState(today())
  const [calendarPresentation, setCalendarPresentation] = useState<'calendar' | 'list'>('calendar')
  const [selectedId, setSelectedId] = useState('')
  const [selectedRequest, setSelectedRequest] = useState<MaintenanceRequest | null>(null)
  const [search, setSearch] = useState('')
  const [sortBy, setSortBy] = useState<'scheduled' | 'reported' | 'priority' | 'cost'>('scheduled')
  const [loading, setLoading] = useState(true)
  const [detailLoading, setDetailLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [editing, setEditing] = useState<MaintenanceRequest | null>(null)
  const [editingSchedule, setEditingSchedule] = useState<MaintenanceSchedule | null>(null)
  const [showScheduleForm, setShowScheduleForm] = useState(false)
  const [partiesError, setPartiesError] = useState('')

  const context = useMemo(() => ({ ...portfolio, parties }), [portfolio, parties])
  const activeAssignments = useMemo(
    () => activePropertyAssignments(portfolio.assignments),
    [portfolio.assignments],
  )
  const summary = useMemo(() => summarizeMaintenanceCosts(requests), [requests])
  const visibleRequests = useMemo(() => sortMaintenanceRequests(
    filterMaintenanceRequests(requests, view, search, context),
    sortBy,
  ), [requests, view, search, context, sortBy])
  const activeRequests = requests.filter((request) => activeStatuses.includes(request.status))
  const overdueRequests = requests.filter((request) =>
    request.target_completion_on && request.target_completion_on < today()
      && !terminalStatuses.includes(request.status),
  )
  const upcomingRequests = requests.filter((request) => {
    const plannedDate = request.scheduled_on || request.target_completion_on
    return !!plannedDate && plannedDate >= today() && !terminalStatuses.includes(request.status)
  })
  const dueSchedules = schedules.filter((schedule) => schedule.status === 'active')
    .sort((a, b) => a.next_due_on.localeCompare(b.next_due_on))

  async function load(showSpinner = false): Promise<MaintenanceRequest[]> {
    if (showSpinner) setLoading(true)
    setError('')
    try {
      const [loadedRequests, loadedSchedules] = await Promise.all([
        api<MaintenanceRequest[]>(`/properties/${propertyId}/maintenance_requests`),
        api<MaintenanceSchedule[]>(`/properties/${propertyId}/maintenance_schedules`),
      ])
      setRequests(loadedRequests)
      setSchedules(loadedSchedules)
      return loadedRequests
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Maintenance data could not be loaded.')
      return []
    } finally {
      if (showSpinner) setLoading(false)
    }
  }

  useEffect(() => {
    let active = true
    setLoading(true)
    setSelectedId('')
    setSelectedRequest(null)
    Promise.all([
      api<MaintenanceRequest[]>(`/properties/${propertyId}/maintenance_requests`),
      api<MaintenanceSchedule[]>(`/properties/${propertyId}/maintenance_schedules`),
    ]).then(([loadedRequests, loadedSchedules]) => {
      if (!active) return
      setRequests(loadedRequests)
      setSchedules(loadedSchedules)
    }).catch((err: unknown) => {
      if (active) setError(err instanceof Error ? err.message : 'Maintenance data could not be loaded.')
    }).finally(() => {
      if (active) setLoading(false)
    })
    return () => { active = false }
  }, [propertyId])

  useEffect(() => {
    let active = true
    if (!selectedId) {
      setSelectedRequest(null)
      return () => { active = false }
    }
    setDetailLoading(true)
    api<MaintenanceRequest>(`/properties/${propertyId}/maintenance_requests/${selectedId}`)
      .then((request) => { if (active) setSelectedRequest(request) })
      .catch((err: unknown) => {
        if (active) setError(err instanceof Error ? err.message : 'Work-order details could not be loaded.')
      })
      .finally(() => { if (active) setDetailLoading(false) })
    return () => { active = false }
  }, [propertyId, selectedId])

  useEffect(() => {
    let active = true
    api<MaintenanceParty[]>('/parties')
      .then((loaded) => { if (active) setParties(loaded) })
      .catch((err: unknown) => {
        if (active) setPartiesError(err instanceof Error ? err.message : 'Service providers could not be loaded.')
      })
    return () => { active = false }
  }, [])

  async function refreshSelected(loadedRequests?: MaintenanceRequest[]) {
    const updated = loadedRequests?.find((request) => request.id === selectedId)
    if (updated) setSelectedRequest(updated)
    if (selectedId) {
      try {
        setSelectedRequest(await api<MaintenanceRequest>(
          `/properties/${propertyId}/maintenance_requests/${selectedId}`,
        ))
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Work-order details could not be refreshed.')
      }
    }
  }

  async function runAction(
    request: MaintenanceRequest,
    action: string,
    values: Record<string, unknown> = {},
    confirmation?: string,
  ): Promise<void> {
    if (confirmation && !window.confirm(confirmation)) return
    setSaving(true)
    setError('')
    setNotice('')
    try {
      await api<unknown>(
        `/properties/${propertyId}/maintenance_requests/${request.id}/${action}`,
        { method: 'POST', body: JSON.stringify(values) },
      )
      setNotice('Work order updated.')
      const loaded = await load()
      await refreshSelected(loaded)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'The work order could not be updated.')
    } finally {
      setSaving(false)
    }
  }

  async function saveRequest(payload: Record<string, FormDataEntryValue>, current?: MaintenanceRequest): Promise<void> {
    setSaving(true)
    setError('')
    setNotice('')
    try {
      const response = await api<MaintenanceRequest>(
        current
          ? `/properties/${propertyId}/maintenance_requests/${current.id}`
          : `/properties/${propertyId}/maintenance_requests`,
        {
          method: current ? 'PATCH' : 'POST',
          body: JSON.stringify({ maintenance_request: payload }),
        },
      )
      setShowForm(false)
      setEditing(null)
      setSelectedId(response.id)
      setNotice(current ? 'Work order saved.' : 'Work order created.')
      await load()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'The work order could not be saved.')
    } finally {
      setSaving(false)
    }
  }

  async function saveSchedule(payload: Record<string, FormDataEntryValue>, current?: MaintenanceSchedule): Promise<void> {
    setSaving(true)
    setError('')
    setNotice('')
    try {
      await api<MaintenanceSchedule>(
        current
          ? `/properties/${propertyId}/maintenance_schedules/${current.id}`
          : `/properties/${propertyId}/maintenance_schedules`,
        {
          method: current ? 'PATCH' : 'POST',
          body: JSON.stringify({ maintenance_schedule: payload }),
        },
      )
      setShowScheduleForm(false)
      setEditingSchedule(null)
      setNotice(current ? 'Maintenance plan saved.' : 'Maintenance plan created.')
      await load()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'The maintenance plan could not be saved.')
    } finally {
      setSaving(false)
    }
  }

  async function saveFinancialEntry(
    request: MaintenanceRequest,
    event: React.FormEvent<HTMLFormElement>,
  ): Promise<void> {
    event.preventDefault()
    const form = event.currentTarget
    const data = Object.fromEntries(new FormData(form).entries())
    const entryType = String(data.entry_type)
    const parameterName = entryType === 'quotation' ? 'quote' : entryType
    const route = entryType === 'quotation' ? 'quotes' : `${entryType}s`
    const { entry_type: _entryType, ...payload } = data

    setSaving(true)
    setError('')
    setNotice('')
    try {
      await api<MaintenanceFinancialEntry>(
        `/properties/${propertyId}/maintenance_requests/${request.id}/${route}`,
        { method: 'POST', body: JSON.stringify({ [parameterName]: payload }) },
      )
      form.reset()
      setNotice('Financial record saved.')
      const loaded = await load()
      await refreshSelected(loaded)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'The financial record could not be saved.')
    } finally {
      setSaving(false)
    }
  }

  async function uploadDocument(request: MaintenanceRequest, file?: File, documentType = 'other'): Promise<void> {
    if (!file) return
    if (file.size > 10 * 1024 * 1024) {
      setError('Choose a document that is 10 MiB or smaller.')
      return
    }
    const form = new FormData()
    form.append('file', file)
    form.append('document_type', documentType)
    form.append('title', file.name)
    setSaving(true)
    setError('')
    setNotice('')
    try {
      const token = localStorage.getItem('property_platform_token')
      const response = await fetch(
        `/api/v1/properties/${propertyId}/maintenance_requests/${request.id}/documents`,
        { method: 'POST', headers: token ? { Authorization: `Bearer ${token}` } : {}, body: form },
      )
      if (!response.ok) throw new Error(await responseError(response))
      setNotice('Evidence attached.')
      const loaded = await load()
      await refreshSelected(loaded)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'The document could not be uploaded.')
    } finally {
      setSaving(false)
    }
  }

  async function scheduleAction(schedule: MaintenanceSchedule, action: string): Promise<void> {
    const needsConfirmation = action === 'complete' || action === 'generate'
    if (needsConfirmation && !window.confirm(
      action === 'generate'
        ? 'Generate due work orders for this plan? Existing occurrences will not be duplicated.'
        : 'Complete this maintenance plan? This does not delete its work-order history.',
    )) return
    setSaving(true)
    setError('')
    setNotice('')
    try {
      await api<unknown>(
        `/properties/${propertyId}/maintenance_schedules/${schedule.id}/${action}`,
        { method: 'POST' },
      )
      setNotice(action === 'generate' ? 'Due work orders generated.' : 'Maintenance plan updated.')
      await load()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'The maintenance plan could not be updated.')
    } finally {
      setSaving(false)
    }
  }

  const rows = view === 'overview'
    ? sortMaintenanceRequests(requests, 'reported').slice(0, 5)
    : visibleRequests
  const activeSchedules = dueSchedules.slice(0, 5)

  return <section className="maintenance-workspace">
    <div className="maintenance-heading">
      <div><p className="eyebrow">Property operations</p><h3>Maintenance</h3></div>
      <div className="maintenance-actions">
        <button className="secondary-button" onClick={() => { setEditingSchedule(null); setShowScheduleForm(true) }}>
          <CalendarDays size={15} /> Plan work
        </button>
        <button className="primary-button" onClick={() => { setEditing(null); setShowForm(true) }}>
          <Plus size={15} /> New work order
        </button>
      </div>
    </div>

    <nav className="maintenance-nav" aria-label="Maintenance sections">
      {views.map((item) => <button
        type="button"
        key={item.id}
        className={view === item.id ? 'active' : ''}
        aria-current={view === item.id ? 'page' : undefined}
        onClick={() => setView(item.id)}
      >{item.label}</button>)}
    </nav>

    {error && <div className="maintenance-feedback error" role="alert">{error}<button type="button" onClick={() => void load(true)}>Retry</button><button aria-label="Dismiss error" onClick={() => setError('')}><X size={14} /></button></div>}
    {notice && <div className="maintenance-feedback success" role="status"><Check size={14} />{notice}<button aria-label="Dismiss message" onClick={() => setNotice('')}><X size={14} /></button></div>}

    {loading ? <div className="detail-loading"><div className="spinner" /> Loading maintenance</div> : <>
      {view === 'overview' && <Overview
        requests={requests}
        schedules={activeSchedules}
        summary={summary}
        context={context}
        parties={parties}
        overdueCount={overdueRequests.length}
        activeCount={activeRequests.length}
        upcomingCount={upcomingRequests.length}
        onView={setView}
        onScheduleAction={scheduleAction}
      />}

      {view === 'costs' && <CostOverview requests={requests} summary={summary} />}

      {view === 'schedules' && <ScheduleList
        schedules={schedules}
        context={context}
        parties={parties}
        saving={saving}
        onEdit={(schedule) => { setEditingSchedule(schedule); setShowScheduleForm(true) }}
        onAction={scheduleAction}
      />}

      {view === 'calendar' && <MaintenanceCalendar
        requests={requests}
        schedules={schedules}
        context={context}
        month={calendarMonth}
        selectedDate={calendarDate}
        presentation={calendarPresentation}
        selectedId={selectedId}
        onMonthChange={(offset) => setCalendarMonth((current) =>
          new Date(current.getFullYear(), current.getMonth() + offset, 1),
        )}
        onDateChange={(date) => {
          if (!date) return
          setCalendarDate(date)
          const [year, month] = date.split('-').map(Number)
          setCalendarMonth(new Date(year, month - 1, 1))
        }}
        onToday={() => {
          const current = new Date()
          setCalendarDate(today())
          setCalendarMonth(new Date(current.getFullYear(), current.getMonth(), 1))
        }}
        onPresentationChange={setCalendarPresentation}
        onSelectRequest={(request) => setSelectedId(request.id)}
        onSelectSchedule={(schedule) => {
          setSelectedId('')
          setEditingSchedule(schedule)
          setShowScheduleForm(true)
        }}
      />}

      {view !== 'overview' && view !== 'costs' && view !== 'calendar' && view !== 'schedules' && <>
        <div className="maintenance-toolbar">
          <label className="maintenance-search"><Search size={16} /><input
            aria-label="Search work orders"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search title, location, assignment"
          /></label>
          <label className="maintenance-sort">Sort by
            <select value={sortBy} onChange={(event) => setSortBy(event.target.value as typeof sortBy)}>
              <option value="scheduled">Scheduled date</option>
              <option value="reported">Recently reported</option>
              <option value="priority">Priority</option>
              <option value="cost">Highest cost</option>
            </select>
          </label>
        </div>
        <WorkOrderList
          requests={rows}
          context={context}
          parties={parties}
          selectedId={selectedId}
          onSelect={(request) => setSelectedId(request.id)}
          emptyLabel={view === 'upcoming' ? 'No upcoming scheduled work orders.' : 'No work orders match this view.'}
        />
        {view === 'upcoming' && <section className="maintenance-section"><SectionHeading title="Recurring maintenance due" action="View plans" onAction={() => setView('schedules')} /><ScheduleList
          compact
          schedules={dueSchedules.filter((schedule) => schedule.next_due_on >= today())}
          context={context}
          parties={parties}
          saving={saving}
          onEdit={(schedule) => { setEditingSchedule(schedule); setShowScheduleForm(true) }}
          onAction={scheduleAction}
        /></section>}
      </>}

      {view === 'overview' && <section className="maintenance-section">
        <SectionHeading title="Recent work orders" action="View all" onAction={() => setView('work_orders')} />
        <WorkOrderList
          requests={rows}
          context={context}
          parties={parties}
          selectedId={selectedId}
          onSelect={(request) => setSelectedId(request.id)}
          emptyLabel="No maintenance work orders yet."
        />
        <SectionHeading title="Upcoming maintenance plans" action="View plans" onAction={() => setView('schedules')} />
        <ScheduleList
          compact
          schedules={activeSchedules}
          context={context}
          parties={parties}
          saving={saving}
          onEdit={(schedule) => { setEditingSchedule(schedule); setShowScheduleForm(true) }}
          onAction={scheduleAction}
        />
      </section>}

      {selectedId && <div className="maintenance-detail-wrap">
        {detailLoading || !selectedRequest
          ? <div className="detail-loading"><div className="spinner" /> Loading work-order details</div>
          : <MaintenanceRequestDetails
            propertyId={propertyId}
            request={selectedRequest}
            context={context}
            parties={parties}
            assignments={activeAssignments}
            saving={saving}
            onEdit={() => { setEditing(selectedRequest); setShowForm(true) }}
            onAction={runAction}
            onUpload={uploadDocument}
            onFinancialEntry={saveFinancialEntry}
          />}
      </div>}
    </>}

    {showForm && <WorkOrderForm
      propertyId={propertyId}
      request={editing || undefined}
      portfolio={context}
      parties={parties}
      saving={saving}
      onClose={() => { setShowForm(false); setEditing(null) }}
      onSave={(payload) => saveRequest(payload, editing || undefined)}
    />}
    {showScheduleForm && <ScheduleForm
      schedule={editingSchedule || undefined}
      portfolio={context}
      parties={parties}
      saving={saving}
      onClose={() => { setShowScheduleForm(false); setEditingSchedule(null) }}
      onSave={(payload) => saveSchedule(payload, editingSchedule || undefined)}
    />}
  </section>
}

function Overview({
  requests,
  schedules,
  summary,
  context,
  parties,
  overdueCount,
  activeCount,
  upcomingCount,
  onView,
  onScheduleAction,
}: {
  requests: MaintenanceRequest[]
  schedules: MaintenanceSchedule[]
  summary: ReturnType<typeof summarizeMaintenanceCosts>
  context: MaintenancePortfolioContext
  parties: MaintenanceParty[]
  overdueCount: number
  activeCount: number
  upcomingCount: number
  onView: (view: MaintenanceView) => void
  onScheduleAction: (schedule: MaintenanceSchedule, action: string) => void
}) {
  const completedCount = requests.filter((request) => ['resolved', 'closed'].includes(request.status)).length
  const nextSchedule = schedules[0]
  return <>
    <div className="maintenance-metrics">
      <Metric label="Work orders" value={String(requests.length)} onClick={() => onView('work_orders')} />
      <Metric label="Active" value={String(activeCount)} onClick={() => onView('work_orders')} />
      <Metric label="Overdue" value={String(overdueCount)} tone={overdueCount ? 'warning' : undefined} onClick={() => onView('work_orders')} />
      <Metric label="Upcoming" value={String(upcomingCount + schedules.filter((schedule) => schedule.next_due_on >= today()).length)} onClick={() => onView('upcoming')} />
      <Metric label="Completed" value={String(completedCount)} onClick={() => onView('completed')} />
      <Metric label="Actual spend" value={moneyTotals(summary.actual)} onClick={() => onView('costs')} />
    </div>
    <div className="maintenance-financial-strip" aria-label="Maintenance financial summary">
      <div><span>Estimated</span><strong>{moneyTotals(summary.estimates)}</strong></div>
      <div><span>Approved</span><strong>{moneyTotals(summary.approved)}</strong></div>
      <div><span>Paid</span><strong>{moneyTotals(summary.paid)}</strong></div>
      <div><span>Invoice balance outstanding</span><strong>{moneyTotals(summary.outstanding)}</strong></div>
    </div>
    {nextSchedule && <div className="maintenance-next-due">
      <CalendarDays size={18} />
      <div><span>Next maintenance plan due</span><strong>{nextSchedule.title}</strong><small>{nextSchedule.next_due_on} · {scheduleLocation(nextSchedule, context)}</small></div>
      <button className="secondary-button" onClick={() => onScheduleAction(nextSchedule, 'generate')}>Generate due work</button>
    </div>}
    <div className="maintenance-overview-links">
      <button onClick={() => onView('upcoming')}><CalendarDays size={17} /><span>Upcoming maintenance</span></button>
      <button onClick={() => onView('in_progress')}><Wrench size={17} /><span>In-progress work</span></button>
      <button onClick={() => onView('history')}><History size={17} /><span>Maintenance history</span></button>
    </div>
    {requests.length === 0 && <EmptyMaintenance message="There are no work orders for this property yet. Create one to start tracking maintenance." />}
    {parties.length === 0 && requests.length > 0 && <p className="maintenance-muted">Service-provider directory is empty.</p>}
    {schedules.length === 0 && <p className="maintenance-muted">No recurring maintenance plans are recorded.</p>}
    <p className="maintenance-disclaimer">Financial totals remain separated by currency. Payments are counted as paid only when their recorded status is paid.</p>
    <span className="sr-only">{completedCount} completed work orders</span>
  </>
}

function Metric({ label, value, tone, onClick }: { label: string; value: string; tone?: 'warning'; onClick: () => void }) {
  return <button type="button" className={`maintenance-metric ${tone || ''}`} onClick={onClick}>
    <span>{label}</span><strong>{value}</strong>
  </button>
}

function CostOverview({ requests, summary }: {
  requests: MaintenanceRequest[]
  summary: ReturnType<typeof summarizeMaintenanceCosts>
}) {
  const allocations = new Map<string, Record<string, number>>()
  requests.forEach((request) => request.cost_allocations.forEach((allocation) => {
    if (allocation.status !== 'approved') return
    const bucket = allocations.get(allocation.currency) || {}
    bucket[allocation.responsible_party] = (bucket[allocation.responsible_party] || 0) + Number(allocation.allocated_amount)
    allocations.set(allocation.currency, bucket)
  }))

  return <section className="maintenance-section">
    <div className="maintenance-cost-grid">
      {[
        ['Estimated', summary.estimates],
        ['Approved', summary.approved],
        ['Actual', summary.actual],
        ['Paid', summary.paid],
        ['Outstanding invoices', summary.outstanding],
      ].map(([label, values]) => <div className="maintenance-cost-card" key={label as string}>
        <span>{label as string}</span>
        <strong>{moneyTotals(values as Record<string, number>)}</strong>
      </div>)}
    </div>
    <section className="maintenance-record-list">
      <h4>Approved responsibility allocations</h4>
      {allocations.size
        ? [...allocations.entries()].map(([currency, values]) => <div className="maintenance-allocation-summary" key={currency}>
          <strong>{currency}</strong>
          {Object.entries(values).map(([party, amount]) => <p key={party}>{readable(party)} <span>{money(currency, amount)}</span></p>)}
        </div>)
        : <EmptyMaintenance message="No approved cost allocations have been recorded." />}
    </section>
    <p className="maintenance-disclaimer">Estimates, approved amounts, actual costs, payments, and invoice balances are shown as separate facts. Amounts in different currencies are never combined.</p>
  </section>
}

function SectionHeading({ title, action, onAction }: { title: string; action: string; onAction: () => void }) {
  return <div className="maintenance-section-heading"><h4>{title}</h4><button type="button" onClick={onAction}>{action}<ChevronDown size={14} /></button></div>
}

function WorkOrderList({
  requests,
  context,
  parties,
  selectedId,
  onSelect,
  emptyLabel,
}: {
  requests: MaintenanceRequest[]
  context: MaintenancePortfolioContext
  parties: MaintenanceParty[]
  selectedId: string
  onSelect: (request: MaintenanceRequest) => void
  emptyLabel: string
}) {
  if (!requests.length) return <EmptyMaintenance message={emptyLabel} />
  return <div className="maintenance-table-wrap">
    <table className="maintenance-table">
      <thead><tr>
        <th>Work order</th><th>Location</th><th>Priority / status</th><th>Scheduled</th><th>Assigned</th><th>Cost</th><th>Classification / responsibility</th>
      </tr></thead>
      <tbody>{requests.map((request) => <tr key={request.id} className={selectedId === request.id ? 'selected' : ''}>
        <td data-label="Work order"><button className="maintenance-row-link" onClick={() => onSelect(request)}><strong>{request.title}</strong><small>{readable(request.category)}</small></button></td>
        <td data-label="Location">{maintenanceLocation(request, context)}</td>
        <td data-label="Priority / status"><span className={`maintenance-priority ${request.priority}`}>{readable(request.priority)}</span><small className={`maintenance-status status-${request.status}`}>{readable(request.status)}</small></td>
        <td data-label="Scheduled">{request.scheduled_on || 'Not scheduled'}</td>
        <td data-label="Assigned">{maintenanceAssignee(request, context, parties)}</td>
        <td data-label="Cost"><span>{money(request.currency, request.estimated_cost)}</span><small>Actual: {money(request.currency, request.actual_cost)}</small></td>
        <td data-label="Classification / responsibility"><span>{readable(request.classification)}</span><small>{readable(request.responsibility_status)} · {readable(request.suggested_responsibility)}</small></td>
      </tr>)}</tbody>
    </table>
  </div>
}

function MaintenanceCalendar({
  requests,
  schedules,
  context,
  month,
  selectedDate,
  presentation,
  selectedId,
  onMonthChange,
  onDateChange,
  onToday,
  onPresentationChange,
  onSelectRequest,
  onSelectSchedule,
}: {
  requests: MaintenanceRequest[]
  schedules: MaintenanceSchedule[]
  context: MaintenancePortfolioContext
  month: Date
  selectedDate: string
  presentation: 'calendar' | 'list'
  selectedId: string
  onMonthChange: (offset: number) => void
  onDateChange: (date: string) => void
  onToday: () => void
  onPresentationChange: (presentation: 'calendar' | 'list') => void
  onSelectRequest: (request: MaintenanceRequest) => void
  onSelectSchedule: (schedule: MaintenanceSchedule) => void
}) {
  const days = calendarGridDates(month)
  const todayDate = localDateString()
  const monthLabel = month.toLocaleDateString(undefined, { month: 'long', year: 'numeric' })
  const events = maintenanceCalendarEvents(requests, schedules, month, todayDate)
  const eventsByDate = new Map<string, typeof events>()
  events.forEach((event) => {
    eventsByDate.set(event.date, [...(eventsByDate.get(event.date) || []), event])
  })

  function eventButton(event: typeof events[number]) {
    const location = event.request
      ? maintenanceLocation(event.request, context)
      : event.schedule ? scheduleLocation(event.schedule, context) : ''
    return <button
      type="button"
      key={event.id}
      className={`maintenance-calendar-event ${event.kind} ${event.status} ${selectedId === event.request?.id ? 'selected' : ''}`}
      aria-label={`${event.title}, ${readable(event.status)}, ${event.kind === 'work_order' ? 'work order' : 'maintenance plan'}`}
      onClick={() => event.request ? onSelectRequest(event.request) : event.schedule && onSelectSchedule(event.schedule)}
    >
      <strong>{event.title}</strong>
      <small>{readable(event.status)}{location ? ` · ${location}` : ''}{event.schedule?.target_completion_on ? ` · complete by ${event.schedule.target_completion_on}` : ''}</small>
    </button>
  }

  return <section className="maintenance-calendar" aria-label="Maintenance calendar">
    <div className="maintenance-calendar-toolbar">
      <div className="maintenance-calendar-navigation">
        <button type="button" className="secondary-button" aria-label="Previous month" onClick={() => onMonthChange(-1)}><ChevronLeft size={16} /></button>
        <h4 aria-live="polite">{monthLabel}</h4>
        <button type="button" className="secondary-button" aria-label="Next month" onClick={() => onMonthChange(1)}><ChevronRight size={16} /></button>
        <button type="button" className="secondary-button" onClick={onToday}>Today</button>
      </div>
      <div className="maintenance-calendar-mode" role="group" aria-label="Calendar presentation">
        <button type="button" aria-pressed={presentation === 'calendar'} className={presentation === 'calendar' ? 'active' : ''} onClick={() => onPresentationChange('calendar')}>Month</button>
        <button type="button" aria-pressed={presentation === 'list'} className={presentation === 'list' ? 'active' : ''} onClick={() => onPresentationChange('list')}>List</button>
      </div>
      <label className="maintenance-calendar-date-picker">Go to date<input type="date" value={selectedDate} onChange={(event) => onDateChange(event.target.value)} /></label>
    </div>

    {events.length === 0 && <EmptyMaintenance message={`No scheduled maintenance in ${monthLabel}.`} />}

    {presentation === 'calendar' && <div className="maintenance-calendar-grid" role="grid" aria-label={monthLabel}>
      {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((day) =>
        <span className="maintenance-calendar-weekday" role="columnheader" key={day}>{day}</span>,
      )}
      {days.map((day) => {
        const date = localDateString(day)
        const dateEvents = eventsByDate.get(date) || []
        return <div
          className={`maintenance-calendar-day ${day.getMonth() === month.getMonth() ? '' : 'outside-month'} ${date === todayDate ? 'today' : ''} ${date === selectedDate ? 'selected-date' : ''}`}
          role="gridcell"
          aria-label={`${date}, ${dateEvents.length} maintenance items`}
          key={date}
        >
          <span className="maintenance-calendar-date">{day.getDate()}</span>
          <div className="maintenance-calendar-day-events">
            {dateEvents.slice(0, 3).map(eventButton)}
            {dateEvents.length > 3 && <span className="maintenance-calendar-more">+{dateEvents.length - 3} more</span>}
          </div>
        </div>
      })}
    </div>}

    {presentation === 'list' && events.length > 0 && <div className="maintenance-calendar-list">
      {events.map((event) => <div className="maintenance-calendar-list-row" key={event.id}>
        <time dateTime={event.date}>{dateFromCalendarKey(event.date)}</time>
        {eventButton(event)}
      </div>)}
    </div>}
  </section>
}

function dateFromCalendarKey(value: string): string {
  const [year, month, day] = value.split('-').map(Number)
  return new Date(year, month - 1, day).toLocaleDateString(undefined, {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })
}

function ScheduleList({
  schedules,
  context,
  parties,
  saving,
  compact = false,
  onEdit,
  onAction,
}: {
  schedules: MaintenanceSchedule[]
  context: MaintenancePortfolioContext
  parties: MaintenanceParty[]
  saving: boolean
  compact?: boolean
  onEdit: (schedule: MaintenanceSchedule) => void
  onAction: (schedule: MaintenanceSchedule, action: string) => void
}) {
  if (!schedules.length) return <EmptyMaintenance message="No maintenance plans are recorded." />
  return <div className="maintenance-schedule-list">
    {schedules.map((schedule) => {
      const assignee = context.assignments.find((entry) => entry.user.id === schedule.assigned_to_id)?.user.name
      const contractor = parties.find((party) => party.id === schedule.contractor_id)?.name
      return <article className="maintenance-schedule-card" key={schedule.id}>
        <div className="maintenance-schedule-info">
          <div className="maintenance-schedule-title"><strong>{schedule.title}</strong><span className={`maintenance-status status-${schedule.status}`}>{readable(schedule.status)}</span></div>
          <p>{readable(schedule.category)} · {readable(schedule.frequency)} · next due {schedule.next_due_on}</p>
          <small>{scheduleLocation(schedule, context)} · {assignee || contractor || 'Unassigned'} · {readable(schedule.generation_mode)}</small>
          {schedule.target_completion_on && <small>Target completion {schedule.target_completion_on}</small>}
          {!compact && <small>{readable(schedule.classification)} · {money(schedule.currency, schedule.estimated_cost)} estimated</small>}
        </div>
        <div className="maintenance-schedule-actions">
          {schedule.status !== 'completed' && <button className="secondary-button" disabled={saving} onClick={() => onEdit(schedule)}>Edit</button>}
          {schedule.status === 'active' && <button className="secondary-button" disabled={saving} onClick={() => onAction(schedule, 'pause')}>Pause</button>}
          {schedule.status === 'paused' && <button className="secondary-button" disabled={saving} onClick={() => onAction(schedule, 'resume')}>Resume</button>}
          {schedule.status === 'active' && <button className="secondary-button" disabled={saving} onClick={() => onAction(schedule, 'generate')}>Generate due</button>}
          {schedule.status !== 'completed' && <button className="secondary-button" disabled={saving} onClick={() => onAction(schedule, 'complete')}>Complete plan</button>}
        </div>
      </article>
    })}
  </div>
}

function EmptyMaintenance({ message }: { message: string }) {
  return <div className="maintenance-empty"><Wrench size={20} /><p>{message}</p></div>
}

function WorkOrderForm({
  propertyId,
  request,
  portfolio,
  parties,
  saving,
  onClose,
  onSave,
}: {
  propertyId: string
  request?: MaintenanceRequest
  portfolio: MaintenancePortfolioContext
  parties: MaintenanceParty[]
  saving: boolean
  onClose: () => void
  onSave: (payload: Record<string, FormDataEntryValue>) => void
}) {
  const [unitId, setUnitId] = useState(request?.unit_id || '')
  const [roomId, setRoomId] = useState(request?.room_id || '')
  const [leaseId, setLeaseId] = useState(request?.lease_id || '')
  const [sourceInspectionId, setSourceInspectionId] = useState(request?.source_inspection_id || '')
  const [inspectionItems, setInspectionItems] = useState<Array<{ id: string; label: string }>>([])
  const [inspectionItemsLoading, setInspectionItemsLoading] = useState(false)
  const [inspectionItemsError, setInspectionItemsError] = useState('')
  const selectedUnit = portfolio.units.find((unit) => unit.id === unitId)
  const rooms = portfolio.rooms.filter((room) => !unitId || room.unit_id === unitId)
  const leases = portfolio.leases.filter((lease) => !unitId || lease.unit_id === unitId)
  const activeAssignments = activePropertyAssignments(portfolio.assignments)
  const portfolioCurrencies = [...new Set((portfolio.maintenance || [])
    .map((item) => item.currency)
    .filter((currency): currency is string => !!currency))]
  const currentCurrency = request?.currency || (portfolioCurrencies.length === 1 ? portfolioCurrencies[0] : '')

  useEffect(() => {
    let active = true
    if (!sourceInspectionId) {
      setInspectionItems([])
      setInspectionItemsError('')
      return () => { active = false }
    }

    setInspectionItemsLoading(true)
    setInspectionItemsError('')
    api<{ rooms: Array<{ room_name: string; items: Array<{ id: string; item_name: string }> }> }>(
      `/properties/${propertyId}/inspections/${sourceInspectionId}`,
    ).then((detail) => {
      if (!active) return
      setInspectionItems(detail.rooms.flatMap((room) => room.items.map((item) => ({
        id: item.id,
        label: `${room.room_name} · ${item.item_name}`,
      }))))
    }).catch((err: unknown) => {
      if (active) setInspectionItemsError(err instanceof Error ? err.message : 'Inspection findings could not be loaded.')
    }).finally(() => {
      if (active) setInspectionItemsLoading(false)
    })
    return () => { active = false }
  }, [propertyId, sourceInspectionId])

  function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const data = Object.fromEntries(new FormData(event.currentTarget).entries())
    onSave(data)
  }

  return <div className="modal-backdrop" onClick={onClose}>
    <form className="modal maintenance-modal maintenance-edit-form" onClick={(event) => event.stopPropagation()} onSubmit={submit}>
      <div className="modal-header"><div><p className="eyebrow">Maintenance work order</p><h2>{request ? 'Edit work order' : 'New work order'}</h2></div><button type="button" className="icon-button" aria-label="Close form" onClick={onClose}><X size={18} /></button></div>
      <fieldset><legend>Work details</legend>
        <label>Title<input name="title" required maxLength={255} defaultValue={request?.title || ''} /></label>
        <label>Description / supporting notes<textarea name="description" rows={3} defaultValue={request?.description || ''} /></label>
        <div className="form-grid">
          <label>Category<select name="category" defaultValue={request?.category || 'general_repairs'}>{categories.map((value) => <option value={value} key={value}>{readable(value)}</option>)}</select></label>
          <label>Priority<select name="priority" defaultValue={request?.priority || 'medium'}>{['low', 'medium', 'high', 'urgent'].map((value) => <option value={value} key={value}>{readable(value)}</option>)}</select></label>
        </div>
        <div className="form-grid">
          <label>Unit / location<select name="unit_id" value={unitId} onChange={(event) => { setUnitId(event.target.value); setRoomId(''); setLeaseId('') }}><option value="">Property-wide</option>{portfolio.units.map((unit) => <option value={unit.id} key={unit.id}>{unit.unit_number || unit.name || 'Unit'}{unit.name && selectedUnit?.id !== unit.id ? ` · ${unit.name}` : ''}</option>)}</select></label>
          <label>Room<select name="room_id" value={roomId} onChange={(event) => setRoomId(event.target.value)}><option value="">No specific room</option>{rooms.map((room) => <option value={room.id} key={room.id}>{room.room_name}</option>)}</select></label>
        </div>
        {portfolio.items.length > 0 && <p className="maintenance-form-hint">For an asset-specific issue, identify the asset in the description; work orders currently link to property, unit and room.</p>}
      </fieldset>
      <fieldset><legend>Scheduling</legend>
        <p className="maintenance-form-hint">Requested date is recorded automatically when the work order is submitted.</p>
        <div className="form-grid">
          <label>Scheduled date<input name="scheduled_on" type="date" defaultValue={request?.scheduled_on || ''} /></label>
          <label>Target completion<input name="target_completion_on" type="date" defaultValue={request?.target_completion_on || ''} /></label>
        </div>
      </fieldset>
      <fieldset><legend>Classification</legend>
        <label>Work classification<select name="classification" defaultValue={request?.classification || 'undetermined'}>{classifications.map((value) => <option value={value} key={value}>{readable(value)}</option>)}</select></label>
        <p className="maintenance-form-hint">Classification describes the work. It does not determine who pays.</p>
      </fieldset>
      <fieldset><legend>Financial responsibility</legend>
        <div className="maintenance-responsibility-note">
          <strong>{request ? readable(request.responsibility_status) : 'Pending review'}</strong>
          <span>{request ? `Suggested: ${readable(request.suggested_responsibility)}` : 'Responsibility is reviewed and approved separately from classification.'}</span>
        </div>
      </fieldset>
      <fieldset><legend>Financial information</legend>
        <div className="form-grid">
          <label>Estimated cost<input name="estimated_cost" type="number" min="0" step="0.01" defaultValue={request?.estimated_cost ?? ''} /></label>
          <label>Currency<input name="currency" required minLength={3} maxLength={3} pattern="[A-Za-z]{3}" title="Enter a three-letter currency code" defaultValue={currentCurrency} /></label>
        </div>
        {request && <div className="maintenance-financial-strip compact">
          <div><span>Approved</span><strong>{money(request.currency, request.approved_cost)}</strong></div>
          <div><span>Actual</span><strong>{money(request.currency, request.actual_cost)}</strong></div>
          <div><span>Paid</span><strong>{money(request.currency, request.financial_entries.filter((entry) => entry.entry_type === 'payment' && entry.status === 'paid').reduce((total, entry) => total + Number(entry.amount), 0))}</strong></div>
        </div>}
      </fieldset>
      <fieldset><legend>Assignment and source</legend>
        <div className="form-grid">
          <label>Internal assignee<select name="assigned_to_id" defaultValue={request?.assigned_to_id || ''}><option value="">Unassigned</option>{activeAssignments.map((assignment) => <option value={assignment.user.id} key={assignment.id}>{assignment.user.name} · {readable(assignment.assignment_type)}</option>)}</select></label>
          <label>Contractor / service provider<select name="contractor_id" defaultValue={request?.contractor_id || ''}><option value="">Not assigned</option>{parties.map((party) => <option value={party.id} key={party.id}>{party.name} · {party.party_type}</option>)}</select></label>
        </div>
        <div className="form-grid">
          <label>Relevant lease<select name="lease_id" value={leaseId} onChange={(event) => setLeaseId(event.target.value)}><option value="">No linked lease</option>{leases.map((lease) => <option value={lease.id} key={lease.id}>{lease.tenant_name} · {lease.start_date}–{lease.end_date || 'current'}</option>)}</select></label>
          <label>Work source<select name="source_type" defaultValue={request?.source_type || 'manager'}>{['tenant_request', 'schedule', 'inspection', 'damage_assessment', 'manager', 'other'].map((value) => <option key={value} value={value}>{readable(value)}</option>)}</select></label>
        </div>
        <div className="form-grid">
          <label>Inspection<select name="source_inspection_id" value={sourceInspectionId} onChange={(event) => setSourceInspectionId(event.target.value)}><option value="">No linked inspection</option>{portfolio.inspections.map((inspection) => <option value={inspection.id} key={inspection.id}>{readable(inspection.inspection_type)} · {inspection.inspected_on || inspection.scheduled_on || 'Date not recorded'}</option>)}</select></label>
          <label>Damage assessment<select name="source_damage_assessment_id" defaultValue={request?.source_damage_assessment_id || ''}><option value="">No linked assessment</option>{portfolio.damage_assessments.map((assessment) => <option value={assessment.id} key={assessment.id}>{readable(assessment.severity)} · {assessment.description.slice(0, 55)}</option>)}</select></label>
        </div>
        {sourceInspectionId && <label>Inspection finding<select name="source_inspection_item_id" defaultValue={request?.source_inspection_item_id || ''}><option value="">Whole inspection</option>{inspectionItems.map((item) => <option key={item.id} value={item.id}>{item.label}</option>)}</select></label>}
        {inspectionItemsLoading && <p className="maintenance-form-hint" role="status">Loading inspection findings...</p>}
        {inspectionItemsError && <p className="maintenance-form-hint error" role="alert">{inspectionItemsError}</p>}
        {parties.length === 0 && <p className="maintenance-form-hint" role="status">No party or contractor records are available.</p>}
      </fieldset>
      {request && <p className="maintenance-form-hint">Requested {new Date(request.reported_at).toLocaleString()} · Approved amount, quotations, invoices and payments are retained as separate records.</p>}
      <div className="modal-actions"><button type="button" className="secondary-button" onClick={onClose}>Cancel</button><button className="primary-button" disabled={saving}>{saving ? 'Saving...' : request ? 'Save changes' : 'Create work order'}</button></div>
    </form>
  </div>
}

function ScheduleForm({
  schedule,
  portfolio,
  parties,
  saving,
  onClose,
  onSave,
}: {
  schedule?: MaintenanceSchedule
  portfolio: MaintenancePortfolioContext
  parties: MaintenanceParty[]
  saving: boolean
  onClose: () => void
  onSave: (payload: Record<string, FormDataEntryValue>) => void
}) {
  const [frequency, setFrequency] = useState(schedule?.frequency || 'quarterly')
  const [nextDueOn, setNextDueOn] = useState(schedule?.next_due_on || today())

  function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    onSave(Object.fromEntries(new FormData(event.currentTarget).entries()))
  }
  const portfolioCurrencies = [...new Set((portfolio.maintenance || [])
    .map((item) => item.currency)
    .filter((currency): currency is string => !!currency))]
  const defaultCurrency = schedule?.currency || (portfolioCurrencies.length === 1 ? portfolioCurrencies[0] : '')
  return <div className="modal-backdrop" onClick={onClose}>
    <form className="modal maintenance-modal maintenance-edit-form" onClick={(event) => event.stopPropagation()} onSubmit={submit}>
      <div className="modal-header"><div><p className="eyebrow">{frequency === 'once' ? 'One-time maintenance' : 'Recurring maintenance'}</p><h2>{schedule ? 'Edit maintenance plan' : 'Create maintenance plan'}</h2></div><button type="button" className="icon-button" aria-label="Close form" onClick={onClose}><X size={18} /></button></div>
      <fieldset><legend>Plan details</legend>
        <label>Title<input name="title" required defaultValue={schedule?.title || ''} /></label>
        <label>Description<textarea name="description" rows={2} defaultValue={schedule?.description || ''} /></label>
        <div className="form-grid">
          <label>Category<select name="category" defaultValue={schedule?.category || 'preventative_maintenance'}>{categories.map((value) => <option value={value} key={value}>{readable(value)}</option>)}</select></label>
          <label>Priority<select name="priority" defaultValue={schedule?.priority || 'medium'}>{['low', 'medium', 'high', 'urgent'].map((value) => <option key={value}>{value}</option>)}</select></label>
        </div>
        <label>Classification<select name="classification" defaultValue={schedule?.classification || 'undetermined'}>{classifications.map((value) => <option value={value} key={value}>{readable(value)}</option>)}</select></label>
        <label>Suggested responsibility<select name="suggested_responsibility" defaultValue={schedule?.suggested_responsibility || 'unknown'}>{['owner', 'tenant', 'shared', 'organization', 'third_party', 'unknown', 'other', 'pending'].map((value) => <option value={value} key={value}>{readable(value)}</option>)}</select></label>
        <p className="maintenance-form-hint">This is only a suggestion; generated work orders still require an authorised responsibility decision.</p>
      </fieldset>
      <fieldset><legend>Location and assignment</legend>
        <div className="form-grid">
          <label>Unit<select name="unit_id" defaultValue={schedule?.unit_id || ''}><option value="">Property-wide</option>{portfolio.units.map((unit) => <option value={unit.id} key={unit.id}>{unit.unit_number || unit.name || 'Unit'}</option>)}</select></label>
          <label>Room<select name="room_id" defaultValue={schedule?.room_id || ''}><option value="">No specific room</option>{portfolio.rooms.map((room) => <option value={room.id} key={room.id}>{room.room_name}</option>)}</select></label>
        </div>
        <div className="form-grid">
          <label>Internal assignee<select name="assigned_to_id" defaultValue={schedule?.assigned_to_id || ''}><option value="">Unassigned</option>{activePropertyAssignments(portfolio.assignments).map((assignment) => <option value={assignment.user.id} key={assignment.id}>{assignment.user.name}</option>)}</select></label>
          <label>Contractor<select name="contractor_id" defaultValue={schedule?.contractor_id || ''}><option value="">Not assigned</option>{parties.map((party) => <option value={party.id} key={party.id}>{party.name} · {party.party_type}</option>)}</select></label>
        </div>
      </fieldset>
      <fieldset><legend>Schedule</legend>
        <div className="form-grid">
          <label>Frequency<select name="frequency" value={frequency} onChange={(event) => setFrequency(event.target.value)}>{['once', 'daily', 'weekly', 'monthly', 'quarterly', 'semi_annual', 'annual', 'custom'].map((value) => <option value={value} key={value}>{readable(value)}</option>)}</select></label>
          <label>Generation mode<select name="generation_mode" defaultValue={schedule?.generation_mode || 'proposed'}><option value="automatic">Create work order</option><option value="proposed">Proposed (requires approval)</option><option value="reminder_only">Reminder only</option></select></label>
        </div>
        <div className="form-grid">
          <label>Custom interval value<input name="interval_value" type="number" min="1" required={frequency === 'custom'} defaultValue={schedule?.interval_value ?? ''} /></label>
          <label>Interval unit<select name="interval_unit" required={frequency === 'custom'} defaultValue={schedule?.interval_unit || 'month'}>{['day', 'week', 'month'].map((value) => <option key={value}>{value}</option>)}</select></label>
        </div>
        <div className="form-grid">
          <label>Starts<input name="starts_on" type="date" required defaultValue={schedule?.starts_on || today()} /></label>
          <label>Next due<input name="next_due_on" type="date" required value={nextDueOn} onChange={(event) => setNextDueOn(event.target.value)} /></label>
        </div>
        {frequency === 'once'
          ? <label>Target completion<input name="target_completion_on" type="date" min={nextDueOn} defaultValue={schedule?.target_completion_on || ''} /></label>
          : <input name="target_completion_on" type="hidden" value="" />}
        <div className="form-grid">
          <label>Ends (optional)<input name="ends_on" type="date" defaultValue={schedule?.ends_on || ''} /></label>
          <label>Reminder lead time (days)<input name="reminder_days" type="number" min="0" defaultValue={schedule?.reminder_days ?? 7} /></label>
        </div>
      </fieldset>
      <fieldset><legend>Budget</legend>
        <div className="form-grid">
          <label>Estimated cost<input name="estimated_cost" type="number" min="0" step="0.01" defaultValue={schedule?.estimated_cost ?? ''} /></label>
          <label>Currency<input name="currency" required minLength={3} maxLength={3} pattern="[A-Za-z]{3}" title="Enter a three-letter currency code" defaultValue={defaultCurrency} /></label>
        </div>
      </fieldset>
      <div className="modal-actions"><button type="button" className="secondary-button" onClick={onClose}>Cancel</button><button className="primary-button" disabled={saving}>{saving ? 'Saving...' : schedule ? 'Save plan' : 'Create plan'}</button></div>
    </form>
  </div>
}

function MaintenanceRequestDetails({
  propertyId,
  request,
  context,
  parties,
  assignments,
  saving,
  onEdit,
  onAction,
  onUpload,
  onFinancialEntry,
}: {
  propertyId: string
  request: MaintenanceRequest
  context: MaintenancePortfolioContext
  parties: MaintenanceParty[]
  assignments: MaintenancePortfolioContext['assignments']
  saving: boolean
  onEdit: () => void
  onAction: (request: MaintenanceRequest, action: string, values?: Record<string, unknown>, confirmation?: string) => Promise<void>
  onUpload: (request: MaintenanceRequest, file?: File, documentType?: string) => Promise<void>
  onFinancialEntry: (request: MaintenanceRequest, event: React.FormEvent<HTMLFormElement>) => Promise<void>
}) {
  const [approvedCost, setApprovedCost] = useState(request.approved_cost?.toString() || '')
  const [scheduledOn, setScheduledOn] = useState(request.scheduled_on || '')
  const [targetDate, setTargetDate] = useState(request.target_completion_on || '')
  const [actualCost, setActualCost] = useState(request.actual_cost?.toString() || '')
  const [resolutionNotes, setResolutionNotes] = useState(request.resolution_notes || '')
  const [decisionReason, setDecisionReason] = useState('')
  const [disputeReason, setDisputeReason] = useState('')
  const [cancelReason, setCancelReason] = useState('')
  const [documentType, setDocumentType] = useState('other')
  const [allocations, setAllocations] = useState([{ responsible_party: 'owner', allocated_amount: '', party_id: '', lease_id: '' }])
  const [allocationReason, setAllocationReason] = useState('')
  const [allocationError, setAllocationError] = useState('')

  useEffect(() => {
    setApprovedCost(request.approved_cost?.toString() || '')
    setScheduledOn(request.scheduled_on || '')
    setTargetDate(request.target_completion_on || '')
    setActualCost(request.actual_cost?.toString() || '')
    setResolutionNotes(request.resolution_notes || '')
  }, [request.id, request.approved_cost, request.scheduled_on, request.target_completion_on, request.actual_cost, request.resolution_notes])

  const invoices = request.financial_entries.filter((entry) => entry.entry_type === 'invoice')
  const paid = request.financial_entries.filter((entry) => entry.entry_type === 'payment' && entry.status === 'paid')
    .reduce((total, entry) => total + Number(entry.amount), 0)
  const invoiceOutstanding = invoices.reduce((total, invoice) => {
    const invoicePaid = paidPaymentsForInvoice(request.financial_entries, invoice.id)
    return total + Math.max(0, Number(invoice.amount) - invoicePaid)
  }, 0)

  async function submitAllocations(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setAllocationError('')
    const total = allocations.reduce((sum, allocation) => sum + Number(allocation.allocated_amount || 0), 0)
    if (request.approved_cost == null || Math.abs(total - Number(request.approved_cost)) > 0.01) {
      setAllocationError('Allocation amounts must total the approved amount.')
      return
    }
    if (allocations.some((allocation) => allocation.responsible_party === 'tenant' && (!allocation.lease_id || !allocation.party_id))) {
      setAllocationError('Each tenant allocation needs a matching tenant and lease.')
      return
    }
    await onAction(request, 'allocations', {
      rationale: allocationReason,
      allocations: allocations.map((allocation) => ({
        ...allocation,
        currency: request.currency,
        party_id: allocation.party_id || undefined,
        lease_id: allocation.lease_id || undefined,
      })),
    }, 'Approve these cost allocations? This records a financial responsibility decision.')
  }

  function updateAllocation(index: number, patch: Partial<typeof allocations[number]>) {
    setAllocations((current) => current.map((item, position) => position === index ? { ...item, ...patch } : item))
  }

  return <section className="maintenance-detail" aria-label={`Work order details: ${request.title}`}>
    <div className="maintenance-detail-heading">
      <div><p className="eyebrow">Work order · requested {new Date(request.reported_at).toLocaleDateString()}</p><h3>{request.title}</h3></div>
      <div className="maintenance-detail-actions"><span className={`maintenance-status status-${request.status}`}>{readable(request.status)}</span><button className="secondary-button" disabled={saving} onClick={onEdit}>Edit</button></div>
    </div>
    {request.description && <p className="maintenance-description">{request.description}</p>}
    <div className="maintenance-facts">
      <Fact label="Category" value={readable(request.category)} />
      <Fact label="Priority" value={readable(request.priority)} />
      <Fact label="Location" value={maintenanceLocation(request, context)} />
      <Fact label="Assignment" value={maintenanceAssignee(request, context, parties)} />
      <Fact label="Classification" value={readable(request.classification)} />
      <Fact label="Responsibility" value={`${readable(request.responsibility_status)} · ${readable(request.suggested_responsibility)}`} />
      <Fact label="Lease / tenant" value={context.leases.find((lease) => lease.id === request.lease_id)?.tenant_name || 'Not linked'} />
      <Fact label="Source" value={readable(request.source_type)} />
      <Fact label="Scheduled" value={request.scheduled_on || 'Not scheduled'} />
      <Fact label="Target completion" value={request.target_completion_on || 'Not recorded'} />
      <Fact label="Started" value={request.actual_started_at ? new Date(request.actual_started_at).toLocaleString() : 'Not recorded'} />
      <Fact label="Resolved" value={request.resolved_at ? new Date(request.resolved_at).toLocaleString() : 'Not recorded'} />
    </div>

    <section className="maintenance-detail-section">
      <h4>Work status</h4>
      <div className="maintenance-action-row">
        {request.status === 'open' && <button className="secondary-button" disabled={saving} onClick={() => onAction(request, 'acknowledge')}>Acknowledge</button>}
        {['open', 'acknowledged'].includes(request.status) && <button className="secondary-button" disabled={saving} onClick={() => onAction(request, 'submit_for_approval', {}, 'Send this work order for approval?')}>Request approval</button>}
        {request.status === 'awaiting_approval' && <form className="maintenance-inline-action" onSubmit={(event) => { event.preventDefault(); void onAction(request, 'approve', { approved_cost: approvedCost, comments: decisionReason }, 'Approve this work and amount?') }}>
          <label>Approved amount<input aria-label="Approved amount" type="number" min="0" step="0.01" required value={approvedCost} onChange={(event) => setApprovedCost(event.target.value)} /></label>
          <label>Approval notes<input aria-label="Approval notes" value={decisionReason} onChange={(event) => setDecisionReason(event.target.value)} /></label>
          <button className="primary-button" disabled={saving}>Approve work</button>
        </form>}
        {request.status === 'awaiting_approval' && <form className="maintenance-inline-action" onSubmit={(event) => { event.preventDefault(); void onAction(request, 'reject', { reason: decisionReason }, 'Reject this work order?') }}>
          <label>Rejection reason<input aria-label="Rejection reason" required value={decisionReason} onChange={(event) => setDecisionReason(event.target.value)} /></label>
          <button className="secondary-button" disabled={saving}>Reject</button>
        </form>}
        {['approved', 'acknowledged', 'open'].includes(request.status) && <form className="maintenance-inline-action" onSubmit={(event) => { event.preventDefault(); void onAction(request, 'schedule', { scheduled_on: scheduledOn, target_completion_on: targetDate || undefined }) }}>
          <label>Scheduled date<input aria-label="Scheduled date" type="date" required value={scheduledOn} onChange={(event) => setScheduledOn(event.target.value)} /></label>
          <label>Target completion<input aria-label="Target completion date" type="date" value={targetDate} onChange={(event) => setTargetDate(event.target.value)} /></label>
          <button className="secondary-button" disabled={saving}>Schedule</button>
        </form>}
        {['approved', 'scheduled', 'acknowledged'].includes(request.status) && <button className="secondary-button" disabled={saving} onClick={() => onAction(request, 'start', {}, 'Start work on this order?')}>Start work</button>}
        {request.status === 'in_progress' && <form className="maintenance-inline-action" onSubmit={(event) => { event.preventDefault(); void onAction(request, 'complete', { actual_cost: actualCost || undefined, resolution_notes: resolutionNotes }) }}>
          <label>Actual cost<input aria-label="Actual cost" type="number" min="0" step="0.01" value={actualCost} onChange={(event) => setActualCost(event.target.value)} /></label>
          <label>Completion notes<input aria-label="Completion notes" value={resolutionNotes} onChange={(event) => setResolutionNotes(event.target.value)} /></label>
          <button className="primary-button" disabled={saving}>Record completion</button>
        </form>}
        {request.status === 'resolved' && <>
          {!request.verified_at && <button className="secondary-button" disabled={saving} onClick={() => onAction(request, 'verify', {}, 'Verify that the reported work is complete?')}>Verify completion</button>}
          <button className="primary-button" disabled={saving} onClick={() => onAction(request, 'close', {}, 'Close this work order? It will remain in maintenance history.')}>Close work order</button>
        </>}
        {!terminalStatuses.includes(request.status) && <form className="maintenance-inline-action" onSubmit={(event) => { event.preventDefault(); void onAction(request, 'cancel', { reason: cancelReason }, 'Cancel this work order?') }}>
          <label>Cancellation reason<input aria-label="Cancellation reason" required value={cancelReason} onChange={(event) => setCancelReason(event.target.value)} /></label>
          <button className="secondary-button" disabled={saving}>Cancel work</button>
        </form>}
      </div>
      {(request.approval_notes || request.rejection_reason || request.cancellation_reason || request.resolution_notes) && <div className="maintenance-decision-notes">
        {request.approval_notes && <p><strong>Approval:</strong> {request.approval_notes}</p>}
        {request.rejection_reason && <p><strong>Rejection:</strong> {request.rejection_reason}</p>}
        {request.cancellation_reason && <p><strong>Cancellation:</strong> {request.cancellation_reason}</p>}
        {request.resolution_notes && <p><strong>Completion:</strong> {request.resolution_notes}</p>}
      </div>}
    </section>

    <section className="maintenance-detail-section">
      <h4>Financial breakdown</h4>
      <div className="maintenance-facts">
        <Fact label="Estimate" value={money(request.currency, request.estimated_cost)} />
        <Fact label="Quotations" value={String(request.financial_entries.filter((entry) => entry.entry_type === 'quotation').length)} />
        <Fact label="Approved amount" value={money(request.currency, request.approved_cost)} />
        <Fact label="Actual cost" value={money(request.currency, request.actual_cost)} />
        <Fact label="Amount paid" value={money(request.currency, paid)} />
        <Fact label="Outstanding invoices" value={money(request.currency, invoiceOutstanding)} />
      </div>
      <FinancialEntryForm request={request} parties={parties} saving={saving} onSubmit={(event) => onFinancialEntry(request, event)} />
      {request.financial_entries.length > 0 && <div className="maintenance-record-list">
        <h4>Quotes, invoices and payments</h4>
        {request.financial_entries.map((entry) => <div className="maintenance-financial-record" key={entry.id}>
          <div><strong>{readable(entry.entry_type)} · {money(entry.currency, entry.amount)}</strong><small>{entry.occurred_on} · {readable(entry.status)}{entry.invoice_reference || entry.reference ? ` · ${entry.invoice_reference || entry.reference}` : ''}</small></div>
          {entry.entry_type === 'payment' && entry.status === 'pending' && <button className="secondary-button" disabled={saving} onClick={() => onAction(request, `payments/${entry.id}/mark_paid`, {}, 'Mark this payment as paid?')}>Mark paid</button>}
        </div>)}
      </div>}
    </section>

    <section className="maintenance-detail-section">
      <h4>Cost responsibility</h4>
      <div className="maintenance-responsibility-note">
        <strong>{readable(request.responsibility_status)}</strong>
        <span>Classification: {readable(request.classification)}. Suggested: {readable(request.suggested_responsibility)}. A suggestion is not an approved charge.</span>
        {request.responsibility_notes && <span>{request.responsibility_notes}</span>}
      </div>
      {request.responsibility_status !== 'approved' && request.approved_cost != null && <form className="maintenance-allocation" onSubmit={submitAllocations}>
        <h4>Review and approve allocation</h4>
        <p>Allocation total must equal {money(request.currency, request.approved_cost)}. Tenant allocations require a matching lease and tenant.</p>
        {allocations.map((allocation, index) => {
          const selectedLease = context.leases.find((lease) => lease.id === allocation.lease_id)
          return <div className="maintenance-allocation-row" key={index}>
            <label>Responsible party<select value={allocation.responsible_party} onChange={(event) => updateAllocation(index, {
              responsible_party: event.target.value,
              party_id: event.target.value === 'tenant' ? selectedLease?.tenant_id || '' : '',
              lease_id: event.target.value === 'tenant' ? allocation.lease_id : '',
            })}>{['owner', 'tenant', 'shared', 'organization', 'third_party', 'other'].map((value) => <option value={value} key={value}>{readable(value)}</option>)}</select></label>
            <label>Allocated amount<input type="number" min="0" step="0.01" required value={allocation.allocated_amount} onChange={(event) => updateAllocation(index, { allocated_amount: event.target.value })} /></label>
            {allocation.responsible_party === 'tenant' && <label>Tenant lease<select required value={allocation.lease_id} onChange={(event) => {
              const lease = context.leases.find((item) => item.id === event.target.value)
              updateAllocation(index, { lease_id: event.target.value, party_id: lease?.tenant_id || '' })
            }}><option value="">Select a lease</option>{context.leases.map((lease) => <option value={lease.id} key={lease.id}>{lease.tenant_name} · {lease.start_date}</option>)}</select></label>}
            {allocation.responsible_party !== 'tenant' && <label>Related party (optional)<select value={allocation.party_id} onChange={(event) => updateAllocation(index, { party_id: event.target.value })}><option value="">No party linked</option>{parties.map((party) => <option value={party.id} key={party.id}>{party.name} · {party.party_type}</option>)}</select></label>}
            {allocations.length > 1 && <button type="button" className="maintenance-remove-allocation" onClick={() => setAllocations((current) => current.filter((_, position) => position !== index))}>Remove allocation</button>}
          </div>
        })}
        <button type="button" className="secondary-button" onClick={() => setAllocations((current) => [...current, { responsible_party: 'owner', allocated_amount: '', party_id: '', lease_id: '' }])}>Add allocation</button>
        <label>Decision rationale<textarea required rows={2} value={allocationReason} onChange={(event) => setAllocationReason(event.target.value)} /></label>
        {allocationError && <p className="form-error" role="alert">{allocationError}</p>}
        <button className="primary-button" disabled={saving}>Approve allocations</button>
      </form>}
      {request.responsibility_status === 'approved' && <form className="maintenance-allocation" onSubmit={(event) => { event.preventDefault(); void onAction(request, 'dispute_responsibility', { rationale: disputeReason }, 'Dispute this approved responsibility decision?') }}>
        <label>Dispute rationale<textarea required rows={2} value={disputeReason} onChange={(event) => setDisputeReason(event.target.value)} /></label>
        <button className="secondary-button" disabled={saving}>Reopen allocation review</button>
      </form>}
      {request.cost_allocations.length > 0 && <div className="maintenance-record-list"><h4>Allocation history</h4>{request.cost_allocations.map((allocation) => <p key={allocation.id}>{readable(allocation.responsible_party)} · {readable(allocation.status)} · {money(allocation.currency, allocation.allocated_amount)} · {allocation.rationale}</p>)}</div>}
    </section>

    <section className="maintenance-detail-section">
      <h4>Evidence and documents</h4>
      {request.documents.length > 0
        ? request.documents.map((document) => <div className="maintenance-document-row" key={document.id}>
          <FileText size={16} />
          <span>{document.url ? <a href={document.url} target="_blank" rel="noreferrer">{document.title}</a> : document.title}<small>{readable(document.document_type)} · {new Date(document.created_at).toLocaleDateString()}</small></span>
        </div>)
        : <p className="maintenance-muted">No supporting documents have been attached.</p>}
      <div className="maintenance-upload-form">
        <label>Evidence type<select value={documentType} onChange={(event) => setDocumentType(event.target.value)}>{['quotation', 'approval', 'work_order', 'before_photo', 'after_photo', 'invoice', 'receipt', 'payment_proof', 'completion_report', 'compliance_certificate', 'other'].map((value) => <option key={value} value={value}>{readable(value)}</option>)}</select></label>
        <label>Attach document or photo<input type="file" accept=".pdf,.jpg,.jpeg,.png,.webp,.doc,.docx" disabled={saving} onChange={(event) => { void onUpload(request, event.target.files?.[0], documentType); event.currentTarget.value = '' }} /></label>
      </div>
    </section>

    <section className="maintenance-detail-section">
      <h4>Approval and verification</h4>
      <div className="maintenance-facts">
        <Fact label="Approved by" value={request.approved_by_id || 'Not approved'} />
        <Fact label="Approved at" value={request.approved_at ? new Date(request.approved_at).toLocaleString() : 'Not recorded'} />
        <Fact label="Verified by" value={request.verified_by_id || 'Not verified'} />
        <Fact label="Verified at" value={request.verified_at ? new Date(request.verified_at).toLocaleString() : 'Not recorded'} />
        <Fact label="Closed by" value={request.closed_by_id || 'Not closed'} />
        <Fact label="Closed at" value={request.closed_at ? new Date(request.closed_at).toLocaleString() : 'Not recorded'} />
        <Fact label="Assigned internal user" value={assignments.find((assignment) => assignment.user.id === request.assigned_to_id)?.user.name || 'Unassigned'} />
      </div>
    </section>

    <section className="maintenance-detail-section">
      <h4>Maintenance history</h4>
      {request.audit_history.length
        ? <ol className="maintenance-history">{request.audit_history.map((event, index) => <li key={`${event.occurred_at}-${index}`}>
          <Clock3 size={14} /><span><strong>{readable(event.action)}</strong><small>{new Date(event.occurred_at).toLocaleString()} · {event.actor_id || 'System'}</small><small>{Object.entries(event.changes || {}).map(([field, value]) => `${field}: ${String(value)}`).join(' · ')}</small></span>
        </li>)}</ol>
        : <p className="maintenance-muted">No audit history is available.</p>}
    </section>
    <div className="maintenance-detail-footer"><span>Work order {request.id}</span><span>Updated {new Date(request.updated_at).toLocaleString()}</span></div>
  </section>
}

function paidPaymentsForInvoice(entries: MaintenanceFinancialEntry[], invoiceId: string): number {
  return entries.filter((entry) =>
    entry.entry_type === 'payment' && entry.status === 'paid' && entry.invoice_id === invoiceId,
  ).reduce((sum, entry) => sum + Number(entry.amount), 0)
}

function Fact({ label, value }: { label: string; value: string }) {
  return <div><span>{label}</span><strong>{value}</strong></div>
}

function FinancialEntryForm({
  request,
  parties,
  saving,
  onSubmit,
}: {
  request: MaintenanceRequest
  parties: MaintenanceParty[]
  saving: boolean
  onSubmit: (event: React.FormEvent<HTMLFormElement>) => void
}) {
  const [entryType, setEntryType] = useState<'quotation' | 'invoice' | 'payment'>('quotation')
  const invoices = request.financial_entries.filter((entry) => entry.entry_type === 'invoice')
  return <form className="maintenance-entry-form" onSubmit={onSubmit}>
    <h4>Record financial item</h4>
    <div className="form-grid">
      <label>Record type<select name="entry_type" value={entryType} onChange={(event) => setEntryType(event.target.value as typeof entryType)}><option value="quotation">Quotation</option><option value="invoice">Invoice</option><option value="payment">Payment</option></select></label>
      <label>Amount<input name="amount" type="number" min="0" step="0.01" required /></label>
    </div>
    <div className="form-grid">
      <label>Date<input name="occurred_on" type="date" required defaultValue={today()} /></label>
      <label>Reference<input name="reference" /></label>
    </div>
    {entryType === 'quotation' && <label>Valid until<input name="valid_until" type="date" /></label>}
    {entryType === 'invoice' && <div className="form-grid">
      <label>Invoice number<input name="invoice_reference" required /></label>
      <label>Due date<input name="due_on" type="date" /></label>
    </div>}
    {entryType === 'payment' && <>
      <label>Invoice<select name="invoice_id" required defaultValue=""><option value="">Select an invoice</option>{invoices.map((invoice) => <option value={invoice.id} key={invoice.id}>{invoice.invoice_reference || invoice.reference || invoice.id} · {money(invoice.currency, invoice.amount)}</option>)}</select></label>
      <label>Payment status<select name="status" defaultValue="paid"><option value="paid">Paid</option><option value="pending">Pending</option></select></label>
    </>}
    {parties.length > 0 && <label>Related party (optional)<select name="party_id" defaultValue=""><option value="">No party linked</option>{parties.map((party) => <option value={party.id} key={party.id}>{party.name} · {party.party_type}</option>)}</select></label>}
    <label>Notes<input name="notes" /></label>
    <button className="secondary-button" disabled={saving}>{saving ? 'Saving...' : `Record ${readable(entryType)}`}</button>
  </form>
}
