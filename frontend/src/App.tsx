import { useEffect, useState } from 'react'
import { Building2, CalendarPlus, ChevronRight, CircleUserRound, LogOut, Plus, Search, ShieldCheck, SlidersHorizontal, X } from 'lucide-react'

type User = { id: string; email: string; first_name: string; last_name: string; organization_id: string }
type Address = { line_1?: string; suburb?: string; city?: string; province?: string; postal_code?: string; country?: string }
type Property = {
  id: string
  name: string
  property_type: string
  property_subtype?: string
  condition?: string
  address: Address
  current_value?: string | number
  cached_total_units: number
  cached_total_bedrooms: number
  cover_photo_url?: string
  created_at: string
}
type Portfolio = {
  property: Property
  buildings: Array<{ id: string; name: string; building_type?: string; units_count?: number }>
  units: Array<{ id: string; building_id: string; unit_number?: string; name?: string; unit_type?: string; bedrooms: number; bathrooms: number; floor_area?: number; status?: string; condition?: string }>
  rooms: Array<{ id: string; unit_id: string; room_name: string; room_type: string; floor_area?: number; status?: string; condition?: string }>
  items: Array<{ id: string; name: string; room_id: string; serial_number?: string; installed_at?: string; description?: string }>
  ownership: Array<{ id: string; party: { name: string; party_type: string }; ownership_percentage: number; start_date: string; end_date?: string }>
  assignments: Array<{ id: string; user: { name: string; email: string }; assignment_type: string; starts_at: string; ends_at?: string }>
  inspections: Array<{ id: string; inspection_type: string; status: string; scheduled_on?: string; inspected_on?: string }>
  leases: Array<{ id: string; unit_id: string; status: string; lease_type: string; start_date: string; end_date?: string; monthly_rent: number | string; tenant_name?: string }>
  maintenance: Array<{ id: string; title: string; priority: string; status: string; reported_at: string; category?: string }>
}
type InspectionDetail = {
  inspection: Portfolio['inspections'][number] & { notes?: string }
  rooms: Array<{ id: string; room_name: string; room_type: string; floor_number?: number; notes?: string; items: Array<{ id: string; item_name: string; item_type_name: string; condition: string; condition_score: number; damage_description?: string; estimated_cost?: number; responsibility?: string; notes?: string }> }>
}

type PropertyDraft = { name: string; property_type: string; property_subtype: string; city: string; condition: string }
const emptyDraft: PropertyDraft = { name: '', property_type: 'residential', property_subtype: 'single_family', city: '', condition: 'good' }

async function api<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = localStorage.getItem('property_platform_token')
  const response = await fetch(`/api/v1${path}`, {
    ...options,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...options.headers },
  })
  if (!response.ok) {
    const body = await response.json().catch(() => ({}))
    throw new Error(body.error || body.errors?.join(', ') || 'Request failed')
  }
  return response.status === 204 ? (undefined as T) : response.json()
}

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
        {loading ? <div className="empty-state"><div className="spinner" /> Loading portfolio</div> : visibleProperties.length ? <div className="property-grid">{visibleProperties.map((property) => <button className={`property-card ${selected?.id === property.id ? 'selected' : ''}`} key={property.id} onClick={() => openProperty(property)}><div className="card-top">{property.cover_photo_url ? <img src={property.cover_photo_url} alt={property.name} style={{ width: '100%', height: 100, objectFit: 'cover', borderRadius: '6px 6px 0 0', display: 'block', margin: '-12px -12px 8px -12px', width: 'calc(100% + 24px)' }} /> : <span className="property-icon"><Building2 size={20} /></span>}<span className={`condition ${property.condition || 'good'}`}>{property.condition || 'active'}</span></div><div className="card-copy"><h3>{property.name}</h3><p>{property.address.city || 'Location pending'}{property.address.province ? `, ${property.address.province}` : ''}</p></div><div className="card-meta"><span>{property.property_type}</span><span>{property.cached_total_units} units <ChevronRight size={14} /></span></div></button>)}</div> : <div className="empty-state"><Building2 size={28} /><h3>No properties yet</h3><p>Create your first managed property to start building the portfolio.</p><button className="primary-button" onClick={() => setShowCreate(true)}><Plus size={17} /> Add property</button></div>}
      </section>
    </main>
    {selected && <PropertyDetailWorkspace property={selected} portfolio={portfolio} loading={portfolioLoading} error={portfolioError} onInspection={(inspectionId) => setInspectionId(selected.id, inspectionId)} onSchedule={() => setShowSchedule(true)} onPhotoUploaded={(url) => { setSelected((p) => p ? { ...p, cover_photo_url: url } : p); setProperties((ps) => ps.map((p) => p.id === selected.id ? { ...p, cover_photo_url: url } : p)) }} onClose={() => { setSelected(null); setPortfolio(null) }} />}
    {inspection && <InspectionReview inspection={inspection} onStart={() => { setInspectionForm(inspection); setInspection(null) }} onClose={() => setInspection(null)} />}
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
  return <div className="drawer-backdrop" onClick={onClose}><aside className="detail-workspace" onClick={(event) => event.stopPropagation()}><div className="detail-header"><div><p className="eyebrow">Property workspace</p><h2>{property.name}</h2><p>{property.address.city || 'Location pending'}{property.address.province ? `, ${property.address.province}` : ''}</p></div><button className="icon-button" onClick={onClose}><X size={18} /></button></div><div className="detail-tabs">{tabs.map(([value, label]) => <button className={tab === value ? 'active' : ''} key={value} onClick={() => setTab(value)}>{label}</button>)}</div>{loading ? <div className="detail-loading"><div className="spinner" /> Loading property workspace</div> : error ? <div className="detail-error"><X size={17} /><p>{error}</p></div> : portfolio && <div className="detail-content">{tab === 'overview' && <OverviewPanel property={property} portfolio={portfolio} onPhotoUploaded={onPhotoUploaded} />}{tab === 'structure' && <StructurePanel portfolio={portfolio} />}{tab === 'inventory' && <InventoryPanel portfolio={portfolio} />}{tab === 'ownership' && <OwnershipPanel portfolio={portfolio} />}{tab === 'access' && <AccessPanel portfolio={portfolio} />}{tab === 'inspections' && <InspectionsPanel portfolio={portfolio} onInspection={onInspection} onSchedule={onSchedule} />}{tab === 'leases' && <LeasesPanel portfolio={portfolio} />}{tab === 'maintenance' && <MaintenancePanel portfolio={portfolio} />}</div>}</aside></div>
}

function OverviewPanel({ property, portfolio, onPhotoUploaded }: { property: Property; portfolio: Portfolio; onPhotoUploaded: (url: string) => void }) {
  const [uploading, setUploading] = useState(false)

  async function uploadCover(file: File) {
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
      if (res.ok) {
        const data = await res.json()
        if (data.cover_photo_url) onPhotoUploaded(data.cover_photo_url)
      }
    } catch { /* non-blocking */ } finally { setUploading(false) }
  }

  return <>
    <div className="workspace-hero" style={{ position: 'relative', padding: 0, overflow: 'hidden', borderRadius: 8, marginBottom: 16 }}>
      {property.cover_photo_url
        ? <img src={property.cover_photo_url} alt={property.name} style={{ width: '100%', height: 180, objectFit: 'cover', display: 'block' }} />
        : <div style={{ width: '100%', height: 180, background: '#f0f0ec', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Building2 size={40} color="#c0bdb5" /></div>}
      <div style={{ position: 'absolute', bottom: 10, right: 10 }}>
        <label style={{ cursor: 'pointer', background: 'rgba(0,0,0,0.55)', color: '#fff', fontSize: 12, padding: '5px 10px', borderRadius: 5, display: 'flex', alignItems: 'center', gap: 5 }}>
          <input type="file" accept="image/*" style={{ display: 'none' }} disabled={uploading} onChange={(e) => { const f = e.target.files?.[0]; if (f) uploadCover(f) }} />
          {uploading ? 'Uploading…' : '📷 Change photo'}
        </label>
      </div>
      <span className={`condition ${property.condition || 'good'}`} style={{ position: 'absolute', top: 10, right: 10 }}>{property.condition || 'active'}</span>
    </div>
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
function OwnershipPanel({ portfolio }: { portfolio: Portfolio }) { return <DataPanel title="Ownership history" count={portfolio.ownership.length}>{portfolio.ownership.length ? portfolio.ownership.map((record) => <div className="data-row" key={record.id}><div><strong>{record.party.name}</strong><span>{record.party.party_type} · from {record.start_date}</span></div><b>{record.ownership_percentage}%</b></div>) : <EmptyPanel label="No ownership history recorded yet" />}</DataPanel> }
function AccessPanel({ portfolio }: { portfolio: Portfolio }) { return <DataPanel title="Property access" count={portfolio.assignments.length}>{portfolio.assignments.length ? portfolio.assignments.map((record) => <div className="data-row" key={record.id}><div><strong>{record.user.name}</strong><span>{record.user.email}</span></div><small>{record.assignment_type}</small></div>) : <EmptyPanel label="No active assignments" />}</DataPanel> }
function InspectionsPanel({ portfolio, onInspection, onSchedule }: { portfolio: Portfolio; onInspection: (inspectionId: string) => void; onSchedule: () => void }) { return <DataPanel title="Inspections" count={portfolio.inspections.length}><button className="secondary-button schedule-button" onClick={onSchedule}><CalendarPlus size={15} /> Schedule inspection</button>{portfolio.inspections.length ? portfolio.inspections.map((inspection) => <button className="inspection-row" key={inspection.id} onClick={() => onInspection(inspection.id)}><div><strong>{inspection.inspection_type.replace('_', ' ')}</strong><span>{inspection.scheduled_on || inspection.inspected_on || 'Date pending'}</span></div><small className={`status-${inspection.status}`}>{inspection.status}</small><ChevronRight size={15} /></button>) : <EmptyPanel label="No inspections scheduled" />}</DataPanel> }
function Metric({ label, value }: { label: string; value: number }) { return <div><span>{label}</span><strong>{value.toString().padStart(2, '0')}</strong></div> }
function DataPanel({ title, count, children }: { title: string; count: number; children: React.ReactNode }) { return <section className="data-panel"><div className="panel-heading"><h3>{title}</h3><span>{count.toString().padStart(2, '0')} records</span></div>{children}</section> }
function EmptyPanel({ label }: { label: string }) { return <div className="panel-empty"><span>{label}</span></div> }
function LeasesPanel({ portfolio }: { portfolio: Portfolio }) {
  const leases = portfolio.leases ?? []
  return <DataPanel title="Leases" count={leases.length}>{leases.length ? leases.map((lease) => <div className="data-row" key={lease.id}><div><strong>{lease.tenant_name || 'Tenant'}</strong><span>{lease.lease_type.replace('_', ' ')} · from {lease.start_date}{lease.end_date ? ` to ${lease.end_date}` : ' (open)'}</span></div><small className={`status-${lease.status}`}>{lease.status} · ${Number(lease.monthly_rent).toLocaleString()}/mo</small></div>) : <EmptyPanel label="No leases recorded yet" />}</DataPanel>
}
function MaintenancePanel({ portfolio }: { portfolio: Portfolio }) {
  const requests = portfolio.maintenance ?? []
  const priorityColour: Record<string, string> = { urgent: '#874f3c', high: '#a06b2e', medium: '#9a7a3c', low: '#87938a' }
  return <DataPanel title="Maintenance requests" count={requests.length}>{requests.length ? requests.map((req) => <div className="data-row" key={req.id}><div><strong>{req.title}</strong><span>{req.category || 'General'} · {new Date(req.reported_at).toLocaleDateString()}</span></div><small style={{ color: priorityColour[req.priority] ?? '#87938a' }}>{req.priority} · {req.status}</small></div>) : <EmptyPanel label="No maintenance requests yet" />}</DataPanel>
}

function ScheduleInspection({ propertyId, onClose, onCreated }: { propertyId: string; onClose: () => void; onCreated: () => void }) { const [inspectionType, setInspectionType] = useState('routine'); const [scheduledOn, setScheduledOn] = useState(''); const [notes, setNotes] = useState(''); const [error, setError] = useState(''); const [loading, setLoading] = useState(false); async function submit(event: React.FormEvent) { event.preventDefault(); setLoading(true); setError(''); try { await api(`/properties/${propertyId}/inspections`, { method: 'POST', body: JSON.stringify({ inspection: { inspection_type: inspectionType, scheduled_on: scheduledOn || undefined, notes: notes || undefined } }) }); onCreated() } catch (err) { setError((err as Error).message) } finally { setLoading(false) } } return <div className="modal-backdrop" onClick={onClose}><form className="modal" onClick={(event) => event.stopPropagation()} onSubmit={submit}><div className="modal-header"><div><p className="eyebrow">Inspection workflow</p><h2>Schedule inspection</h2></div><button type="button" className="icon-button" onClick={onClose}><X size={18} /></button></div><div className="form-grid"><label>Type<select value={inspectionType} onChange={(event) => setInspectionType(event.target.value)}><option value="routine">Routine</option><option value="move_in">Move in</option><option value="move_out">Move out</option><option value="periodic">Periodic</option></select></label><label>Date<input type="date" value={scheduledOn} onChange={(event) => setScheduledOn(event.target.value)} /></label></div><label>Notes<textarea value={notes} onChange={(event) => setNotes(event.target.value)} placeholder="Optional inspection context" rows={4} /></label>{error && <div className="form-error">{error}</div>}<div className="modal-actions"><button type="button" className="secondary-button" onClick={onClose}>Cancel</button><button className="primary-button" disabled={loading}>{loading ? 'Scheduling...' : 'Schedule inspection'} <CalendarPlus size={16} /></button></div></form></div> }

function InspectionReview({ inspection, onStart, onClose }: { inspection: InspectionDetail; onStart: () => void; onClose: () => void }) { const items = inspection.rooms.flatMap((room) => room.items); const average = items.length ? (items.reduce((total, item) => total + item.condition_score, 0) / items.length).toFixed(1) : '—'; return <div className="drawer-backdrop" onClick={onClose}><aside className="inspection-review" onClick={(event) => event.stopPropagation()}><div className="detail-header"><div><p className="eyebrow">Inspection review</p><h2>{inspection.inspection.inspection_type.replace('_', ' ')}</h2><p>{inspection.inspection.inspected_on || inspection.inspection.scheduled_on || 'Date pending'} · {inspection.inspection.status}</p></div><button className="icon-button" onClick={onClose}><X size={18} /></button></div><div className="inspection-summary"><div><span>Rooms</span><strong>{inspection.rooms.length}</strong></div><div><span>Items checked</span><strong>{items.length}</strong></div><div><span>Average score</span><strong>{average}<small>/ 5</small></strong></div></div><div className="inspection-body">{inspection.inspection.status !== 'locked' && <button className="primary-button full" onClick={onStart}>Start room inspection</button>}{inspection.rooms.length ? inspection.rooms.map((room) => <section className="review-room" key={room.id}><div className="review-room-heading"><div><p className="eyebrow">{room.room_type}</p><h3>{room.room_name}</h3></div><span>{room.items.length} items</span></div>{room.items.length ? room.items.map((item) => <div className="review-item" key={item.id}><div><strong>{item.item_name}</strong><span>{item.item_type_name}{item.damage_description ? ` · ${item.damage_description}` : ''}</span></div><b className={`score score-${item.condition_score}`}>{item.condition_score}/5</b></div>) : <EmptyPanel label="No snapshot items" />}</section>) : <EmptyPanel label="No inspection rooms recorded" />}</div></aside></div> }

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
      if (res.ok) {
        const photo = await res.json()
        if (photo.url) setPhotoUrls((prev) => ({ ...prev, [itemId]: photo.url }))
      }
    } catch { /* non-blocking */ } finally { setUploading(null) }
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
        <p className="eyebrow" style={{ marginBottom: 6 }}>Cover photo <span style={{ color: '#87938a', fontWeight: 400, textTransform: 'none', letterSpacing: 0 }}>— optional</span></p>
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
