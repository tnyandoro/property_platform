import { describe, expect, it } from 'vitest'
import {
  calendarGridDates,
  filterMaintenanceRequests,
  maintenanceCalendarEvents,
  maintenanceLocation,
  sortMaintenanceRequests,
  summarizeMaintenanceCosts,
} from './logic'
import type { MaintenancePortfolioContext, MaintenanceRequest, MaintenanceSchedule } from './types'

const context: MaintenancePortfolioContext = {
  units: [{ id: 'unit-1', unit_number: '4B' }],
  rooms: [{ id: 'room-1', unit_id: 'unit-1', room_name: 'Kitchen' }],
  items: [],
  leases: [],
  assignments: [],
  inspections: [],
  damage_assessments: [],
}

function request(overrides: Partial<MaintenanceRequest> = {}): MaintenanceRequest {
  return {
    id: 'request-1',
    property_id: 'property-1',
    unit_id: 'unit-1',
    room_id: 'room-1',
    title: 'Repair tap',
    priority: 'medium',
    status: 'scheduled',
    classification: 'wear_and_tear',
    suggested_responsibility: 'unknown',
    responsibility_status: 'pending_review',
    source_type: 'manager',
    reported_at: '2026-01-01T10:00:00Z',
    currency: 'ZAR',
    cost_allocations: [],
    financial_entries: [],
    documents: [],
    audit_history: [],
    created_at: '2026-01-01T10:00:00Z',
    updated_at: '2026-01-01T10:00:00Z',
    ...overrides,
  }
}

function schedule(overrides: Partial<MaintenanceSchedule> = {}): MaintenanceSchedule {
  return {
    id: 'schedule-1',
    property_id: 'property-1',
    title: 'Monthly pump service',
    priority: 'medium',
    classification: 'preventative_maintenance',
    suggested_responsibility: 'unknown',
    frequency: 'monthly',
    starts_on: '2026-01-31',
    next_due_on: '2026-01-31',
    reminder_days: 7,
    status: 'active',
    generation_mode: 'proposed',
    currency: 'ZAR',
    ...overrides,
  }
}

describe('maintenance workspace logic', () => {
  it('filters scheduled work by date and searches its property location', () => {
    const current = request({ scheduled_on: '2026-06-18' })
    const overdue = request({ id: 'request-2', scheduled_on: '2026-06-15' })
    const targetOnly = request({
      id: 'request-3',
      status: 'open',
      scheduled_on: undefined,
      target_completion_on: '2026-06-19',
    })

    expect(filterMaintenanceRequests([current, overdue, targetOnly], 'upcoming', 'kitchen', context, '2026-06-17'))
      .toEqual([current, targetOnly])
    expect(maintenanceLocation(current, context)).toBe('4B · Kitchen')
  })

  it('keeps expense totals separated by currency and counts only paid payments', () => {
    const invoice = { id: 'invoice-1', entry_type: 'invoice' as const, amount: 100, currency: 'ZAR', status: 'received', occurred_on: '2026-06-01' }
    const requests = [
      request({
        estimated_cost: 120,
        approved_cost: 100,
        actual_cost: 90,
        financial_entries: [
          invoice,
          { id: 'paid-1', entry_type: 'payment', amount: 30, currency: 'ZAR', status: 'paid', occurred_on: '2026-06-02', invoice_id: 'invoice-1' },
          { id: 'pending-1', entry_type: 'payment', amount: 20, currency: 'ZAR', status: 'pending', occurred_on: '2026-06-03', invoice_id: 'invoice-1' },
        ],
      }),
      request({
        id: 'request-2',
        currency: 'USD',
        actual_cost: 50,
        financial_entries: [
          { id: 'invoice-2', entry_type: 'invoice', amount: 70, currency: 'USD', status: 'received', occurred_on: '2026-06-01' },
        ],
      }),
    ]

    expect(summarizeMaintenanceCosts(requests)).toEqual({
      estimates: { ZAR: 120 },
      approved: { ZAR: 100 },
      actual: { ZAR: 90, USD: 50 },
      paid: { ZAR: 30 },
      outstanding: { ZAR: 70, USD: 70 },
    })
  })

  it('sorts urgent work ahead of lower priority while keeping the result immutable', () => {
    const low = request({ id: 'low', priority: 'low' })
    const urgent = request({ id: 'urgent', priority: 'urgent' })
    const input = [low, urgent]

    expect(sortMaintenanceRequests(input, 'priority').map((item) => item.id)).toEqual(['urgent', 'low'])
    expect(input).toEqual([low, urgent])
  })

  it('keeps disputed responsibility decisions visible in maintenance history', () => {
    const disputed = request({ responsibility_status: 'disputed' })
    expect(filterMaintenanceRequests([disputed], 'history', '', context)).toEqual([disputed])
  })

  it('builds a full month grid without UTC date shifts', () => {
    const dates = calendarGridDates(new Date(2026, 1, 1))

    expect(dates).toHaveLength(42)
    expect(dates[0]).toEqual(new Date(2026, 1, 1))
    expect(dates[41]).toEqual(new Date(2026, 2, 14))
  })

  it('shows overdue and completed work with anchored recurring occurrences', () => {
    const overdue = request({
      id: 'overdue',
      status: 'in_progress',
      scheduled_on: '2026-03-05',
      target_completion_on: '2026-03-10',
    })
    const completed = request({
      id: 'completed',
      status: 'closed',
      scheduled_on: '2026-03-08',
      target_completion_on: '2026-03-09',
      resolved_at: '2026-03-12T10:00:00Z',
    })
    const events = maintenanceCalendarEvents(
      [overdue, completed],
      [schedule()],
      new Date(2026, 2, 1),
      '2026-03-11',
    )

    expect(events).toEqual(expect.arrayContaining([
      expect.objectContaining({ id: 'overdue', date: '2026-03-10', status: 'overdue' }),
      expect.objectContaining({ id: 'completed', date: '2026-03-12', status: 'closed' }),
      expect.objectContaining({ id: 'schedule-1:2026-03-31', date: '2026-03-31', kind: 'schedule' }),
    ]))
  })
})
