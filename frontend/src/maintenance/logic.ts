import type {
  MaintenanceAssignment,
  MaintenancePortfolioContext,
  MaintenanceRequest,
  MaintenanceSchedule,
  MaintenanceView,
} from './types'

export type MaintenanceCostSummary = {
  estimates: Record<string, number>
  approved: Record<string, number>
  actual: Record<string, number>
  paid: Record<string, number>
  outstanding: Record<string, number>
}

export function localDateString(date = new Date()): string {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

function dateFromString(value: string): Date {
  const [year, month, day] = value.slice(0, 10).split('-').map(Number)
  return new Date(year, month - 1, day)
}

function dateIsWithin(value: string, start: string, end: string): boolean {
  return value >= start && value <= end
}

export function calendarGridDates(month: Date): Date[] {
  const firstDay = new Date(month.getFullYear(), month.getMonth(), 1)
  const gridStart = new Date(firstDay.getFullYear(), firstDay.getMonth(), 1 - firstDay.getDay())
  return Array.from({ length: 42 }, (_, index) =>
    new Date(gridStart.getFullYear(), gridStart.getMonth(), gridStart.getDate() + index),
  )
}

function nextScheduleDate(schedule: MaintenanceSchedule, date: Date): Date | null {
  const frequencyMonths: Record<string, number> = {
    monthly: 1,
    quarterly: 3,
    semi_annual: 6,
    annual: 12,
  }
  const customMonths = schedule.interval_unit === 'month'
    ? schedule.interval_value
    : schedule.interval_months
  const months = frequencyMonths[schedule.frequency]
    ?? (schedule.frequency === 'custom' && customMonths ? customMonths : undefined)

  if (schedule.frequency === 'daily' || (schedule.frequency === 'custom' && schedule.interval_unit === 'day')) {
    const interval = schedule.frequency === 'daily' ? 1 : schedule.interval_value
    return interval ? new Date(date.getFullYear(), date.getMonth(), date.getDate() + interval) : null
  }
  if (schedule.frequency === 'weekly' || (schedule.frequency === 'custom' && schedule.interval_unit === 'week')) {
    const interval = schedule.frequency === 'weekly' ? 1 : schedule.interval_value
    return interval ? new Date(date.getFullYear(), date.getMonth(), date.getDate() + interval * 7) : null
  }
  if (months) {
    const targetMonth = new Date(date.getFullYear(), date.getMonth() + months, 1)
    const anchorDay = dateFromString(schedule.starts_on).getDate()
    const targetDay = Math.min(anchorDay, new Date(targetMonth.getFullYear(), targetMonth.getMonth() + 1, 0).getDate())
    return new Date(targetMonth.getFullYear(), targetMonth.getMonth(), targetDay)
  }
  return null
}

export type MaintenanceCalendarEvent = {
  id: string
  date: string
  title: string
  status: string
  kind: 'work_order' | 'schedule'
  request?: MaintenanceRequest
  schedule?: MaintenanceSchedule
}

export function maintenanceCalendarEvents(
  requests: MaintenanceRequest[],
  schedules: MaintenanceSchedule[],
  month: Date,
  today = localDateString(),
): MaintenanceCalendarEvent[] {
  const grid = calendarGridDates(month)
  const start = localDateString(grid[0])
  const end = localDateString(grid[grid.length - 1])
  const events: MaintenanceCalendarEvent[] = []

  requests.forEach((request) => {
    const completed = ['resolved', 'closed'].includes(request.status)
    const terminal = ['resolved', 'closed', 'rejected', 'cancelled'].includes(request.status)
    const dueDate = !terminal && request.target_completion_on && request.target_completion_on < today
      ? request.target_completion_on
      : undefined
    const date = completed
      ? (request.resolved_at ? localDateString(new Date(request.resolved_at)) : undefined)
        || request.scheduled_on || request.target_completion_on
      : dueDate || request.scheduled_on || request.target_completion_on
    if (!date || !dateIsWithin(date, start, end)) return
    events.push({
      id: request.id,
      date,
      title: request.title,
      status: dueDate ? 'overdue' : request.status,
      kind: 'work_order',
      request,
    })
  })

  schedules.filter((schedule) => schedule.status === 'active').forEach((schedule) => {
    let dueDate = dateFromString(schedule.next_due_on)
    const startDate = dateFromString(schedule.starts_on)
    const endDate = schedule.ends_on ? dateFromString(schedule.ends_on) : null
    let iterations = 0
    while (localDateString(dueDate) <= end && (!endDate || dueDate <= endDate) && iterations < 10_000) {
      const date = localDateString(dueDate)
      if (date >= start && date <= end && dueDate >= startDate) {
        events.push({
          id: `${schedule.id}:${date}`,
          date,
          title: schedule.title,
          status: date < today ? 'overdue' : 'scheduled',
          kind: 'schedule',
          schedule,
        })
      }
      if (schedule.frequency === 'once') break
      const nextDate = nextScheduleDate(schedule, dueDate)
      if (!nextDate || nextDate <= dueDate) break
      dueDate = nextDate
      iterations += 1
    }
  })

  return events.sort((left, right) =>
    left.date.localeCompare(right.date) || left.title.localeCompare(right.title),
  )
}

function sumCurrencies(
  current: Record<string, number>,
  currency: string,
  amount: number | string | null | undefined,
): void {
  if (amount === null || amount === undefined || amount === '') return
  const value = Number(amount)
  if (!Number.isFinite(value)) return
  current[currency] = (current[currency] || 0) + value
}

export function summarizeMaintenanceCosts(requests: MaintenanceRequest[]): MaintenanceCostSummary {
  const summary: MaintenanceCostSummary = {
    estimates: {},
    approved: {},
    actual: {},
    paid: {},
    outstanding: {},
  }
  const invoices = new Map<string, { amount: number; paid: number; currency: string }>()

  requests.forEach((request) => {
    sumCurrencies(summary.estimates, request.currency, request.estimated_cost)
    sumCurrencies(summary.approved, request.currency, request.approved_cost)
    sumCurrencies(summary.actual, request.currency, request.actual_cost)

    request.financial_entries.forEach((entry) => {
      if (entry.entry_type === 'invoice') {
        const amount = Number(entry.amount)
        if (Number.isFinite(amount)) invoices.set(entry.id, { amount, paid: 0, currency: entry.currency })
      }
    })
  })

  requests.forEach((request) => {
    request.financial_entries.forEach((entry) => {
      if (entry.entry_type !== 'payment') return
      if (entry.status === 'paid') sumCurrencies(summary.paid, entry.currency, entry.amount)
      if (entry.status !== 'paid' || !entry.invoice_id) return

      const invoice = invoices.get(entry.invoice_id)
      if (invoice && invoice.currency === entry.currency) invoice.paid += Number(entry.amount)
    })
  })

  invoices.forEach((invoice) => {
    sumCurrencies(summary.outstanding, invoice.currency, Math.max(0, invoice.amount - invoice.paid))
  })

  return summary
}

const activeStatuses = new Set([
  'open',
  'acknowledged',
  'awaiting_approval',
  'approved',
  'scheduled',
  'in_progress',
])
const completedStatuses = new Set(['resolved', 'closed'])
const historyStatuses = new Set(['resolved', 'closed', 'rejected', 'cancelled', 'disputed'])

export function filterMaintenanceRequests(
  requests: MaintenanceRequest[],
  view: MaintenanceView,
  search: string,
  context: MaintenancePortfolioContext,
  today = localDateString(),
): MaintenanceRequest[] {
  const query = search.trim().toLowerCase()
  return requests.filter((request) => {
    const plannedDate = request.scheduled_on || request.target_completion_on
    if (view === 'upcoming' && !(!!plannedDate && plannedDate >= today && !['resolved', 'closed', 'rejected', 'cancelled'].includes(request.status))) return false
    if (view === 'in_progress' && request.status !== 'in_progress') return false
    if (view === 'completed' && !completedStatuses.has(request.status)) return false
    if (view === 'history' && !historyStatuses.has(request.status) && request.responsibility_status !== 'disputed') return false
    if (view === 'work_orders' && !activeStatuses.has(request.status)) return false

    if (!query) return true
    const unit = context.units.find((item) => item.id === request.unit_id)
    const room = context.rooms.find((item) => item.id === request.room_id)
    const assignee = context.assignments.find((item) => item.user.id === request.assigned_to_id)
    const contractor = context.parties?.find((item) => item.id === request.contractor_id)
    const haystack = [
      request.title,
      request.description,
      request.category,
      request.priority,
      request.status,
      request.classification,
      request.suggested_responsibility,
      unit?.unit_number,
      unit?.name,
      room?.room_name,
      assignee?.user.name,
      contractor?.name,
    ].filter(Boolean).join(' ').toLowerCase()
    return haystack.includes(query)
  })
}

const priorityOrder: Record<string, number> = { urgent: 0, high: 1, medium: 2, low: 3 }

export function sortMaintenanceRequests(
  requests: MaintenanceRequest[],
  sortBy: 'scheduled' | 'reported' | 'priority' | 'cost',
): MaintenanceRequest[] {
  return [...requests].sort((a, b) => {
    if (sortBy === 'priority') {
      return (priorityOrder[a.priority] ?? 4) - (priorityOrder[b.priority] ?? 4)
        || b.reported_at.localeCompare(a.reported_at)
    }
    if (sortBy === 'cost') return Number(b.actual_cost || b.estimated_cost || 0) - Number(a.actual_cost || a.estimated_cost || 0)
    if (sortBy === 'scheduled') return (a.scheduled_on || '9999-12-31').localeCompare(b.scheduled_on || '9999-12-31')
    return b.reported_at.localeCompare(a.reported_at)
  })
}

export function maintenanceLocation(
  request: MaintenanceRequest,
  context: MaintenancePortfolioContext,
): string {
  const unit = context.units.find((item) => item.id === request.unit_id)
  const room = context.rooms.find((item) => item.id === request.room_id)
  const unitLabel = unit?.unit_number || unit?.name
  return [unitLabel, room?.room_name].filter(Boolean).join(' · ') || 'Property-wide'
}

export function maintenanceAssignee(
  request: MaintenanceRequest,
  context: MaintenancePortfolioContext,
  parties: { id: string; name: string }[],
): string {
  const internal = context.assignments.find((item) => item.user.id === request.assigned_to_id)?.user.name
  const external = parties.find((party) => party.id === request.contractor_id)?.name
  return [internal, external].filter(Boolean).join(' · ') || 'Unassigned'
}

export function scheduleLocation(
  schedule: MaintenanceSchedule,
  context: MaintenancePortfolioContext,
): string {
  const unit = context.units.find((item) => item.id === schedule.unit_id)
  const room = context.rooms.find((item) => item.id === schedule.room_id)
  return [unit?.unit_number || unit?.name, room?.room_name].filter(Boolean).join(' · ') || 'Property-wide'
}

export function activePropertyAssignments(
  assignments: MaintenanceAssignment[],
  at = new Date(),
): MaintenanceAssignment[] {
  return assignments.filter((assignment) => {
    const starts = new Date(assignment.starts_at)
    const ends = assignment.ends_at ? new Date(assignment.ends_at) : null
    return starts <= at && (!ends || ends >= at)
  })
}
