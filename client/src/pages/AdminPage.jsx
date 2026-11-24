import { useState, useEffect, useMemo } from 'react'
import { Link } from 'react-router-dom'
import { getAdminVehicles, toggleFeatured } from '../api/client'

/*
 * Admin: manage featured vehicles.
 * The admin key is asked for once and remembered in this browser only
 * (sessionStorage is cleared when the tab closes).
 */
const KEY_STORAGE = 'auctionlab:adminKey'

function loadKey() {
  try { return sessionStorage.getItem(KEY_STORAGE) || '' } catch { return '' }
}
function saveKey(key) {
  try {
    if (key) sessionStorage.setItem(KEY_STORAGE, key)
    else sessionStorage.removeItem(KEY_STORAGE)
  } catch { /* storage blocked — key lives in memory only */ }
}

/* ── Sign-in form ── */
function AdminKeyForm({ onSubmit, error }) {
  const [value, setValue] = useState('')
  return (
    <section className="admin-page">
      <form
        className="admin-login"
        onSubmit={e => { e.preventDefault(); if (value.trim()) onSubmit(value.trim()) }}
      >
        <h2 className="section-title">Admin <span className="accent">Access</span></h2>
        <p className="admin-login-hint">Enter the admin key (ADMIN_API_KEY in api/.env).</p>
        <input
          type="password"
          className="admin-input"
          placeholder="Admin key"
          value={value}
          onChange={e => setValue(e.target.value)}
          autoFocus
          autoComplete="off"
        />
        {error && <p className="admin-error">⚠ {error}</p>}
        <button type="submit" className="btn-primary admin-login-btn">Unlock →</button>
      </form>
    </section>
  )
}

/* ── Toggle switch ── */
function FeaturedSwitch({ checked, busy, onChange, label }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      className={`admin-switch${checked ? ' admin-switch--on' : ''}${busy ? ' admin-switch--busy' : ''}`}
      onClick={onChange}
      disabled={busy}
    >
      <span className="admin-switch-thumb" />
    </button>
  )
}

/* ── Main page ── */
export default function AdminPage() {
  const [adminKey, setAdminKey] = useState(loadKey)
  const [authError, setAuthError] = useState(null)

  const [vehicles, setVehicles] = useState([])
  const [loading, setLoading]   = useState(false)
  const [error, setError]       = useState(null)
  const [busyIds, setBusyIds]   = useState(() => new Set())

  const [search, setSearch]           = useState('')
  const [featuredOnly, setFeaturedOnly] = useState(false)

  /* load vehicles whenever we have a key */
  useEffect(() => {
    if (!adminKey) return
    let cancelled = false
    setLoading(true)
    setError(null)
    getAdminVehicles(adminKey)
      .then(res => { if (!cancelled) setVehicles(res.data ?? []) })
      .catch(err => {
        if (cancelled) return
        if (err.status === 401 || err.status === 503) {
          signOut(err.status === 401 ? 'That admin key was not accepted.' : err.message)
        } else {
          setError(err.message)
        }
      })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [adminKey])

  function signIn(key) {
    saveKey(key)
    setAuthError(null)
    setAdminKey(key)
  }

  function signOut(message = null) {
    saveKey('')
    setAdminKey('')
    setVehicles([])
    setAuthError(message)
  }

  async function handleToggle(v) {
    const id = v.VehicleId
    setBusyIds(prev => new Set(prev).add(id))
    // optimistic update
    setVehicles(list => list.map(x => x.VehicleId === id ? { ...x, IsFeatured: !x.IsFeatured } : x))
    try {
      const res = await toggleFeatured(id, adminKey)
      setVehicles(list => list.map(x => x.VehicleId === id ? { ...x, IsFeatured: res.IsFeatured } : x))
    } catch (err) {
      // roll back
      setVehicles(list => list.map(x => x.VehicleId === id ? { ...x, IsFeatured: v.IsFeatured } : x))
      if (err.status === 401) signOut('Your admin key is no longer valid.')
      else setError(`Couldn't update vehicle #${id}: ${err.message}`)
    } finally {
      setBusyIds(prev => { const next = new Set(prev); next.delete(id); return next })
    }
  }

  const featuredCount = vehicles.filter(v => v.IsFeatured).length

  const visible = useMemo(() => {
    const q = search.trim().toLowerCase()
    return vehicles.filter(v => {
      if (featuredOnly && !v.IsFeatured) return false
      if (!q) return true
      return [v.VehicleId, v.ModelYear, v.Make, v.Model, v.Vin, v.BodyClass, v.Color]
        .some(f => f != null && String(f).toLowerCase().includes(q))
    })
  }, [vehicles, search, featuredOnly])

  if (!adminKey) return <AdminKeyForm onSubmit={signIn} error={authError} />

  return (
    <section className="admin-page">
      <div className="section-header">
        <h2 className="section-title">
          Featured <span className="accent">Vehicles</span>
        </h2>
        <div className="admin-header-actions">
          <span className="results-count">
            {featuredCount} featured · {vehicles.length} total
          </span>
          <button className="btn-clear" onClick={() => signOut()}>Sign out</button>
        </div>
      </div>

      <div className="filter-extra">
        <label htmlFor="admin-search">Search</label>
        <input
          id="admin-search"
          type="search"
          placeholder="Make, model, VIN, year…"
          value={search}
          onChange={e => setSearch(e.target.value)}
          style={{ width: 240 }}
        />
        <button
          className={`filter-chip${featuredOnly ? ' active' : ''}`}
          onClick={() => setFeaturedOnly(f => !f)}
          aria-pressed={featuredOnly}
        >
          ★ Featured only
        </button>
      </div>

      {error && (
        <div className="admin-error-bar">
          <span>⚠ {error}</span>
          <button className="admin-error-close" onClick={() => setError(null)} aria-label="Dismiss">×</button>
        </div>
      )}

      {loading ? (
        <div className="state-loading">
          <div className="spinner" />
          <span>Loading vehicles…</span>
        </div>
      ) : (
        <div className="admin-table-wrap">
          <table className="admin-table">
            <thead>
              <tr>
                <th className="col-id">ID</th>
                <th>Year</th>
                <th>Vehicle</th>
                <th className="col-hide-sm">Body</th>
                <th className="col-hide-sm">Color</th>
                <th className="col-hide-md">VIN</th>
                <th className="col-featured">Featured</th>
              </tr>
            </thead>
            <tbody>
              {visible.map(v => {
                const title = [v.Make, v.Model].filter(Boolean).join(' ') || 'Unknown'
                return (
                  <tr key={v.VehicleId} className={v.IsFeatured ? 'is-featured' : ''}>
                    <td className="col-id">{v.VehicleId}</td>
                    <td>{v.ModelYear ?? '—'}</td>
                    <td>
                      <Link to={`/vehicle/${v.VehicleId}`} className="admin-vehicle-link">
                        {title}
                      </Link>
                    </td>
                    <td className="col-hide-sm admin-muted">{v.BodyClass ?? '—'}</td>
                    <td className="col-hide-sm admin-muted">{v.Color ?? '—'}</td>
                    <td className="col-hide-md admin-vin">{v.Vin ?? '—'}</td>
                    <td className="col-featured">
                      <FeaturedSwitch
                        checked={!!v.IsFeatured}
                        busy={busyIds.has(v.VehicleId)}
                        onChange={() => handleToggle(v)}
                        label={`Feature ${v.ModelYear ?? ''} ${title}`}
                      />
                    </td>
                  </tr>
                )
              })}
              {visible.length === 0 && (
                <tr>
                  <td colSpan={7} className="admin-empty">No vehicles match.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </section>
  )
}
