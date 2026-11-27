
import { useEffect, useState } from 'react'
import { Bell, Building2, CalendarDays, FileText, LogOut, Wrench } from 'lucide-react'
import { api } from './api'

type TenantDashboardData = {
  profile: {
    first_name: string
    last_name: string
    email: string
    phone_number?: string | null
    tenant_reference?: string | null
  }
  tenancies: Array<{
    property: {
      name: string
      description?: string | null
      address: Record<string, string | null>
    }
    premises: {
      unit: {
        unit_number?: string | null
        name?: string | null
        unit_type?: string | null
        bedrooms: number
        bathrooms: number
        floor_area?: number | string | null
      }
    }
    lease: {
      id: string
      status: string
      lease_type: string
      start_date: string
      end_date: string
      agreed_rent: { amount: number | string; currency: string }
      deposit_amount?: number | string | null
      notice_period_days: number
      terms_summary?: string | null
      shared_documents: Array<{ id: string; title: string; document_type: string; created_at: string }>
    }
  }>
  maintenance_requests: Array<{
    id: string
    title: string
    description?: string | null
    category?: string | null
    priority: string
    status: string
    submitted_at: string
    updates: Array<{
      id: string
      update_type: string
      body: string
      published_at: string
      scheduled_start_at?: string | null
      scheduled_end_at?: string | null
    }>
  }>
  renewal_proposals: Array<{
    id: string
    property_name: string
    status: string
    proposed_start_date: string
    proposed_end_date: string
    proposed_rent: { amount: number | string; currency: string }
    expires_at?: string | null
    shared_document?: { id: string; title: string; document_type: string } | null
  }>
  notifications: Array<{
    id: string
    notification_type: string
    title: string
    body: string
    created_at: string
    read_at?: string | null
  }>
}

type Props = {
  onSignOut: () => void
}

const maintenanceCategories = [
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

const priorities = ['low', 'medium', 'high', 'urgent']

const date = (value?: string | null) => value
  ? new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(new Date(value))
  : 'Not set'

const amount = (value: number | string, currency: string) =>
  `${currency} ${Number(value).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`

const label = (value?: string | null) => value
  ? value.replace(/_/g, ' ')
  : 'Not recorded'

const errorMessage = (error: unknown, fallback: string) =>
  error instanceof Error ? error.message : fallback

export function TenantDashboard({ onSignOut }: Props) {
  const [dashboard, setDashboard] = useState<TenantDashboardData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const [selectedLeaseId, setSelectedLeaseId] = useState('')
  const [description, setDescription] = useState('')
  const [category, setCategory] = useState('general_repairs')
  const [priority, setPriority] = useState('medium')
  const [submitting, setSubmitting] = useState(false)
  const [formError, setFormError] = useState('')
  const [formSuccess, setFormSuccess] = useState('')

  useEffect(() => {
    let active = true

    api<TenantDashboardData>('/tenant/dashboard')
      .then((data) => {
        if (active) setDashboard(data)
      })
      .catch((err: unknown) => {
        if (active) setError(errorMessage(err, 'Your dashboard could not be loaded.'))
      })
      .finally(() => {
        if (active) setLoading(false)
      })

    return () => {
      active = false
    }
  }, [])

  const submitMaintenanceRequest = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()

    const leaseId = selectedLeaseId || dashboard?.tenancies[0]?.lease.id

    if (!leaseId) {
      setFormError('No active tenancy is available for this request.')
      return
    }

    if (!description.trim()) {
      setFormError('Please describe the maintenance issue.')
      return
    }

    setSubmitting(true)
    setFormError('')
    setFormSuccess('')

    try {
      await api('/tenant/maintenance_requests', {
        method: 'POST',
        body: JSON.stringify({
          maintenance_request: {
            lease_id: leaseId,
            description: description.trim(),
            category,
            priority,
          },
        }),
      })

      setDescription('')
      setCategory('general_repairs')
      setPriority('medium')
      setFormSuccess('Your maintenance request has been submitted.')

      try {
        const updatedDashboard = await api<TenantDashboardData>('/tenant/dashboard')
        setDashboard(updatedDashboard)
      } catch {
        setFormError('Your request was submitted, but the dashboard could not refresh. Reload the page to see it.')
      }
    } catch (err: unknown) {
      setFormError(errorMessage(err, 'Your maintenance request could not be submitted. Please try again.'))
    } finally {
      setSubmitting(false)
    }
  }

  const openRequests = dashboard?.maintenance_requests.filter(
    (request) => !['completed', 'closed'].includes(request.status),
  ).length ?? 0

  const unreadNotifications = dashboard?.notifications.filter(
    (notification) => !notification.read_at,
  ).length ?? 0

  return <div className="tenant-shell">
    <header className="tenant-header">
      <div className="brand"><span className="brand-mark"><Building2 size={18} /></span><span>Atlas / tenant</span></div>
      <button className="tenant-signout" type="button" onClick={onSignOut}><LogOut size={15} /> Sign out</button>
    </header>

    <main className="tenant-main">
      {loading ? <div className="tenant-loading"><div className="spinner" /> Loading your dashboard</div> : error ? <div className="error-banner" role="alert">{error}</div> : dashboard && <>
        <section className="tenant-welcome">
          <div>
            <p className="eyebrow">Tenant workspace</p>
            <h1>Welcome, {dashboard.profile.first_name}</h1>
            <p>Keep track of your home, lease details and maintenance updates in one place.</p>
          </div>
          {dashboard.profile.tenant_reference && <div className="tenant-reference"><span>Tenant reference</span><strong>{dashboard.profile.tenant_reference}</strong></div>}
        </section>

        <section className="tenant-summary" aria-label="Tenancy summary">
          <div><span>Current homes</span><strong>{dashboard.tenancies.length.toString().padStart(2, '0')}</strong></div>
          <div><span>Open maintenance</span><strong>{openRequests.toString().padStart(2, '0')}</strong></div>
          <div><span>Unread updates</span><strong>{unreadNotifications.toString().padStart(2, '0')}</strong></div>
        </section>

        <section className="tenant-section">
          <div className="tenant-section-heading"><div><p className="eyebrow">Your tenancy</p><h2>Your home</h2></div></div>
          {dashboard.tenancies.length ? <div className="tenant-home-grid">{dashboard.tenancies.map((tenancy) => {
            const unit = tenancy.premises.unit
            const documents = tenancy.lease.shared_documents

            return <article className="tenant-home-card" key={tenancy.lease.id}>
              <div className="tenant-home-title"><span className="tenant-home-icon"><Building2 size={21} /></span><div><h3>{tenancy.property.name}</h3><p>{[tenancy.property.address.line_1, tenancy.property.address.suburb, tenancy.property.address.city, tenancy.property.address.province].filter(Boolean).join(', ') || 'Address not provided'}</p></div></div>
              <div className="tenant-facts">
                <div><span>Unit</span><strong>{unit.unit_number || unit.name || 'Not specified'}</strong></div>
                <div><span>Lease dates</span><strong>{date(tenancy.lease.start_date)} – {date(tenancy.lease.end_date)}</strong></div>
                <div><span>Monthly rent</span><strong>{amount(tenancy.lease.agreed_rent.amount, tenancy.lease.agreed_rent.currency)}</strong></div>
                <div><span>Premises</span><strong>{unit.bedrooms} bed · {unit.bathrooms} bath</strong></div>
              </div>
              {tenancy.property.description && <p className="tenant-property-description">{tenancy.property.description}</p>}
              {tenancy.lease.terms_summary && <p className="tenant-property-description">{tenancy.lease.terms_summary}</p>}
              <div className="tenant-home-footer"><span><CalendarDays size={14} /> {label(tenancy.lease.lease_type)}</span><span><FileText size={14} /> {documents.length} shared {documents.length === 1 ? 'document' : 'documents'}</span></div>
              {documents.length > 0 && <ul className="tenant-document-list">{documents.map((document) => <li key={document.id}>{document.title}</li>)}</ul>}
            </article>
          })}</div> : <div className="tenant-empty"><Building2 size={24} /><h3>No current tenancy linked</h3><p>Contact your property manager if you expected to see a home here.</p></div>}
        </section>

        <div className="tenant-dashboard-grid">
          <section className="tenant-section">
            <div className="tenant-section-heading"><div><p className="eyebrow">Requests you submitted</p><h2>Maintenance</h2></div><Wrench size={19} /></div>

            {dashboard.tenancies.length > 0 && <form className="tenant-maintenance-form" onSubmit={submitMaintenanceRequest}>
              <h3>Report a maintenance issue</h3>
              <p>Tell your property team what needs attention. They will review your request and provide updates here.</p>

              {dashboard.tenancies.length > 1 && <label className="tenant-form-field">
                <span>Property / tenancy</span>
                <select
                  value={selectedLeaseId || dashboard.tenancies[0].lease.id}
                  onChange={(event) => setSelectedLeaseId(event.target.value)}
                  required
                >
                  {dashboard.tenancies.map((tenancy) => {
                    const unit = tenancy.premises.unit
                    const unitName = unit.unit_number || unit.name || 'Unit'

                    return <option key={tenancy.lease.id} value={tenancy.lease.id}>
                      {tenancy.property.name} — {unitName}
                    </option>
                  })}
                </select>
              </label>}

              <label className="tenant-form-field">
                <span>Category</span>
                <select value={category} onChange={(event) => setCategory(event.target.value)} required>
                  {maintenanceCategories.map((value) => <option value={value} key={value}>{label(value)}</option>)}
                </select>
              </label>

              <label className="tenant-form-field">
                <span>Priority</span>
                <select value={priority} onChange={(event) => setPriority(event.target.value)} required>
                  {priorities.map((value) => <option value={value} key={value}>{label(value)}</option>)}
                </select>
              </label>

              <label className="tenant-form-field">
                <span>Describe the issue</span>
                <textarea
                  value={description}
                  onChange={(event) => setDescription(event.target.value)}
                  placeholder="Describe what is happening, where the issue is, and when you first noticed it..."
                  rows={5}
                  maxLength={10000}
                  required
                />
                <small>{description.length.toLocaleString()} / 10,000 characters</small>
              </label>

              {formError && <div className="error-banner" role="alert">{formError}</div>}
              {formSuccess && <div className="success-banner" role="status">{formSuccess}</div>}

              <div className="tenant-form-actions">
                <button className="primary-button" type="submit" disabled={submitting || !description.trim()}>
                  {submitting ? 'Submitting...' : 'Submit maintenance request'}
                </button>
              </div>
            </form>}

            {dashboard.maintenance_requests.length ? <div className="tenant-feed">{dashboard.maintenance_requests.map((request) => <article className="tenant-feed-item" key={request.id}>
              <div className="tenant-feed-heading"><div><h3>{request.title}</h3><p>{label(request.category)} · Submitted {date(request.submitted_at)}</p></div><span className={`tenant-status status-${request.status}`}>{label(request.status)}</span></div>
              {request.description && <p className="tenant-feed-body">{request.description}</p>}
              {request.updates[0] && <div className="tenant-published-update"><strong>Latest update</strong><p>{request.updates[0].body}</p>{request.updates[0].scheduled_start_at && <small>Visit planned for {date(request.updates[0].scheduled_start_at)}. </small>}<small>{date(request.updates[0].published_at)}</small></div>}
            </article>)}</div> : <div className="tenant-empty compact"><p>You have no maintenance requests to show.</p></div>}

            {!dashboard.tenancies.length && <div className="tenant-empty compact"><p>You need an active tenancy before you can submit a maintenance request.</p></div>}
          </section>

          <section className="tenant-section">
            <div className="tenant-section-heading"><div><p className="eyebrow">From your property team</p><h2>Notifications</h2></div><Bell size={19} /></div>
            {dashboard.notifications.length ? <div className="tenant-feed">{dashboard.notifications.map((notification) => <article className="tenant-notification" key={notification.id}>
              <div className="tenant-feed-heading"><h3>{notification.title}</h3>{!notification.read_at && <span className="tenant-unread">New</span>}</div>
              <p>{notification.body}</p><small>{date(notification.created_at)}</small>
            </article>)}</div> : <div className="tenant-empty compact"><p>You’re all caught up.</p></div>}
          </section>
        </div>

        {dashboard.renewal_proposals.length > 0 && <section className="tenant-section">
          <div className="tenant-section-heading"><div><p className="eyebrow">Lease updates</p><h2>Renewal proposals</h2></div></div>
          <div className="tenant-feed">{dashboard.renewal_proposals.map((proposal) => <article className="tenant-feed-item" key={proposal.id}>
            <div className="tenant-feed-heading"><div><h3>{proposal.property_name}</h3><p>{date(proposal.proposed_start_date)} – {date(proposal.proposed_end_date)}</p></div><span className="tenant-status">{label(proposal.status)}</span></div>
            <p className="tenant-feed-body">Proposed monthly rent: {amount(proposal.proposed_rent.amount, proposal.proposed_rent.currency)}</p>
            {proposal.expires_at && <small>Respond by {date(proposal.expires_at)}</small>}
            {proposal.shared_document && <p className="tenant-shared-document"><FileText size={14} /> {proposal.shared_document.title}</p>}
          </article>)}</div>
        </section>}
      </>}
    </main>
  </div>
}
