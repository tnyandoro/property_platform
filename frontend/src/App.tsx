import { useEffect, useState } from 'react'
import { Building2, CalendarPlus, ChevronRight, CircleUserRound, FileText, LogOut, Plus, Search, ShieldCheck, SlidersHorizontal, X } from 'lucide-react'
import { api, responseError } from './api'
import { MaintenanceWorkspace } from './MaintenanceWorkspace'

type User = { id: string; email: string; first_name: string; last_name: string; organization_id: string }
type Address = { line_1?: string; line_2?: string; suburb?: string; city?: string; province?: string; postal_code?: string; country?: string }
type Property = {
  id: string
  name: string
  property_type: string
  property_subtype?: string
  condition?: string
  address: Address
  current_value?: string | number
  original_value?: string | number
  cached_total_units: number
  cached_total_bedrooms: number
  cover_photo_url?: string
  created_at: string
}
type OwnershipParty = { id: string; name: string; party_type: string }
type OwnershipDocument = {
  id: string
  title: string
  document_type: string
  description?: string | null
  content_type?: string | null
  file_size_bytes?: number | null
  url?: string | null
  created_at: string
}
type OwnershipRecord = {
  id: string
  party: OwnershipParty
  ownership_percentage: string | number
  start_date: string
  end_date?: string | null
  effective_status: 'current' | 'historical' | 'upcoming'
  transfer_type?: string | null
  transfer_value?: string | number | null
  valuation_at_transfer?: string | number | null
  currency?: string | null
  transfer_reference?: string | null
  conveyancer?: string | null
  notes?: string | null
  verification_status: 'unverified' | 'pending_review' | 'verified'
  verified_at?: string | null
  verified_by?: { id: string; name: string } | null
  documents: OwnershipDocument[]
}
type LeaseRecord = {
  id: string
  unit_id: string
  tenant_id: string
  tenant_name: string
  status: string
  lease_type: string
  start_date: string
  end_date?: string | null
  created_at: string
  monthly_rent: number | string
  rent_currency?: string | null
  deposit_amount?: number | string | null
  pdf_filename?: string | null
  pdf_url?: string | null
}
type Portfolio = {
  property: Property
  buildings: Array<{ id: string; name: string; building_type?: string; units_count?: number }>
  units: Array<{ id: string; building_id: string; unit_number?: string; name?: string; unit_type?: string; bedrooms: number; bathrooms: number; floor_area?: number; status?: string; condition?: string }>
  rooms: Array<{ id: string; unit_id: string; room_name: string; room_type: string; floor_area?: number; status?: string; condition?: string }>
  items: Array<{ id: string; name: string; room_id: string; serial_number?: string; installed_at?: string; description?: string }>
  ownership: OwnershipRecord[]
  assignments: Array<{ id: string; user: { id: string; name: string; email: string }; assignment_type: string; starts_at: string; ends_at?: string }>
  inspections: Array<{ id: string; inspection_type: string; status: string; scheduled_on?: string; inspected_on?: string }>
  leases: LeaseRecord[]
  maintenance: Array<{ id: string; title: string; priority: string; status: string; reported_at: string; category?: string; currency?: string | null }>
  damage_assessments: Array<{ id: string; description: string; severity: string; responsibility: string; status: string; estimated_cost?: number | string | null; inspection_id?: string | null; inspection_item_id?: string | null; assessed_on: string }>
}
type InspectionDetail = {
  inspection: Portfolio['inspections'][number] & { notes?: string }
  rooms: Array<{ id: string; room_name: string; room_type: string; floor_number?: number; notes?: string; items: Array<{ id: string; item_name: string; item_type_name: string; condition: string; condition_score: number; damage_description?: string; estimated_cost?: number; responsibility?: string; notes?: string }> }>
}
type InspectionPhoto = { id: string; inspection_item_id?: string | null; url?: string | null; caption?: string | null; taken_at?: string | null }

type PropertyDraft = { name: string; property_type: string; property_subtype: string; city: string; condition: string }
const emptyDraft: PropertyDraft = { name: '', property_type: 'residential', property_subtype: 'single_family', city: '', condition: 'good' }
const MAX_PHOTO_UPLOAD_SIZE = 10 * 1024 * 1024
const PHOTO_SIZE_ERROR = 'Choose an image that is 10 MiB or smaller.'
const MAX_LEASE_PDF_UPLOAD_SIZE = 10 * 1024 * 1024

function App() {
  const [user, setUser] = useState<User | null>(() => JSON.parse(localStorage.getItem('property_platform_user') || 'null'))
  const [properties, setProperties] = useState<Property[]>([])
  const [selected, setSelected] = useState<Property | null>(null)
  const [portfolio, setPortfolio] = useState<Portfolio | null>(null)
  const [portfolioLoading, setPortfolioLoading] = useState(false)
  const [portfolioError, setPortfolioError] = useState('')
  const [inspection, setInspection] = useState<InspectionDetail | null>(null)
  const [inspectionForm, setInspectionForm] = useState<InspectionDetail | null>(null)
  const [showSchedule, setShowSchedule] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [showCreate, setShowCreate] = useState(false)

  useEffect(() => { if (user) loadProperties() }, [user])

  async function loadProperties() {
    setLoading(true); setError('')
    try { setProperties(await api<Property[]>('/properties')) } catch (err) { setError((err as Error).message) } finally { setLoading(false) }
  }

  async function openProperty(property: Property) {
    setSelected(property); setPortfolio(null); setPortfolioError(''); setPortfolioLoading(true)
    try { setPortfolio(await api<Portfolio>(`/properties/${property.id}/portfolio`)) } catch (err) { setPortfolioError((err as Error).message) } finally { setPortfolioLoading(false) }
  }

  function signOut() { localStorage.removeItem('property_platform_token'); localStorage.removeItem('property_platform_user'); setUser(null); setProperties([]) }
  const visibleProperties = properties.filter((property) => `${property.name} ${property.address.city || ''} ${property.property_type}`.toLowerCase().includes(search.toLowerCase()))

  if (!user) return <Login onLogin={(nextUser, token) => { localStorage.setItem('property_platform_token', token); localStorage.setItem('property_platform_user', JSON.stringify(nextUser)); setUser(nextUser) }} />

  return <div className="app-shell">
    <aside className="sidebar">
      <div className="brand"><span className="brand-mark"><Building2 size={18} /></span><span>Atlas / property</span></div>
      <nav><a className="active"><Building2 size={17} /> Portfolio <span className="nav-count">{properties.length}</span></a><a><ShieldCheck size={17} /> Inspections <span className="soon">soon</span></a><a><SlidersHorizontal size={17} /> Operations</a></nav>
      <div className="sidebar-footer"><div className="mini-user"><CircleUserRound size={30} /><div><strong>{user.first_name} {user.last_name}</strong><span>Portfolio manager</span></div></div><button className="logout" onClick={signOut}><LogOut size={15} /> Sign out</button></div>
    </aside>
    <main className="main-content">
      <header className="topbar"><div><p className="eyebrow">{new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })}</p><h1>Property portfolio</h1></div><button className="primary-button" onClick={() => setShowCreate(true)}><Plus size={17} /> Add property</button></header>
      <section className="stats"><div><span>Managed assets</span><strong>{properties.length.toString().padStart(2, '0')}</strong><small>Across your organization</small></div><div><span>Total units</span><strong>{properties.reduce((sum, property) => sum + property.cached_total_units, 0).toString().padStart(2, '0')}</strong><small>Connected to portfolio</small></div><div><span>Bedrooms</span><strong>{properties.reduce((sum, property) => sum + property.cached_total_bedrooms, 0).toString().padStart(2, '0')}</strong><small>Ready for inspection</small></div></section>
      <section className="workspace"><div className="section-heading"><div><p className="eyebrow">Your inventory</p><h2>All properties</h2></div><div className="search-wrap"><Search size={17} /><input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search properties" /></div></div>
        {error && <div className="error-banner">{error}<button onClick={() => setError('')}><X size={15} /></button></div>}
        {loading ? <div className="empty-state"><div className="spinner" /> Loading portfolio</div> : visibleProperties.length ? <div className="property-grid">{visibleProperties.map((property) => <button className={`property-card ${selected?.id === property.id ? 'selected' : ''}`} key={property.id} onClick={() => openProperty(property)}><div className="card-top">{property.cover_photo_url ? <img src={property.cover_photo_url} alt={property.name} style={{ height: 100, objectFit: 'cover', borderRadius: '6px 6px 0 0', display: 'block', margin: '-12px -12px 8px -12px', width: 'calc(100% + 24px)' }} /> : <span className="property-icon"><Building2 size={20} /></span>}<span className={`condition ${property.condition || 'good'}`}>{property.condition || 'active'}</span></div><div className="card-copy"><h3>{property.name}</h3><p>{property.address.city || 'Location pending'}{property.address.province ? `, ${property.address.province}` : ''}</p></div><div className="card-meta"><span>{property.property_type}</span><span>{property.cached_total_units} units <ChevronRight size={14} /></span></div></button>)}</div> : <div className="empty-state"><Building2 size={28} /><h3>No properties yet</h3><p>Create your first managed property to start building the portfolio.</p><button className="primary-button" onClick={() => setShowCreate(true)}><Plus size={17} /> Add property</button></div>}
      </section>
    </main>
    {selected && <PropertyDetailWorkspace property={selected} portfolio={portfolio} loading={portfolioLoading} error={portfolioError} onInspection={(inspectionId) => setInspectionId(selected.id, inspectionId)} onSchedule={() => setShowSchedule(true)} onPhotoUploaded={(url) => { setSelected((p) => p ? { ...p, cover_photo_url: url } : p); setProperties((ps) => ps.map((p) => p.id === selected.id ? { ...p, cover_photo_url: url } : p)) }} onClose={() => { setSelected(null); setPortfolio(null) }} />}
    {inspection && selected && <InspectionReview propertyId={selected.id} inspection={inspection} onStart={() => { setInspectionForm(inspection); setInspection(null) }} onClose={() => setInspection(null)} />}
    {inspectionForm && selected && <InspectionForm propertyId={selected.id} inspection={inspectionForm} onClose={() => setInspectionForm(null)} onSaved={() => { setInspectionForm(null); setInspection(null); openProperty(selected) }} />}
    {showSchedule && selected && <ScheduleInspection propertyId={selected.id} onClose={() => setShowSchedule(false)} onCreated={() => { setShowSchedule(false); openProperty(selected) }} />}
    {showCreate && <CreateProperty onClose={() => setShowCreate(false)} onCreated={(property) => { setProperties((current) => [...current, property]); setShowCreate(false); openProperty(property) }} />}
  </div>

  async function setInspectionId(propertyId: string, inspectionId: string) {
    try { setInspection(await api<InspectionDetail>(`/properties/${propertyId}/inspections/${inspectionId}`)) } catch (err) { setError((err as Error).message) }
  }
}

function Login({ onLogin }: { onLogin: (user: User, token: string) => void }) {
  const [email, setEmail] = useState('admin@acme.example'); const [password, setPassword] = useState('password123'); const [error, setError] = useState(''); const [loading, setLoading] = useState(false)
  async function submit(event: React.FormEvent) { event.preventDefault(); setLoading(true); setError(''); try { const result = await api<{ token: string; user: User }>('/login', { method: 'POST', body: JSON.stringify({ email, password }) }); onLogin(result.user, result.token) } catch (err) { setError((err as Error).message) } finally { setLoading(false) } }
  return <div className="login-page"><div className="login-art"><div className="brand light"><span className="brand-mark"><Building2 size={18} /></span><span>Atlas / property</span></div><div className="art-copy"><p className="eyebrow">Operations, made visible</p><h1>Know every<br /><em>place</em> you manage.</h1><p>A focused command center for property teams, from the first handover to the final inspection.</p></div><div className="art-footer">01 <span /> Property registry</div></div><form className="login-card" onSubmit={submit}><div className="mobile-brand brand"><span className="brand-mark"><Building2 size={18} /></span><span>Atlas / property</span></div><p className="eyebrow">Welcome back</p><h2>Sign in to your workspace</h2><p className="login-help">Use your organization account to open the portfolio.</p><label>Email address<input value={email} onChange={(event) => setEmail(event.target.value)} type="email" required /></label><label>Password<input value={password} onChange={(event) => setPassword(event.target.value)} type="password" required /></label>{error && <div className="form-error">{error}</div>}<button className="primary-button full" disabled={loading}>{loading ? 'Signing in...' : 'Enter workspace'} <ChevronRight size={17} /></button><p className="demo-hint">Demo access is prefilled for local development.</p></form></div>
}

function PropertyDetailWorkspace({ property, portfolio, loading, error, onInspection, onSchedule, onPhotoUploaded, onClose }: { property: Property; portfolio: Portfolio | null; loading: boolean; error: string; onInspection: (inspectionId: string) => void; onSchedule: () => void; onPhotoUploaded: (url: string) => void; onClose: () => void }) {
  const [tab, setTab] = useState('overview')
  const tabs = [['overview', 'Overview'], ['structure', 'Structure'], ['inventory', 'Inventory'], ['ownership', 'Ownership'], ['access', 'Access'], ['inspections', 'Inspections'], ['leases', 'Leases'], ['maintenance', 'Maintenance']]
  return <div className="drawer-backdrop" onClick={onClose}><aside className="detail-workspace" onClick={(event) => event.stopPropagation()}><div className="detail-header"><div><p className="eyebrow">Property workspace</p><h2>{property.name}</h2><p>{property.address.city || 'Location pending'}{property.address.province ? `, ${property.address.province}` : ''}</p></div><button className="icon-button" onClick={onClose}><X size={18} /></button></div><div className="detail-tabs">{tabs.map(([value, label]) => <button className={tab === value ? 'active' : ''} key={value} onClick={() => setTab(value)}>{label}</button>)}</div>{loading ? <div className="detail-loading"><div className="spinner" /> Loading property workspace</div> : error ? <div className="detail-error"><X size={17} /><p>{error}</p></div> : portfolio && <div className="detail-content">{tab === 'overview' && <OverviewPanel property={property} portfolio={portfolio} onPhotoUploaded={onPhotoUploaded} />}{tab === 'structure' && <StructurePanel portfolio={portfolio} />}{tab === 'inventory' && <InventoryPanel portfolio={portfolio} />}{tab === 'ownership' && <OwnershipPanel property={property} portfolio={portfolio} />}{tab === 'access' && <AccessPanel portfolio={portfolio} />}{tab === 'inspections' && <InspectionsPanel portfolio={portfolio} onInspection={onInspection} onSchedule={onSchedule} />}{tab === 'leases' && <LeasesPanel propertyId={property.id} portfolio={portfolio} />  }{tab === 'maintenance' && <MaintenanceWorkspace propertyId={property.id} portfolio={portfolio} />}</div>}</aside></div>
}

function OverviewPanel({ property, portfolio, onPhotoUploaded }: { property: Property; portfolio: Portfolio; onPhotoUploaded: (url: string) => void }) {
  const [uploading, setUploading] = useState(false)
  const [uploadError, setUploadError] = useState('')

  async function uploadCover(file: File) {
    setUploadError('')
    if (file.size > MAX_PHOTO_UPLOAD_SIZE) {
      setUploadError(PHOTO_SIZE_ERROR)
      return
    }

    setUploading(true)
    try {
      const form = new FormData()
      form.append('file', file)
      const token = localStorage.getItem('property_platform_token')
      const res = await fetch(`/api/v1/properties/${property.id}/photos`, {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: form,
      })
      if (!res.ok) throw new Error(await responseError(res))
      const data = await res.json()
      if (!data.cover_photo_url) throw new Error('The upload did not return a cover photo URL.')
      onPhotoUploaded(data.cover_photo_url)
    } catch (err) {
      setUploadError(err instanceof Error ? err.message : 'Photo upload failed.')
    } finally { setUploading(false) }
  }

  return <>
    <div className="workspace-hero" style={{ position: 'relative', padding: 0, overflow: 'hidden', borderRadius: 8, marginBottom: 16 }}>
      {property.cover_photo_url
        ? <img src={property.cover_photo_url} alt={property.name} style={{ width: '100%', height: 180, objectFit: 'cover', display: 'block' }} />
        : <div style={{ width: '100%', height: 180, background: '#f0f0ec', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Building2 size={40} color="#c0bdb5" /></div>}
      <div style={{ position: 'absolute', bottom: 10, right: 10 }}>
        <label style={{ cursor: 'pointer', background: 'rgba(0,0,0,0.55)', color: '#fff', fontSize: 12, padding: '5px 10px', borderRadius: 5, display: 'flex', alignItems: 'center', gap: 5 }}>
          <input type="file" accept="image/*" style={{ display: 'none' }} disabled={uploading} onChange={(e) => { const f = e.target.files?.[0]; if (f) uploadCover(f); e.currentTarget.value = '' }} />
          {uploading ? 'Uploading…' : '📷 Change photo'}
        </label>
      </div>
      <span className={`condition ${property.condition || 'good'}`} style={{ position: 'absolute', top: 10, right: 10 }}>{property.condition || 'active'}</span>
    </div>
    {uploadError && <div className="form-error" role="alert">{uploadError}</div>}
    <div style={{ padding: '0 4px 12px' }}>
      <h3 style={{ margin: '0 0 4px' }}>{property.property_type} property</h3>
      <p style={{ margin: 0, color: '#57606a', fontSize: 13 }}>{property.address.line_1 || 'Address not supplied'}<br />{property.address.city || 'City pending'}{property.address.province ? `, ${property.address.province}` : ''}</p>
    </div>
    <div className="detail-metrics"><Metric label="Buildings" value={portfolio.buildings.length} /><Metric label="Units" value={portfolio.units.length} /><Metric label="Bedrooms" value={property.cached_total_bedrooms} /><Metric label="Inventory" value={portfolio.items.length} /></div>
    <div className="detail-callout"><ShieldCheck size={17} /><div><strong>Protected portfolio</strong><p>Every record shown here is scoped to your active property assignment.</p></div></div>
  </>
}
function StructurePanel({ portfolio }: { portfolio: Portfolio }) { return <DataPanel title="Buildings & units" count={portfolio.units.length}>{portfolio.buildings.length ? portfolio.buildings.map((building) => <div className="data-group" key={building.id}><div className="data-row"><div><strong>{building.name}</strong><span>{building.building_type || 'Building'} · {building.units_count || portfolio.units.filter((unit) => unit.building_id === building.id).length} units</span></div><Building2 size={16} /></div>{portfolio.units.filter((unit) => unit.building_id === building.id).map((unit) => <div className="nested-row" key={unit.id}><span>{unit.unit_number || unit.name || 'Unit'}</span><small>{unit.bedrooms} bed · {unit.bathrooms} bath · {unit.status || 'active'}</small></div>)}</div>) : <EmptyPanel label="No buildings recorded yet" />}</DataPanel> }
function InventoryPanel({ portfolio }: { portfolio: Portfolio }) { return <DataPanel title="Inventory" count={portfolio.items.length}>{portfolio.items.length ? portfolio.items.map((item) => <div className="data-row" key={item.id}><div><strong>{item.name}</strong><span>{item.description || 'No description'}</span></div><small>{item.serial_number || 'Unserialized'}</small></div>) : <EmptyPanel label="No inventory recorded yet" />}</DataPanel> }
const ownershipTransferTypes = [
  ['sale_purchase', 'Sale / purchase'],
  ['inheritance', 'Inheritance'],
  ['donation', 'Donation'],
  ['gift', 'Gift'],
  ['court_order', 'Court order'],
  ['family_transfer', 'Family transfer'],
  ['company_trust_transfer', 'Company or trust transfer'],
  ['other', 'Other'],
]
const ownershipPartyTypes = [
  ['individual', 'Individual'],
  ['company', 'Company'],
  ['trust', 'Trust'],
  ['government', 'Government'],
  ['other', 'Other'],
]
const ownershipCurrencies = [
  ['USD', 'USD — US Dollar'],
  ['ZAR', 'ZAR — South African Rand'],
]

function OwnershipCurrencyField({ currency, onChange, required, additionalCurrency }: {
  currency: string
  onChange: (currency: string) => void
  required: boolean
  additionalCurrency?: string | null
}) {
  const currencies = additionalCurrency && !ownershipCurrencies.some(([code]) => code === additionalCurrency)
    ? [...ownershipCurrencies, [additionalCurrency, additionalCurrency]]
    : ownershipCurrencies

  return <label>Currency denomination{required && <span className="ownership-required">Required for financial values</span>}
    <select required={required} value={currency} onChange={(event) => onChange(event.target.value)}>
      {required ? <option value="" disabled>Select currency</option> : <option value="">Not specified</option>}
      {currencies.map(([code, label]) => <option value={code} key={code}>{label}</option>)}
    </select>
    <span className="ownership-field-help">Amounts stay in the selected currency; changing it does not convert them.</span>
  </label>
}

function localDateKey(date = new Date()) {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

function ownershipStatus(record: OwnershipRecord, today: string) {
  if (record.start_date > today) return 'upcoming'
  if (record.end_date && record.end_date <= today) return 'historical'
  return 'current'
}

function ownershipMoney(value?: string | number | null, currency?: string | null) {
  if (value == null || !Number.isFinite(Number(value))) return 'Not recorded'
  const amount = Number(value).toLocaleString(undefined, { maximumFractionDigits: 2 })
  return currency ? `${currency} ${amount}` : `Currency not recorded · ${amount}`
}

function dateDaysBetween(from: string, to: string) {
  const [fromYear, fromMonth, fromDay] = from.split('-').map(Number)
  const [toYear, toMonth, toDay] = to.split('-').map(Number)
  return Math.round((Date.UTC(toYear, toMonth - 1, toDay) - Date.UTC(fromYear, fromMonth - 1, fromDay)) / 86_400_000)
}

function OwnershipPanel({ property, portfolio }: { property: Property; portfolio: Portfolio }) {
  const [records, setRecords] = useState(portfolio.ownership)
  const [parties, setParties] = useState<OwnershipParty[]>([])
  const [partiesLoading, setPartiesLoading] = useState(true)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [formMode, setFormMode] = useState<'record' | 'transfer' | null>(null)
  const [editingRecord, setEditingRecord] = useState<OwnershipRecord | null>(null)
  const [closingRecord, setClosingRecord] = useState<OwnershipRecord | null>(null)
  const today = localDateKey()

  useEffect(() => {
    let active = true
    refreshParties()
      .then((loadedParties) => { if (active) setParties(loadedParties) })
      .catch((err) => { if (active) setError(err instanceof Error ? err.message : 'Owners could not be loaded.') })
      .finally(() => { if (active) setPartiesLoading(false) })
    return () => { active = false }
  }, [])

  useEffect(() => setRecords(portfolio.ownership), [portfolio.ownership])

  async function refreshRecords() {
    setRecords(await api<OwnershipRecord[]>(`/properties/${property.id}/ownership`))
  }

  async function refreshParties() {
    return api<OwnershipParty[]>('/parties')
  }

  async function afterSave(message: string) {
    setFormMode(null)
    setEditingRecord(null)
    setClosingRecord(null)
    setError('')
    try {
      const [updatedRecords, updatedParties] = await Promise.all([
        api<OwnershipRecord[]>(`/properties/${property.id}/ownership`),
        refreshParties(),
      ])
      setRecords(updatedRecords)
      setParties(updatedParties)
      setNotice(message)
    } catch (err) {
      setError(`The change was saved, but ownership data could not be refreshed: ${err instanceof Error ? err.message : 'Request failed'}`)
    }
  }

  async function updateVerification(record: OwnershipRecord, status: OwnershipRecord['verification_status']) {
    setError('')
    setNotice('')
    try {
      await api(`/properties/${property.id}/ownership/${record.id}`, {
        method: 'PATCH',
        body: JSON.stringify({ property_ownership: { verification_status: status } }),
      })
      setNotice('Verification status updated.')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Verification status could not be updated.')
      return
    }
    try {
      await refreshRecords()
    } catch (err) {
      setError(`Verification status was updated, but history could not be refreshed: ${err instanceof Error ? err.message : 'Request failed'}`)
    }
  }

  const chronologicalRecords = [...records].sort((a, b) => a.start_date.localeCompare(b.start_date) || a.id.localeCompare(b.id))
  const currentOwners = chronologicalRecords.filter((record) => ownershipStatus(record, today) === 'current')
  const upcomingRecords = chronologicalRecords.filter((record) => ownershipStatus(record, today) === 'upcoming')
  const ownerCount = new Set(chronologicalRecords.map((record) => record.party.id)).size
  const eventDates = [...new Set(chronologicalRecords.map((record) => record.start_date))].sort()
  const effectiveEventDates = eventDates.filter((date) => date <= today)
  const latestEventDate = effectiveEventDates[effectiveEventDates.length - 1]
  const changeDates = [...new Set(chronologicalRecords.flatMap((record) => [record.start_date, record.end_date]).filter((date): date is string => Boolean(date && date <= today)))].sort()
  const latestChangeDate = changeDates[changeDates.length - 1]
  const latestEventRecords = latestEventDate ? chronologicalRecords.filter((record) => record.start_date === latestEventDate) : []
  const earliestRecord = chronologicalRecords[0]
  const transferDates = Math.max(0, changeDates.length - 1)
  const currentPercentage = currentOwners.reduce((total, record) => total + Number(record.ownership_percentage), 0)
  const address = [
    property.address.line_1,
    property.address.line_2,
    property.address.suburb,
    property.address.city,
    property.address.province,
    property.address.country,
  ].filter(Boolean).join(', ') || 'Address not recorded'
  const latestPriceRecords = latestEventRecords.filter((record) => record.transfer_value != null)
  const latestPriceVariants = new Set(latestPriceRecords.map((record) => `${record.currency || ''}:${record.transfer_value}`))
  const latestPrice = latestPriceVariants.size === 1
    ? ownershipMoney(latestPriceRecords[0].transfer_value, latestPriceRecords[0].currency)
    : latestPriceVariants.size > 1 ? 'Different amounts · see entries' : 'Not recorded'
  const acquisitionValue = property.original_value ?? earliestRecord?.transfer_value
  const acquisitionCurrency = property.original_value != null ? null : earliestRecord?.currency
  const acquisitionValueNote = property.original_value != null
    ? 'Original value currency is not recorded.'
    : earliestRecord?.transfer_value != null
      ? `Recorded transaction currency: ${earliestRecord.currency || 'not recorded'}.`
      : 'No original acquisition value is recorded.'
  const elapsedDays = latestChangeDate ? dateDaysBetween(latestChangeDate, today) : null
  const upcomingDate = upcomingRecords[0]?.start_date
  const fullShareWarning = currentOwners.length > 0 && currentPercentage < 100

  return <section className="ownership-workspace">
    <div className="ownership-workspace-heading">
      <div>
        <p className="eyebrow">Property registry</p>
        <h3>Property Ownership &amp; Transaction History</h3>
        <strong>{property.name}</strong>
        <p>{address}</p>
      </div>
      <div className="ownership-actions">
        <button className="secondary-button" disabled={partiesLoading} onClick={() => { setError(''); setFormMode('transfer') }}>Record transfer</button>
        <button className="primary-button" disabled={partiesLoading} onClick={() => { setError(''); setEditingRecord(null); setFormMode('record') }}><Plus size={15} /> Add ownership record</button>
      </div>
    </div>

    {error && <div className="form-error ownership-message" role="alert">{error}</div>}
    {notice && <div className="ownership-notice" role="status">{notice}</div>}
    {partiesLoading && <div className="detail-loading ownership-loading">Loading owner list...</div>}

    <section className="ownership-current">
      <div className="ownership-current-heading">
        <div><p className="eyebrow">Current owner{currentOwners.length === 1 ? '' : 's'} on record</p><h4>{currentOwners.length ? 'Ownership on record' : upcomingDate ? 'No current owner recorded' : 'Current ownership unavailable'}</h4></div>
        <span className={`ownership-state ${currentOwners.length ? 'current' : 'unavailable'}`}>{currentOwners.length ? 'Current' : upcomingDate ? 'Transfer scheduled' : 'Not recorded'}</span>
      </div>
      {currentOwners.length ? <div className="ownership-owner-list">
        {currentOwners.map((record) => <div className="ownership-owner-chip" key={record.id}>
          <strong>{record.party.name}</strong><span>{record.party.party_type} · {record.ownership_percentage}%</span>
        </div>)}
      </div> : <p className="ownership-empty-copy">{upcomingDate ? `Incoming ownership begins ${upcomingDate}.` : 'Add verified or unverified records to establish current ownership.'}</p>}
      {fullShareWarning && <p className="ownership-warning" role="status">Recorded active shares total {currentPercentage.toLocaleString()}%. Confirm whether the remainder is intentionally unallocated.</p>}
    </section>
    <p className="ownership-disclaimer">Verification statuses reflect an internal evidence review and are not legal determinations of title.</p>

    <div className="ownership-stat-grid">
      <div className="ownership-stat"><span>Recorded owners</span><strong>{ownerCount}</strong></div>
      <div className="ownership-stat"><span>Transfers recorded</span><strong>{transferDates}</strong></div>
      <div className="ownership-stat"><span>Original acquisition value</span><strong>{ownershipMoney(acquisitionValue, acquisitionCurrency)}</strong><small>{acquisitionValueNote}</small></div>
      <div className="ownership-stat"><span>Most recent transaction price</span><strong>{latestPrice}</strong><small>{latestEventDate || 'No transaction recorded'}</small></div>
      <div className="ownership-stat"><span>Current estimated value</span><strong>{ownershipMoney(property.current_value)}</strong><small>Current valuation currency is not recorded.</small></div>
      <div className="ownership-stat"><span>Since last recorded change</span><strong>{elapsedDays == null ? '—' : `${elapsedDays} day${elapsedDays === 1 ? '' : 's'}`}</strong><small>{latestChangeDate || 'No ownership event recorded'}</small></div>
    </div>

    {upcomingDate && <div className="ownership-upcoming"><strong>Upcoming transfer</strong><span>{currentOwners.length ? `Current records remain active before ${upcomingDate}; incoming ownership begins on that date.` : `No current owner is recorded; incoming ownership begins on ${upcomingDate}.`}</span></div>}

    <div className="ownership-timeline-heading">
      <div><p className="eyebrow">Chronological record</p><h4>Ownership timeline</h4></div>
      <span>{records.length} record{records.length === 1 ? '' : 's'}</span>
    </div>
    {chronologicalRecords.length ? <ol className="ownership-timeline">
      {chronologicalRecords.map((record) => {
        const status = ownershipStatus(record, today)
        const statusLabel = status === 'upcoming' ? 'Upcoming' : status === 'current' ? 'Current owner' : 'Previous owner'
        const transferType = ownershipTransferTypes.find(([value]) => value === record.transfer_type)?.[1] || record.transfer_type?.replace(/_/g, ' ') || 'Transfer type not recorded'
        return <li className={`ownership-entry ownership-entry-${status}`} key={record.id}>
          <details>
            <summary>
              <span className="ownership-timeline-dot" />
              <div className="ownership-entry-summary">
                <span className="ownership-entry-kicker">{statusLabel} · {record.start_date} · {transferType}</span>
                <strong>{record.party.name}</strong>
                <span>{record.party.party_type} · {record.ownership_percentage}%{record.end_date ? ` · Ends ${record.end_date}` : status === 'current' ? ' · No end date recorded' : ''}</span>
                <span className="ownership-entry-price">Transfer price: {ownershipMoney(record.transfer_value, record.currency)} · Valuation at transfer: {ownershipMoney(record.valuation_at_transfer, record.currency)}</span>
              </div>
              <span className={`ownership-verification-badge ${record.verification_status}`}>{record.verification_status.replace('_', ' ')}</span>
            </summary>
            <div className="ownership-entry-details">
              <div className="ownership-detail-grid">
                <div><span>Acquisition date</span><strong>{record.start_date}</strong></div>
                <div><span>Ownership end date</span><strong>{record.end_date || (status === 'upcoming' ? 'Not set' : 'Current / open')}</strong></div>
                <div><span>Ownership share</span><strong>{record.ownership_percentage}%</strong></div>
                <div><span>Transfer type</span><strong>{transferType}</strong></div>
                <div><span>Transfer price</span><strong>{ownershipMoney(record.transfer_value, record.currency)}</strong></div>
                <div><span>Valuation at transfer</span><strong>{ownershipMoney(record.valuation_at_transfer, record.currency)}</strong></div>
                <div><span>Currency</span><strong>{record.currency || 'Not recorded'}</strong></div>
                <div><span>Transfer / deed reference</span><strong>{record.transfer_reference || 'Not recorded'}</strong></div>
                <div><span>Conveyancer</span><strong>{record.conveyancer || 'Not recorded'}</strong></div>
                <div><span>Verification</span><strong>{record.verification_status.replace('_', ' ')}</strong></div>
                {record.verified_by && <div><span>Verified by</span><strong>{record.verified_by.name}</strong></div>}
              </div>
              <div className="ownership-record-notes"><span>Notes</span><p>{record.notes || 'No transaction notes recorded.'}</p></div>
              <label className="ownership-verification-control">Update verification status
                <select value={record.verification_status} onChange={(event) => updateVerification(record, event.target.value as OwnershipRecord['verification_status'])}>
                  <option value="unverified">Unverified</option>
                  <option value="pending_review">Pending review</option>
                  <option value="verified">Verified</option>
                </select>
              </label>
              <OwnershipDocuments propertyId={property.id} record={record} onUploaded={() => refreshRecords()} />
              <div className="ownership-entry-actions">
                <button className="secondary-button" onClick={() => { setError(''); setEditingRecord(record); setFormMode('record') }}>Edit record</button>
                {status === 'current' && <button className="secondary-button" onClick={() => { setError(''); setClosingRecord(record) }}>Close ownership</button>}
              </div>
            </div>
          </details>
        </li>
      })}
    </ol> : <EmptyPanel label="No ownership history recorded yet. Add a retrospective record or record a transfer." />}

    {formMode === 'record' && <OwnershipRecordForm
      propertyId={property.id}
      parties={parties}
      record={editingRecord}
      onClose={() => { setFormMode(null); setEditingRecord(null) }}
      onSaved={() => afterSave(editingRecord ? 'Ownership record updated.' : 'Ownership record added.')}
    />}
    {formMode === 'transfer' && <OwnershipTransferForm
      propertyId={property.id}
      parties={parties}
      onClose={() => setFormMode(null)}
      onSaved={() => afterSave('Ownership transfer recorded.')}
    />}
    {closingRecord && <CloseOwnershipForm
      propertyId={property.id}
      record={closingRecord}
      onClose={() => setClosingRecord(null)}
      onSaved={() => afterSave('Ownership record closed.')}
    />}
  </section>
}

function OwnershipRecordForm({ propertyId, parties, record, onClose, onSaved }: {
  propertyId: string
  parties: OwnershipParty[]
  record: OwnershipRecord | null
  onClose: () => void
  onSaved: () => void
}) {
  const [partyMode, setPartyMode] = useState<'existing' | 'new'>(record || parties.length ? 'existing' : 'new')
  const [partyId, setPartyId] = useState(record?.party.id || parties[0]?.id || '')
  const [partyName, setPartyName] = useState('')
  const [partyType, setPartyType] = useState('individual')
  const [ownershipPercentage, setOwnershipPercentage] = useState(record?.ownership_percentage.toString() || '100')
  const [startDate, setStartDate] = useState(record?.start_date || localDateKey())
  const [endDate, setEndDate] = useState(record?.end_date || '')
  const [transferType, setTransferType] = useState(record?.transfer_type || '')
  const [transferValue, setTransferValue] = useState(record?.transfer_value?.toString() || '')
  const [valuation, setValuation] = useState(record?.valuation_at_transfer?.toString() || '')
  const [currency, setCurrency] = useState(record ? record.currency || '' : 'USD')
  const [reference, setReference] = useState(record?.transfer_reference || '')
  const [conveyancer, setConveyancer] = useState(record?.conveyancer || '')
  const [notes, setNotes] = useState(record?.notes || '')
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)
  const amountEntered = Boolean(transferValue || valuation)

  async function submit(event: React.FormEvent) {
    event.preventDefault()
    setSaving(true)
    setError('')
    try {
      await api(`/properties/${propertyId}/ownership${record ? `/${record.id}` : ''}`, {
        method: record ? 'PATCH' : 'POST',
        body: JSON.stringify({
          property_ownership: {
            party_id: partyMode === 'existing' ? partyId : undefined,
            party: partyMode === 'new' ? { name: partyName, party_type: partyType } : undefined,
            ownership_percentage: Number(ownershipPercentage),
            start_date: startDate,
            end_date: endDate || null,
            transfer_type: transferType || null,
            transfer_value: transferValue === '' ? null : Number(transferValue),
            valuation_at_transfer: valuation === '' ? null : Number(valuation),
            currency: currency.trim().toUpperCase() || null,
            transfer_reference: reference || null,
            conveyancer: conveyancer || null,
            notes: notes || null,
          },
        }),
      })
      onSaved()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Ownership record could not be saved.')
    } finally {
      setSaving(false)
    }
  }

  return <div className="modal-backdrop" onClick={onClose}>
    <form className="modal ownership-modal" onClick={(event) => event.stopPropagation()} onSubmit={submit}>
      <div className="modal-header">
        <div><p className="eyebrow">Ownership registry</p><h2>{record ? 'Edit ownership record' : 'Add ownership record'}</h2></div>
        <button type="button" className="icon-button" aria-label="Close ownership form" onClick={onClose}><X size={18} /></button>
      </div>
      <div className="ownership-form-scroll">
        <label>Owner source
          <select value={partyMode} onChange={(event) => setPartyMode(event.target.value as 'existing' | 'new')}>
            <option value="existing" disabled={!parties.length && !record}>Select existing party</option>
            <option value="new">Create new party</option>
          </select>
        </label>
        {partyMode === 'existing' ? <label>Owner
          <select required value={partyId} onChange={(event) => setPartyId(event.target.value)}>
            <option value="">Select a party</option>
            {parties.map((party) => <option value={party.id} key={party.id}>{party.name} · {party.party_type}</option>)}
          </select>
        </label> : <div className="form-grid">
          <label>Owner / registered entity name<input required value={partyName} onChange={(event) => setPartyName(event.target.value)} /></label>
          <label>Party type
            <select value={partyType} onChange={(event) => setPartyType(event.target.value)}>
              {ownershipPartyTypes.map(([value, label]) => <option value={value} key={value}>{label}</option>)}
            </select>
          </label>
        </div>}
        <div className="form-grid">
          <label>Ownership percentage<input required type="number" min="0.01" max="100" step="0.01" value={ownershipPercentage} onChange={(event) => setOwnershipPercentage(event.target.value)} /></label>
          <label>Acquisition date<input required type="date" value={startDate} onChange={(event) => setStartDate(event.target.value)} /></label>
        </div>
        <label>Ownership end date (optional)<input type="date" min={startDate} value={endDate} onChange={(event) => setEndDate(event.target.value)} /><span className="ownership-field-help">Ownership ends at the start of this date; transfer records use the same effective date.</span></label>
        <label>How was ownership acquired?
          <select value={transferType} onChange={(event) => setTransferType(event.target.value)}>
            <option value="">Not recorded</option>
            {ownershipTransferTypes.map(([value, label]) => <option value={value} key={value}>{label}</option>)}
          </select>
        </label>
        <div className="form-grid">
          <label>Transfer price<input type="number" min="0" step="0.01" value={transferValue} onChange={(event) => setTransferValue(event.target.value)} placeholder="Optional" /></label>
          <label>Valuation at transfer<input type="number" min="0" step="0.01" value={valuation} onChange={(event) => setValuation(event.target.value)} placeholder="Optional" /></label>
        </div>
        <OwnershipCurrencyField currency={currency} onChange={setCurrency} required={amountEntered} additionalCurrency={record?.currency} />
        <div className="form-grid">
          <label>Transfer / deed reference<input value={reference} onChange={(event) => setReference(event.target.value)} /></label>
          <label>Conveyancer / legal representative<input value={conveyancer} onChange={(event) => setConveyancer(event.target.value)} /></label>
        </div>
        <label>Transaction notes<textarea rows={3} value={notes} onChange={(event) => setNotes(event.target.value)} placeholder="Optional historical context or transaction notes" /></label>
        <p className="ownership-form-note">New records start as unverified. Verification is an internal evidence review, not a legal determination. Historical dates are not restricted by the property's platform registration date.</p>
        {error && <div className="form-error" role="alert">{error}</div>}
      </div>
      <div className="modal-actions">
        <button type="button" className="secondary-button" onClick={onClose}>Cancel</button>
        <button className="primary-button" disabled={saving}>{saving ? 'Saving...' : record ? 'Save changes' : 'Add record'}</button>
      </div>
    </form>
  </div>
}

type IncomingOwnerDraft = {
  key: number
  partyMode: 'existing' | 'new'
  partyId: string
  partyName: string
  partyType: string
  ownershipPercentage: string
}

function OwnershipTransferForm({ propertyId, parties, onClose, onSaved }: {
  propertyId: string
  parties: OwnershipParty[]
  onClose: () => void
  onSaved: () => void
}) {
  const [effectiveOn, setEffectiveOn] = useState(localDateKey())
  const [transferType, setTransferType] = useState('sale_purchase')
  const [transferValue, setTransferValue] = useState('')
  const [valuation, setValuation] = useState('')
  const [currency, setCurrency] = useState('USD')
  const [reference, setReference] = useState('')
  const [conveyancer, setConveyancer] = useState('')
  const [notes, setNotes] = useState('')
  const [incomingOwners, setIncomingOwners] = useState<IncomingOwnerDraft[]>([{
    key: 1,
    partyMode: parties.length ? 'existing' : 'new',
    partyId: parties[0]?.id || '',
    partyName: '',
    partyType: 'individual',
    ownershipPercentage: '100',
  }])
  const [nextKey, setNextKey] = useState(2)
  const [confirmed, setConfirmed] = useState(false)
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)
  const amountEntered = Boolean(transferValue || valuation)
  const totalPercentage = incomingOwners.reduce((total, owner) => total + Number(owner.ownershipPercentage || 0), 0)

  function updateOwner(key: number, changes: Partial<IncomingOwnerDraft>) {
    setIncomingOwners((current) => current.map((owner) => owner.key === key ? { ...owner, ...changes } : owner))
  }

  function addOwner() {
    setIncomingOwners((current) => [...current, {
      key: nextKey,
      partyMode: parties.length ? 'existing' : 'new',
      partyId: parties[0]?.id || '',
      partyName: '',
      partyType: 'individual',
      ownershipPercentage: '',
    }])
    setNextKey((value) => value + 1)
  }

  async function submit(event: React.FormEvent) {
    event.preventDefault()
    setSaving(true)
    setError('')
    try {
      await api(`/properties/${propertyId}/ownership/transfers`, {
        method: 'POST',
        body: JSON.stringify({
          transfer: {
            effective_on: effectiveOn,
            transfer_type: transferType,
            transfer_value: transferValue === '' ? null : Number(transferValue),
            valuation_at_transfer: valuation === '' ? null : Number(valuation),
            currency: currency.trim().toUpperCase() || null,
            transfer_reference: reference || null,
            conveyancer: conveyancer || null,
            notes: notes || null,
            incoming_owners: incomingOwners.map((owner) => ({
              party_id: owner.partyMode === 'existing' ? owner.partyId : undefined,
              party: owner.partyMode === 'new' ? { name: owner.partyName, party_type: owner.partyType } : undefined,
              ownership_percentage: Number(owner.ownershipPercentage),
            })),
          },
        }),
      })
      onSaved()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Transfer could not be recorded.')
    } finally {
      setSaving(false)
    }
  }

  return <div className="modal-backdrop" onClick={onClose}>
    <form className="modal ownership-modal ownership-transfer-modal" onClick={(event) => event.stopPropagation()} onSubmit={submit}>
      <div className="modal-header">
        <div><p className="eyebrow">Ownership workflow</p><h2>Record ownership transfer</h2></div>
        <button type="button" className="icon-button" aria-label="Close transfer form" onClick={onClose}><X size={18} /></button>
      </div>
      <div className="ownership-form-scroll">
        <p className="ownership-form-note">This atomic transaction ends every current ownership record at the start of the transfer date and begins incoming ownership on that date. Include any co-owners who will remain owners after the transfer. Prior records are retained.</p>
        <label>Effective transfer date<input required type="date" value={effectiveOn} onChange={(event) => setEffectiveOn(event.target.value)} /></label>
        <label>Transfer type
          <select required value={transferType} onChange={(event) => setTransferType(event.target.value)}>
            {ownershipTransferTypes.map(([value, label]) => <option value={value} key={value}>{label}</option>)}
          </select>
        </label>
        <div className="ownership-incoming-heading"><h3>Incoming owners</h3><button type="button" className="secondary-button" onClick={addOwner}><Plus size={14} /> Add co-owner</button></div>
        {incomingOwners.map((owner, index) => <div className="ownership-owner-draft" key={owner.key}>
          <div className="ownership-owner-draft-heading"><strong>Owner {index + 1}</strong>{incomingOwners.length > 1 && <button type="button" className="ownership-remove-owner" onClick={() => setIncomingOwners((current) => current.filter((entry) => entry.key !== owner.key))}>Remove</button>}</div>
          <label>Owner source
            <select value={owner.partyMode} onChange={(event) => updateOwner(owner.key, { partyMode: event.target.value as 'existing' | 'new' })}>
              <option value="existing" disabled={!parties.length}>Select existing party</option>
              <option value="new">Create new party</option>
            </select>
          </label>
          {owner.partyMode === 'existing' ? <label>Owner
            <select required value={owner.partyId} onChange={(event) => updateOwner(owner.key, { partyId: event.target.value })}>
              <option value="">Select a party</option>
              {parties.map((party) => <option value={party.id} key={party.id}>{party.name} · {party.party_type}</option>)}
            </select>
          </label> : <div className="form-grid">
            <label>Owner / entity name<input required value={owner.partyName} onChange={(event) => updateOwner(owner.key, { partyName: event.target.value })} /></label>
            <label>Party type
              <select value={owner.partyType} onChange={(event) => updateOwner(owner.key, { partyType: event.target.value })}>
                {ownershipPartyTypes.map(([value, label]) => <option value={value} key={value}>{label}</option>)}
              </select>
            </label>
          </div>}
          <label>Ownership percentage<input required type="number" min="0.01" max="100" step="0.01" value={owner.ownershipPercentage} onChange={(event) => updateOwner(owner.key, { ownershipPercentage: event.target.value })} /></label>
        </div>)}
        <p className={totalPercentage > 100 ? 'ownership-warning' : 'ownership-share-summary'}>Incoming shares total {totalPercentage.toLocaleString()}%{totalPercentage < 100 ? ' — the unallocated share will remain unassigned.' : ''}</p>
        <div className="form-grid">
          <label>Transfer price<input type="number" min="0" step="0.01" value={transferValue} onChange={(event) => setTransferValue(event.target.value)} placeholder="Optional; may be zero or blank" /></label>
          <label>Valuation at transfer<input type="number" min="0" step="0.01" value={valuation} onChange={(event) => setValuation(event.target.value)} placeholder="Optional" /></label>
        </div>
        <OwnershipCurrencyField currency={currency} onChange={setCurrency} required={amountEntered} />
        <div className="form-grid">
          <label>Transfer / deed reference<input value={reference} onChange={(event) => setReference(event.target.value)} /></label>
          <label>Conveyancer / legal representative<input value={conveyancer} onChange={(event) => setConveyancer(event.target.value)} /></label>
        </div>
        <label>Transaction notes<textarea rows={3} value={notes} onChange={(event) => setNotes(event.target.value)} /></label>
        <label className="ownership-confirm"><input type="checkbox" required checked={confirmed} onChange={(event) => setConfirmed(event.target.checked)} /> I confirm the incoming owners and shares reflect ownership after this transfer.</label>
        {error && <div className="form-error" role="alert">{error}</div>}
      </div>
      <div className="modal-actions">
        <button type="button" className="secondary-button" onClick={onClose}>Cancel</button>
        <button className="primary-button" disabled={saving || totalPercentage > 100}>{saving ? 'Recording transfer...' : 'Record transfer'}</button>
      </div>
    </form>
  </div>
}

function CloseOwnershipForm({ propertyId, record, onClose, onSaved }: {
  propertyId: string
  record: OwnershipRecord
  onClose: () => void
  onSaved: () => void
}) {
  const [endDate, setEndDate] = useState(localDateKey())
  const [confirmed, setConfirmed] = useState(false)
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)

  async function submit(event: React.FormEvent) {
    event.preventDefault()
    setSaving(true)
    setError('')
    try {
      await api(`/properties/${propertyId}/ownership/${record.id}/close`, {
        method: 'POST',
        body: JSON.stringify({ end_date: endDate }),
      })
      onSaved()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Ownership record could not be closed.')
    } finally {
      setSaving(false)
    }
  }

  return <div className="modal-backdrop" onClick={onClose}>
    <form className="modal ownership-modal ownership-close-modal" onClick={(event) => event.stopPropagation()} onSubmit={submit}>
      <div className="modal-header">
        <div><p className="eyebrow">Preserve ownership history</p><h2>Close ownership record</h2></div>
        <button type="button" className="icon-button" aria-label="Close dialog" onClick={onClose}><X size={18} /></button>
      </div>
      <div className="ownership-form-scroll">
        <p>Close {record.party.name}'s {record.ownership_percentage}% record. The history and supporting documents will remain available.</p>
        <label>Ownership ends effective on<input required type="date" min={record.start_date} value={endDate} onChange={(event) => setEndDate(event.target.value)} /><span className="ownership-field-help">This date is exclusive: the record is no longer active from this date.</span></label>
        <label className="ownership-confirm"><input type="checkbox" required checked={confirmed} onChange={(event) => setConfirmed(event.target.checked)} /> I confirm this owner no longer holds this share from the selected date.</label>
        {error && <div className="form-error" role="alert">{error}</div>}
      </div>
      <div className="modal-actions">
        <button type="button" className="secondary-button" onClick={onClose}>Cancel</button>
        <button className="primary-button" disabled={saving}>{saving ? 'Closing...' : 'Close record'}</button>
      </div>
    </form>
  </div>
}

function OwnershipDocuments({ propertyId, record, onUploaded }: {
  propertyId: string
  record: OwnershipRecord
  onUploaded: () => Promise<void> | void
}) {
  const [file, setFile] = useState<File | null>(null)
  const [title, setTitle] = useState('')
  const [documentType, setDocumentType] = useState('title_deed')
  const [uploading, setUploading] = useState(false)
  const [error, setError] = useState('')
  const [fileInputKey, setFileInputKey] = useState(0)
  const documents = record.documents ?? []

  async function upload(event: React.FormEvent) {
    event.preventDefault()
    if (!file) return
    setError('')
    if (file.size > 10 * 1024 * 1024) {
      setError('Choose a document that is 10 MiB or smaller.')
      return
    }

    setUploading(true)
    try {
      const body = new FormData()
      body.append('file', file)
      body.append('title', title || file.name)
      body.append('document_type', documentType)
      const token = localStorage.getItem('property_platform_token')
      const response = await fetch(`/api/v1/properties/${propertyId}/ownership/${record.id}/documents`, {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body,
      })
      if (!response.ok) throw new Error(await responseError(response))
      setFile(null)
      setTitle('')
      setFileInputKey((key) => key + 1)
      try {
        await onUploaded()
      } catch (err) {
        setError(`Document uploaded, but the history could not be refreshed: ${err instanceof Error ? err.message : 'Request failed'}`)
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Document upload failed.')
    } finally {
      setUploading(false)
    }
  }

  return <section className="ownership-documents">
    <h4><FileText size={14} /> Supporting documents</h4>
    {documents.length ? <ul>
      {documents.map((document) => <li key={document.id}>
        {document.url ? <a href={document.url} target="_blank" rel="noreferrer">{document.title}</a> : <span>{document.title} · File unavailable</span>}
        <small>{document.document_type.replace(/_/g, ' ')} · {new Date(document.created_at).toLocaleDateString()}</small>
      </li>)}
    </ul> : <p>No supporting documents have been added.</p>}
    <form className="ownership-document-form" onSubmit={upload}>
      <div className="form-grid">
        <label>Document type
          <select value={documentType} onChange={(event) => setDocumentType(event.target.value)}>
            <option value="title_deed">Title deed</option>
            <option value="sale_agreement">Sale agreement</option>
            <option value="transfer_document">Transfer document</option>
            <option value="inheritance_document">Inheritance document</option>
            <option value="court_order">Court order</option>
            <option value="other">Other</option>
          </select>
        </label>
        <label>Document title<input value={title} onChange={(event) => setTitle(event.target.value)} placeholder={file?.name || 'Optional label'} /></label>
      </div>
      <label>Choose document<input key={fileInputKey} type="file" accept=".pdf,.jpg,.jpeg,.png,.webp,.doc,.docx" required onChange={(event) => setFile(event.target.files?.[0] ?? null)} /></label>
      {error && <div className="form-error" role="alert">{error}</div>}
      <button className="secondary-button" disabled={uploading || !file}>{uploading ? 'Uploading...' : 'Upload supporting document'}</button>
    </form>
  </section>
}

function AccessPanel({ portfolio }: { portfolio: Portfolio }) { return <DataPanel title="Property access" count={portfolio.assignments.length}>{portfolio.assignments.length ? portfolio.assignments.map((record) => <div className="data-row" key={record.id}><div><strong>{record.user.name}</strong><span>{record.user.email}</span></div><small>{record.assignment_type}</small></div>) : <EmptyPanel label="No active assignments" />}</DataPanel> }
function InspectionsPanel({ portfolio, onInspection, onSchedule }: { portfolio: Portfolio; onInspection: (inspectionId: string) => void; onSchedule: () => void }) { return <DataPanel title="Inspections" count={portfolio.inspections.length}><button className="secondary-button schedule-button" onClick={onSchedule}><CalendarPlus size={15} /> Schedule inspection</button>{portfolio.inspections.length ? portfolio.inspections.map((inspection) => <button className="inspection-row" key={inspection.id} onClick={() => onInspection(inspection.id)}><div><strong>{inspection.inspection_type.replace('_', ' ')}</strong><span>{inspection.scheduled_on || inspection.inspected_on || 'Date pending'}</span></div><small className={`status-${inspection.status}`}>{inspection.status}</small><ChevronRight size={15} /></button>) : <EmptyPanel label="No inspections scheduled" />}</DataPanel> }
function Metric({ label, value }: { label: string; value: number }) { return <div><span>{label}</span><strong>{value.toString().padStart(2, '0')}</strong></div> }
function DataPanel({ title, count, children }: { title: string; count: number; children: React.ReactNode }) { return <section className="data-panel"><div className="panel-heading"><h3>{title}</h3><span>{count.toString().padStart(2, '0')} records</span></div>{children}</section> }
function EmptyPanel({ label }: { label: string }) { return <div className="panel-empty"><span>{label}</span></div> }
function LeasesPanel({ propertyId, portfolio }: { propertyId: string; portfolio: Portfolio }) {
  const [leases, setLeases] = useState(portfolio.leases ?? [])
  const [showForm, setShowForm] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => setLeases(portfolio.leases ?? []), [portfolio.leases])

  const unitHistories = portfolio.units.map((unit) => ({
    unit,
    leases: leases
      .filter((lease) => lease.unit_id === unit.id)
      .sort((a, b) => b.start_date.localeCompare(a.start_date) || b.created_at.localeCompare(a.created_at)),
  })).filter((history) => history.leases.length > 0)

  return <section className="data-panel">
    <div className="panel-heading lease-panel-heading">
      <div><h3>Lease history</h3><span>{leases.length} stored · latest 5 shown per unit</span></div>
      <button className="primary-button" disabled={!portfolio.units.length} onClick={() => { setError(''); setShowForm(true) }}><Plus size={15} /> Add lease</button>
    </div>
    {error && <div className="form-error" role="alert">{error}</div>}
    {unitHistories.length ? unitHistories.map(({ unit, leases: unitLeases }) => {
      const label = unit.unit_number || unit.name || 'Unit'
      const visibleLeases = unitLeases.slice(0, 5)
      return <section className="lease-unit-history" key={unit.id}>
        <h4>{label}</h4>
        {visibleLeases.map((lease) => <div className="lease-row" key={lease.id}>
          <div className="lease-row-main">
            <strong>{lease.tenant_name || 'Tenant not recorded'}</strong>
            <span>{lease.lease_type.replace(/_/g, ' ')} · {lease.start_date} to {lease.end_date || 'End date not recorded'}</span>
            <small className={`status-${lease.status}`}>{lease.status}</small>
          </div>
          <div className="lease-row-side">
            <strong>{lease.rent_currency || 'Currency not recorded'} {Number(lease.monthly_rent).toLocaleString()}/mo</strong>
            {lease.pdf_url
              ? <a href={lease.pdf_url} target="_blank" rel="noreferrer">{lease.pdf_filename || 'View lease PDF'}</a>
              : <span>PDF not attached</span>}
          </div>
        </div>)}
        {unitLeases.length > 5 && <p className="lease-history-note">Showing the latest 5 of {unitLeases.length} leases. Older lease records remain stored.</p>}
      </section>
    }) : <EmptyPanel label={portfolio.units.length ? 'No leases recorded yet' : 'Add a unit before recording a lease'} />}
    {showForm && <LeaseForm
      propertyId={propertyId}
      units={portfolio.units}
      onClose={() => setShowForm(false)}
      onSaved={(lease) => {
        setLeases((current) => [lease, ...current.filter((record) => record.id !== lease.id)])
        setShowForm(false)
      }}
    />}
  </section>
}

function LeaseForm({ propertyId, units, onClose, onSaved }: {
  propertyId: string
  units: Portfolio['units']
  onClose: () => void
  onSaved: (lease: LeaseRecord) => void
}) {
  const [parties, setParties] = useState<OwnershipParty[]>([])
  const [tenantMode, setTenantMode] = useState<'existing' | 'new'>('new')
  const [tenantId, setTenantId] = useState('')
  const [tenantName, setTenantName] = useState('')
  const [tenantType, setTenantType] = useState('individual')
  const [unitId, setUnitId] = useState(units[0]?.id || '')
  const [startDate, setStartDate] = useState(localDateKey())
  const [endDate, setEndDate] = useState('')
  const [leaseType, setLeaseType] = useState('fixed_term')
  const [monthlyRent, setMonthlyRent] = useState('')
  const [rentCurrency, setRentCurrency] = useState('ZAR')
  const [depositAmount, setDepositAmount] = useState('')
  const [termsSummary, setTermsSummary] = useState('')
  const [file, setFile] = useState<File | null>(null)
  const [partyError, setPartyError] = useState('')
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    let active = true
    api<OwnershipParty[]>('/parties')
      .then((loadedParties) => { if (active) setParties(loadedParties) })
      .catch((err) => { if (active) setPartyError(err instanceof Error ? err.message : 'Existing parties could not be loaded.') })
    return () => { active = false }
  }, [])

  async function submit(event: React.FormEvent) {
    event.preventDefault()
    if (!file) {
      setError('Choose the signed lease PDF.')
      return
    }
    if (file.size > MAX_LEASE_PDF_UPLOAD_SIZE) {
      setError('Lease PDF must be 10 MiB or smaller.')
      return
    }

    setSaving(true)
    setError('')
    try {
      const body = new FormData()
      body.append('lease[unit_id]', unitId)
      if (tenantMode === 'existing') {
        body.append('lease[tenant_id]', tenantId)
      } else {
        body.append('lease[tenant][name]', tenantName)
        body.append('lease[tenant][party_type]', tenantType)
      }
      body.append('lease[start_date]', startDate)
      body.append('lease[end_date]', endDate)
      body.append('lease[lease_type]', leaseType)
      body.append('lease[monthly_rent]', monthlyRent)
      body.append('lease[rent_currency]', rentCurrency)
      if (depositAmount) body.append('lease[deposit_amount]', depositAmount)
      if (termsSummary) body.append('lease[terms_summary]', termsSummary)
      body.append('lease_pdf', file)

      const token = localStorage.getItem('property_platform_token')
      const response = await fetch(`/api/v1/properties/${propertyId}/leases`, {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body,
      })
      if (!response.ok) throw new Error(await responseError(response))
      onSaved(await response.json() as LeaseRecord)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Lease could not be saved.')
    } finally {
      setSaving(false)
    }
  }

  return <div className="modal-backdrop" onClick={onClose}>
    <form className="modal lease-modal" onClick={(event) => event.stopPropagation()} onSubmit={submit}>
      <div className="modal-header">
        <div><p className="eyebrow">Lease records</p><h2>Store signed lease</h2></div>
        <button type="button" className="icon-button" aria-label="Close lease form" onClick={onClose}><X size={18} /></button>
      </div>
      <div className="lease-form-scroll">
        {partyError && <p className="lease-form-note" role="status">{partyError} You can still add a new tenant.</p>}
        <label>Unit
          <select required value={unitId} onChange={(event) => setUnitId(event.target.value)}>
            {units.map((unit) => <option value={unit.id} key={unit.id}>{unit.unit_number || unit.name || 'Unit'}</option>)}
          </select>
        </label>
        <label>Tenant source
          <select value={tenantMode} onChange={(event) => setTenantMode(event.target.value as 'existing' | 'new')}>
            <option value="new">Create tenant record</option>
            <option value="existing" disabled={!parties.length}>Select existing party</option>
          </select>
        </label>
        {tenantMode === 'existing' ? <label>Tenant / party
          <select required value={tenantId} onChange={(event) => setTenantId(event.target.value)}>
            <option value="">Select a party</option>
            {parties.map((party) => <option value={party.id} key={party.id}>{party.name} · {party.party_type}</option>)}
          </select>
        </label> : <div className="form-grid">
          <label>Tenant / entity name<input required value={tenantName} onChange={(event) => setTenantName(event.target.value)} /></label>
          <label>Party type
            <select value={tenantType} onChange={(event) => setTenantType(event.target.value)}>
              {ownershipPartyTypes.map(([value, label]) => <option value={value} key={value}>{label}</option>)}
            </select>
          </label>
        </div>}
        <div className="form-grid">
          <label>Lease begins<input required type="date" value={startDate} onChange={(event) => setStartDate(event.target.value)} /></label>
          <label>Lease ends<input required type="date" min={startDate} value={endDate} onChange={(event) => setEndDate(event.target.value)} /></label>
        </div>
        <label>Lease type
          <select value={leaseType} onChange={(event) => setLeaseType(event.target.value)}>
            <option value="fixed_term">Fixed term</option>
            <option value="month_to_month">Month to month</option>
            <option value="periodic">Periodic</option>
          </select>
        </label>
        <div className="form-grid">
          <label>Monthly rent<input required type="number" min="0" step="0.01" value={monthlyRent} onChange={(event) => setMonthlyRent(event.target.value)} /></label>
          <label>Rent currency
            <select value={rentCurrency} onChange={(event) => setRentCurrency(event.target.value)}>
              <option value="ZAR">ZAR</option>
              <option value="USD">USD</option>
            </select>
          </label>
        </div>
        <label>Deposit amount (optional)<input type="number" min="0" step="0.01" value={depositAmount} onChange={(event) => setDepositAmount(event.target.value)} /></label>
        <label>Lease summary (optional)<textarea rows={3} value={termsSummary} onChange={(event) => setTermsSummary(event.target.value)} /></label>
        <label>Signed lease PDF<input type="file" accept="application/pdf,.pdf" required onChange={(event) => setFile(event.target.files?.[0] ?? null)} /></label>
        <p className="lease-form-note">PDF files only, up to 10 MiB. Lease dates and rent are stored with the document.</p>
        {error && <div className="form-error" role="alert">{error}</div>}
      </div>
      <div className="modal-actions">
        <button type="button" className="secondary-button" onClick={onClose}>Cancel</button>
        <button className="primary-button" disabled={saving}>{saving ? 'Saving lease...' : 'Save lease'}</button>
      </div>
    </form>
  </div>
}
function ScheduleInspection({ propertyId, onClose, onCreated }: { propertyId: string; onClose: () => void; onCreated: () => void }) { const [inspectionType, setInspectionType] = useState('routine'); const [scheduledOn, setScheduledOn] = useState(''); const [notes, setNotes] = useState(''); const [error, setError] = useState(''); const [loading, setLoading] = useState(false); async function submit(event: React.FormEvent) { event.preventDefault(); setLoading(true); setError(''); try { await api(`/properties/${propertyId}/inspections`, { method: 'POST', body: JSON.stringify({ inspection: { inspection_type: inspectionType, scheduled_on: scheduledOn || undefined, notes: notes || undefined } }) }); onCreated() } catch (err) { setError((err as Error).message) } finally { setLoading(false) } } return <div className="modal-backdrop" onClick={onClose}><form className="modal" onClick={(event) => event.stopPropagation()} onSubmit={submit}><div className="modal-header"><div><p className="eyebrow">Inspection workflow</p><h2>Schedule inspection</h2></div><button type="button" className="icon-button" onClick={onClose}><X size={18} /></button></div><div className="form-grid"><label>Type<select value={inspectionType} onChange={(event) => setInspectionType(event.target.value)}><option value="routine">Routine</option><option value="move_in">Move in</option><option value="move_out">Move out</option><option value="periodic">Periodic</option></select></label><label>Date<input type="date" value={scheduledOn} onChange={(event) => setScheduledOn(event.target.value)} /></label></div><label>Notes<textarea value={notes} onChange={(event) => setNotes(event.target.value)} placeholder="Optional inspection context" rows={4} /></label>{error && <div className="form-error">{error}</div>}<div className="modal-actions"><button type="button" className="secondary-button" onClick={onClose}>Cancel</button><button className="primary-button" disabled={loading}>{loading ? 'Scheduling...' : 'Schedule inspection'} <CalendarPlus size={16} /></button></div></form></div> }

function InspectionReview({ propertyId, inspection, onStart, onClose }: { propertyId: string; inspection: InspectionDetail; onStart: () => void; onClose: () => void }) {
  const [photos, setPhotos] = useState<InspectionPhoto[]>([])
  const [photosLoading, setPhotosLoading] = useState(true)
  const [photoError, setPhotoError] = useState('')
  const [selectedItem, setSelectedItem] = useState<InspectionDetail['rooms'][number]['items'][number] | null>(null)
  const items = inspection.rooms.flatMap((room) => room.items)
  const average = items.length
    ? (items.reduce((total, item) => total + item.condition_score, 0) / items.length).toFixed(1)
    : '—'
  const photosByItem = new Map<string, InspectionPhoto[]>()

  useEffect(() => {
    let cancelled = false
    setPhotos([])
    setPhotoError('')
    setPhotosLoading(true)
    api<InspectionPhoto[]>(`/properties/${propertyId}/inspections/${inspection.inspection.id}/photos`)
      .then((loadedPhotos) => {
        if (!cancelled) setPhotos(loadedPhotos)
      })
      .catch((err) => {
        if (!cancelled) setPhotoError(err instanceof Error ? err.message : 'Inspection images could not be loaded.')
      })
      .finally(() => {
        if (!cancelled) setPhotosLoading(false)
      })
    return () => { cancelled = true }
  }, [propertyId, inspection.inspection.id])

  photos.forEach((photo) => {
    if (!photo.inspection_item_id) return
    const itemPhotos = photosByItem.get(photo.inspection_item_id) ?? []
    itemPhotos.push(photo)
    photosByItem.set(photo.inspection_item_id, itemPhotos)
  })

  const selectedRoom = selectedItem
    ? inspection.rooms.find((room) => room.items.some((item) => item.id === selectedItem.id))
    : undefined
  const selectedPhotos = selectedItem ? (photosByItem.get(selectedItem.id) ?? []).filter((photo) => photo.url) : []

  return <div className="drawer-backdrop" onClick={onClose}>
    <aside className="inspection-review" onClick={(event) => event.stopPropagation()}>
      <div className="detail-header">
        <div>
          <p className="eyebrow">Inspection review</p>
          <h2>{inspection.inspection.inspection_type.replace('_', ' ')}</h2>
          <p>{inspection.inspection.inspected_on || inspection.inspection.scheduled_on || 'Date pending'} · {inspection.inspection.status}</p>
        </div>
        <button className="icon-button" onClick={onClose}><X size={18} /></button>
      </div>
      <div className="inspection-summary">
        <div><span>Rooms</span><strong>{inspection.rooms.length}</strong></div>
        <div><span>Items checked</span><strong>{items.length}</strong></div>
        <div><span>Average score</span><strong>{average}<small>/ 5</small></strong></div>
      </div>
      <div className="inspection-body">
        {photosLoading && <p className="inspection-photo-status">Loading inspection images...</p>}
        {photoError && <p className="inspection-photo-error" role="alert">Inspection images could not be loaded: {photoError}</p>}
        {inspection.inspection.status !== 'locked' && <button className="primary-button full" onClick={onStart}>Start room inspection</button>}
        {inspection.rooms.length ? inspection.rooms.map((room) => <section className="review-room" key={room.id}>
          <div className="review-room-heading">
            <div><p className="eyebrow">{room.room_type}</p><h3>{room.room_name}</h3></div>
            <span>{room.items.length} items</span>
          </div>
          {room.items.length ? room.items.map((item) => <button type="button" className="review-item" key={item.id} onClick={() => setSelectedItem(item)}>
            <div className="review-item-copy">
              <strong>{item.item_name}</strong>
              <span>{item.item_type_name} · Condition: {item.condition}</span>
              <p className="review-item-description">{item.notes?.trim() || 'No condition description added.'}</p>
              {item.damage_description && <p className="review-item-damage">Damage: {item.damage_description}</p>}
              {photosByItem.get(item.id)?.some((photo) => photo.url) && <span className="review-thumbnails">
                {photosByItem.get(item.id)?.filter((photo) => photo.url).map((photo) => <img key={photo.id} src={photo.url ?? undefined} alt={`${item.item_name} inspection thumbnail`} loading="lazy" />)}
              </span>}
            </div>
            <b className={`score score-${item.condition_score}`}>{item.condition_score}/5</b>
          </button>) : <EmptyPanel label="No snapshot items" />}
        </section>) : <EmptyPanel label="No inspection rooms recorded" />}
      </div>
      {selectedItem && <div className="inspection-item-backdrop" onClick={() => setSelectedItem(null)}>
        <section className="inspection-item-report" role="dialog" aria-modal="true" aria-labelledby="inspection-item-title" onClick={(event) => event.stopPropagation()}>
          <div className="inspection-item-report-header">
            <div>
              <p className="eyebrow">{selectedRoom?.room_name || 'Inspection item'} · {selectedItem.item_type_name}</p>
              <h2 id="inspection-item-title">{selectedItem.item_name}</h2>
            </div>
            <button type="button" className="icon-button" aria-label="Close item report" onClick={() => setSelectedItem(null)}><X size={18} /></button>
          </div>
          <div className="inspection-item-report-body">
            <div className="inspection-item-result">
              <div><span>Condition</span><strong>{selectedItem.condition}</strong></div>
              <div><span>Rating</span><strong>{selectedItem.condition_score}/5</strong></div>
            </div>
            <section className="inspection-report-field">
              <h3>Condition description</h3>
              <p>{selectedItem.notes?.trim() || 'No condition description added.'}</p>
            </section>
            {selectedItem.damage_description && <section className="inspection-report-field">
              <h3>Damage</h3>
              <p>{selectedItem.damage_description}</p>
            </section>}
            {(selectedItem.responsibility || selectedItem.estimated_cost != null) && <section className="inspection-report-field inspection-report-extra">
              {selectedItem.responsibility && <div><span>Responsibility</span><strong>{selectedItem.responsibility}</strong></div>}
              {selectedItem.estimated_cost != null && <div><span>Estimated cost</span><strong>{selectedItem.estimated_cost}</strong></div>}
            </section>}
            <section className="inspection-report-field">
              <h3>Inspection images</h3>
              {photosLoading ? <p>Loading inspection images...</p> : selectedPhotos.length ? <div className="inspection-report-images">
                {selectedPhotos.map((photo) => <figure key={photo.id}>
                  <img src={photo.url ?? undefined} alt={`${selectedItem.item_name} inspection`} />
                  <figcaption>{photo.caption || (photo.taken_at ? `Taken ${new Date(photo.taken_at).toLocaleString()}` : 'Inspection photo')}</figcaption>
                </figure>)}
              </div> : <p>{photoError ? `Images could not be loaded: ${photoError}` : 'No images attached to this item.'}</p>}
            </section>
          </div>
        </section>
      </div>}
    </aside>
  </div>
}

function InspectionForm({ propertyId, inspection, onClose, onSaved }: { propertyId: string; inspection: InspectionDetail; onClose: () => void; onSaved: () => void }) {
  const [rooms, setRooms] = useState(inspection.rooms)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [uploading, setUploading] = useState<string | null>(null)
  const [photoUrls, setPhotoUrls] = useState<Record<string, string>>({})

  function updateItem(roomId: string, itemId: string, changes: Partial<InspectionDetail['rooms'][number]['items'][number]>) {
    setRooms((current) => current.map((room) => room.id === roomId
      ? { ...room, items: room.items.map((item) => item.id === itemId ? { ...item, ...changes } : item) }
      : room))
  }

  async function uploadPhoto(inspectionRoomId: string, itemId: string, file: File) {
    setError('')
    if (file.size > MAX_PHOTO_UPLOAD_SIZE) {
      setError(PHOTO_SIZE_ERROR)
      return
    }

    setUploading(itemId)
    try {
      const form = new FormData()
      form.append('file', file)
      form.append('inspection_room_id', inspectionRoomId)
      form.append('inspection_item_id', itemId)
      const token = localStorage.getItem('property_platform_token')
      const res = await fetch(`/api/v1/properties/${propertyId}/inspections/${inspection.inspection.id}/photos`, {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: form,
      })
      if (!res.ok) throw new Error(await responseError(res))
      const photo = await res.json()
      if (!photo.url) throw new Error('The upload did not return a photo URL.')
      setPhotoUrls((prev) => ({ ...prev, [itemId]: photo.url }))
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Photo upload failed.')
    } finally { setUploading(null) }
  }

  async function submit(event: React.FormEvent) {
    event.preventDefault(); setSaving(true); setError('')
    try {
      await api(`/properties/${propertyId}/inspections/${inspection.inspection.id}`, {
        method: 'PATCH',
        body: JSON.stringify({
          status: 'completed',
          inspected_on: new Date().toISOString().slice(0, 10),
          rooms: rooms.map((room) => ({
            id: room.id, notes: room.notes,
            items: room.items.map((item) => ({
              id: item.id, condition: item.condition, condition_score: item.condition_score,
              damage_description: item.damage_description, responsibility: item.responsibility, notes: item.notes
            }))
          }))
        })
      })
      onSaved()
    } catch (err) { setError((err as Error).message) } finally { setSaving(false) }
  }

  return <div className="drawer-backdrop" onClick={onClose}>
    <form className="inspection-form" onClick={(event) => event.stopPropagation()} onSubmit={submit}>
      <div className="detail-header">
        <div><p className="eyebrow">Move-in inspection</p><h2>Room checklist</h2><p>Rate every item from 1 to 5 before completing.</p></div>
        <button type="button" className="icon-button" onClick={onClose}><X size={18} /></button>
      </div>
      <div className="inspection-form-body">
        {rooms.map((room) => <section className="form-room" key={room.id}>
          <div className="review-room-heading"><div><p className="eyebrow">{room.room_type}</p><h3>{room.room_name}</h3></div><span>{room.items.length} checks</span></div>
          {room.items.map((item) => <div className="form-item" key={item.id}>
            <div className="form-item-header">
              <div><strong>{item.item_name}</strong><span>{item.condition}</span></div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <div className="rating-control">
                  {[1, 2, 3, 4, 5].map((score) => <button type="button" className={item.condition_score === score ? 'selected' : ''} key={score} onClick={() => updateItem(room.id, item.id, { condition_score: score, condition: score <= 2 ? 'poor' : score === 3 ? 'fair' : 'good' })}>{score}</button>)}
                </div>
                {photoUrls[item.id]
                  ? <a href={photoUrls[item.id]} target="_blank" rel="noreferrer" title="View photo">
                      <img src={photoUrls[item.id]} alt="inspection photo" style={{ width: 36, height: 36, objectFit: 'cover', borderRadius: 4, border: '1px solid #e5e7eb' }} />
                    </a>
                  : <label title="Attach photo" style={{ cursor: 'pointer', color: '#87938a', fontSize: 14 }}>
                      <input type="file" accept="image/*" style={{ display: 'none' }} disabled={uploading === item.id}
                        onChange={(e) => { const f = e.target.files?.[0]; if (f) uploadPhoto(room.id, item.id, f) }} />
                      {uploading === item.id ? <span style={{ fontSize: 10 }}>…</span> : '📎'}
                    </label>}
              </div>
            </div>
            <label className="inspection-item-description">
              <span>Condition description</span>
              <textarea
                rows={2}
                value={item.notes ?? ''}
                placeholder="Describe the item's condition in this room..."
                onChange={(event) => updateItem(room.id, item.id, { notes: event.target.value })}
              />
            </label>
          </div>)}
        </section>)}
        {error && <div className="form-error">{error}</div>}
        <div className="modal-actions" style={{ marginTop: 24 }}>
          <button type="button" className="secondary-button" onClick={onClose}>Cancel</button>
          <button className="primary-button" disabled={saving}>{saving ? 'Saving inspection...' : 'Complete inspection'} <ShieldCheck size={16} /></button>
        </div>
      </div>
    </form>
  </div>
}

function PropertyDrawer({ property, onClose }: { property: Property; onClose: () => void }) { return <div className="drawer-backdrop" onClick={onClose}><aside className="drawer" onClick={(event) => event.stopPropagation()}><div className="drawer-header"><span className="eyebrow">Property profile</span><button className="icon-button" onClick={onClose}><X size={18} /></button></div><div className="drawer-hero"><span className="property-icon large"><Building2 size={25} /></span><p className="eyebrow">{property.property_type}</p><h2>{property.name}</h2><p>{property.address.line_1 || 'Address not supplied'}<br />{property.address.city || 'City pending'}{property.address.province ? `, ${property.address.province}` : ''}</p></div><div className="detail-list"><div><span>Condition</span><strong>{property.condition || 'Not rated'}</strong></div><div><span>Units</span><strong>{property.cached_total_units}</strong></div><div><span>Bedrooms</span><strong>{property.cached_total_bedrooms}</strong></div><div><span>Current value</span><strong>{property.current_value ? `$${Number(property.current_value).toLocaleString()}` : 'Not supplied'}</strong></div></div><div className="drawer-note"><ShieldCheck size={17} /><p>Access is protected by your active property assignment.</p></div></aside></div> }

function CreateProperty({ onClose, onCreated }: { onClose: () => void; onCreated: (property: Property) => void }) {
  const [draft, setDraft] = useState(emptyDraft)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [photoPreview, setPhotoPreview] = useState<string | null>(null)
  const [photoFile, setPhotoFile] = useState<File | null>(null)

  function pickFile(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0]
    if (!f) return
    if (f.size > MAX_PHOTO_UPLOAD_SIZE) {
      setPhotoFile(null)
      setPhotoPreview(null)
      setError(PHOTO_SIZE_ERROR)
      e.currentTarget.value = ''
      return
    }
    setError('')
    setPhotoFile(f)
    setPhotoPreview(URL.createObjectURL(f))
  }

  async function submit(event: React.FormEvent) {
    event.preventDefault(); setLoading(true); setError('')
    try {
      const property = await api<Property>('/properties', { method: 'POST', body: JSON.stringify({ property: draft }) })
      if (photoFile) {
        const form = new FormData()
        form.append('file', photoFile)
        const token = localStorage.getItem('property_platform_token')
        const res = await fetch(`/api/v1/properties/${property.id}/photos`, {
          method: 'POST', headers: token ? { Authorization: `Bearer ${token}` } : {}, body: form,
        })
        if (res.ok) {
          const data = await res.json()
          onCreated({ ...property, cover_photo_url: data.cover_photo_url })
          return
        }
      }
      onCreated(property)
    } catch (err) { setError((err as Error).message) } finally { setLoading(false) }
  }

  return <div className="modal-backdrop" onClick={onClose}>
    <form className="modal" onClick={(e) => e.stopPropagation()} onSubmit={submit}>
      <div className="modal-header">
        <div><p className="eyebrow">Portfolio registry</p><h2>Add a property</h2></div>
        <button type="button" className="icon-button" onClick={onClose}><X size={18} /></button>
      </div>

      {/* Cover photo picker */}
      <label style={{ display: 'block', cursor: 'pointer', marginBottom: 16 }}>
        <p className="eyebrow" style={{ marginBottom: 6 }}>Cover photo <span style={{ color: '#87938a', fontWeight: 400, textTransform: 'none', letterSpacing: 0 }}>— optional, up to 10 MiB</span></p>
        <input type="file" accept="image/*" style={{ display: 'none' }} onChange={pickFile} />
        <div style={{ width: '100%', height: 140, borderRadius: 8, overflow: 'hidden', background: '#f0f0ec', display: 'flex', alignItems: 'center', justifyContent: 'center', border: '2px dashed #d1cfc8' }}>
          {photoPreview
            ? <img src={photoPreview} alt="preview" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
            : <div style={{ textAlign: 'center', color: '#87938a' }}><div style={{ fontSize: 28 }}>📷</div><p style={{ margin: '6px 0 0', fontSize: 12 }}>Click to add a photo</p></div>}
        </div>
      </label>

      <label>Property name<input value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })} placeholder="e.g. Acme House" required /></label>
      <div className="form-grid">
        <label>Type<select value={draft.property_type} onChange={(e) => setDraft({ ...draft, property_type: e.target.value })}><option value="residential">Residential</option><option value="commercial">Commercial</option><option value="mixed_use">Mixed use</option></select></label>
        <label>Condition<select value={draft.condition} onChange={(e) => setDraft({ ...draft, condition: e.target.value })}><option value="good">Good</option><option value="fair">Fair</option><option value="poor">Poor</option></select></label>
      </div>
      <label>City<input value={draft.city} onChange={(e) => setDraft({ ...draft, city: e.target.value })} placeholder="Cape Town" /></label>

      {error && <div className="form-error">{error}</div>}
      <div className="modal-actions">
        <button type="button" className="secondary-button" onClick={onClose}>Cancel</button>
        <button className="primary-button" disabled={loading}>{loading ? (photoFile ? 'Uploading…' : 'Creating...') : 'Create property'} <Plus size={16} /></button>
      </div>
    </form>
  </div>
}

export default App
