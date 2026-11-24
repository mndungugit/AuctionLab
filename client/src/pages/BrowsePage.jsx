import { useState, useEffect } from 'react'
import { useNavigate }         from 'react-router-dom'
import { getVehicles, getFilters } from '../api/client'
import { fetchCarImage } from '../api/carImage'
import VehicleCard from '../components/VehicleCard'


const PAGE_SIZE = 12

/* ── Manager's Special card (hero right panel) ── */
function ManagersSpecial({ vehicle, onView }) {
  const [imgSrc, setImgSrc] = useState(null)
  const [imgErr, setImgErr] = useState(false)

  useEffect(() => {
    if (!vehicle) return
    let cancelled = false
    fetchCarImage(vehicle.Make, vehicle.Model, vehicle.ModelYear, vehicle.Vin)
      .then(url  => { if (!cancelled) setImgSrc(url) })
      .catch(()  => { if (!cancelled) setImgErr(true) })
    return () => { cancelled = true }
  }, [vehicle?.Vin])

  if (!vehicle) return null

  const title = [vehicle.Make, vehicle.Model].filter(Boolean).join(' ') || 'Vehicle'

  return (
    <div className="managers-special">
      {/* red top bar */}
      <div className="ms-header">
        <span className="ms-star">★</span>
        <div>
          <div className="ms-eyebrow">This Month's</div>
          <div className="ms-title">Manager's Special</div>
        </div>
      </div>

      {/* vehicle image */}
      <div className="ms-image">
        {imgSrc && !imgErr ? (
          <img
            src={imgSrc}
            alt={`${vehicle.ModelYear ?? ''} ${title}`}
            onError={() => setImgErr(true)}
          />
        ) : (
          <span className="ms-image-placeholder">🚗</span>
        )}
      </div>

      {/* info */}
      <div className="ms-info">
        <div className="ms-year">{vehicle.ModelYear ?? '—'}</div>
        <div className="ms-name">{title}</div>
        {vehicle.BodyClass && <div className="ms-body">{vehicle.BodyClass}</div>}
        <div className="ms-vin">VIN: {vehicle.Vin ? vehicle.Vin.toUpperCase() : 'N/A'}</div>
      </div>

      <button className="ms-cta" onClick={onView}>
        View This Vehicle →
      </button>
    </div>
  )
}

/* ── Main page ── */
export default function BrowsePage() {
  const navigate = useNavigate()

  /* ── filter state ── */
  const [selectedMake, setSelectedMake] = useState('')
  const [yearMin,      setYearMin]      = useState('')
  const [yearMax,      setYearMax]      = useState('')
  const [bodyClass,    setBodyClass]    = useState('')

  /* ── data state ── */
  const [vehicles,    setVehicles]    = useState([])
  const [filters,     setFilters]     = useState(null)
  const [featured,    setFeatured]    = useState(null)
  const [total,       setTotal]       = useState(0)
  const [page,        setPage]        = useState(1)
  const [loading,     setLoading]     = useState(true)
  const [error,       setError]       = useState(null)

 useEffect(() => {
  // Fetch all vehicles and sort by ModelYear descending to find the true newest
  getVehicles({ page: 1, pageSize: 200 })
    .then(data => {
      const list = data.data ?? data.vehicles ?? data.Vehicles ?? (Array.isArray(data) ? data : [])
      if (list.length > 0) {
        const sorted = [...list].sort((a, b) => {
          return (Number(b.ModelYear) || 0) - (Number(a.ModelYear) || 0)
        })
        setFeatured(sorted[0])
      }
    })
    .catch(() => {})
}, [])

  /* ── load filter options once ── */
  useEffect(() => {
    getFilters()
      .then(f => {
        const rawMakes = f.makes ?? f.Makes ?? []
        const makeNames = rawMakes
          .map(m => (typeof m === 'string' ? m : m.Make))
          .filter(s => s && typeof s === 'string' && s.trim() !== '')

        const earlyYears = rawMakes.map(m => Number(m.EarliestYear)).filter(y => y > 1900)
        const lateYears  = rawMakes.map(m => Number(m.LatestYear)).filter(y => y > 1900)

        const minYear = f.yearRange?.MinYear ?? f.yearRange?.minYear
          ?? (earlyYears.length ? Math.min(...earlyYears) : null)
        const maxYear = f.yearRange?.MaxYear ?? f.yearRange?.maxYear
          ?? (lateYears.length  ? Math.max(...lateYears)  : null)

        const rawBody = f.bodyClasses ?? f.BodyClasses ?? []
        const bodyNames = rawBody
          .map(b => (typeof b === 'string' ? b : b.BodyClass ?? b.bodyClass ?? ''))
          .filter(s => s.trim() !== '')

        setFilters({
          makes:       makeNames,
          bodyClasses: bodyNames,
          yearRange:   { MinYear: minYear, MaxYear: maxYear }
        })
      })
      .catch(err => console.error('[AuctionLab] filters error:', err))
  }, [])

  /* ── load vehicles whenever filters / page change ── */
  useEffect(() => {
    setLoading(true)
    setError(null)

    const params = { page, pageSize: PAGE_SIZE }
    if (selectedMake) params.make      = selectedMake
    if (yearMin)      params.yearMin   = yearMin
    if (yearMax)      params.yearMax   = yearMax
    if (bodyClass)    params.bodyClass = bodyClass

    getVehicles(params)
      .then(data => {
        const list  = data.data ?? data.vehicles ?? data.Vehicles ?? (Array.isArray(data) ? data : [])
        const count = data.totalCount ?? data.total ?? data.Total ?? list.length
        setVehicles(list)
        setTotal(count)
        setLoading(false)
      })
      .catch(err => {
        setError(err.message)
        setLoading(false)
      })
  }, [selectedMake, yearMin, yearMax, bodyClass, page])

  /* ── derived ── */
  const totalPages  = Math.max(1, Math.ceil(total / PAGE_SIZE))
  const makes       = filters?.makes      ?? []
  const bodyClasses = filters?.bodyClasses ?? []
  const minYear     = filters?.yearRange?.MinYear
  const maxYear     = filters?.yearRange?.MaxYear
  const yearDisplay = (minYear && maxYear) ? `${minYear}–${maxYear}` : '—'

  function clearFilters() {
    setSelectedMake('')
    setYearMin('')
    setYearMax('')
    setBodyClass('')
    setPage(1)
  }

  function handleMakeChip(make) {
    setSelectedMake(prev => prev === make ? '' : make)
    setPage(1)
  }

  /* ── render ── */
  return (
    <>
      {/* ── HERO ── */}
      <section className="hero">
        <div className="hero-bg" />

        {/* LEFT — headline + CTA */}
        <div className="hero-content">
          <h1>
            Bid.<br />
            Win.<br />
            <span className="red">Drive.</span>
          </h1>
          <p className="hero-sub">
            Browse towed &amp; recovered vehicles available through Georgia's
            official Title 40‑11‑2 public auction process.
          </p>
          <div className="hero-actions">
            <button
              className="btn-primary"
              onClick={() => document.getElementById('browse-anchor')?.scrollIntoView({ behavior: 'smooth' })}
            >
              Browse Vehicles →
            </button>
            <button className="btn-outline" onClick={() => navigate('/how-it-works')}>How It Works</button>
          </div>
        </div>

        {/* RIGHT — Manager's Special */}
        <div className="hero-visual">
          <ManagersSpecial
            vehicle={featured}
            onView={() => {
              const id = featured?.Id ?? featured?.VehicleId ?? featured?.id
              if (id) navigate(`/vehicle/${id}`)
            }}
          />
        </div>
      </section>

      {/* ── STATS BAR ── */}
      <div className="stats-bar">
        <div className="stat-item">
          <div>
            <div className="stat-num">{total || '—'}</div>
            <div className="stat-label">Vehicles<br />Available</div>
          </div>
        </div>
        <div className="stat-divider" />
        <div className="stat-item">
          <div>
            <div className="stat-num">{yearDisplay}</div>
            <div className="stat-label">Model Year<br />Range</div>
          </div>
        </div>
        <div className="stat-divider" />
        <div className="stat-item">
          <div>
            <div className="stat-num">{makes.length || '—'}</div>
            <div className="stat-label">Makes<br />Listed</div>
          </div>
        </div>
        <div className="stat-divider" />
        <div className="stat-item">
          <div>
            <div className="stat-num">GA</div>
            <div className="stat-label">40‑11‑2<br />Certified</div>
          </div>
        </div>
      </div>






      {/* ── BROWSE ── */}
      <section className="browse-section" id="browse-anchor">
        <div className="section-header">
          <h2 className="section-title">
            Available <span className="accent">Vehicles</span>
          </h2>
          <span className="results-count">
            {loading ? 'Loading…' : `${total} vehicles`}
          </span>
        </div>

        {/* make chips */}
        <div className="filter-row">
          <button
            className={`filter-chip${selectedMake === '' ? ' active' : ''}`}
            onClick={() => handleMakeChip('')}
          >
            All Makes
          </button>
          {makes.map(m => (
            <button
              key={m}
              className={`filter-chip${selectedMake === m ? ' active' : ''}`}
              onClick={() => handleMakeChip(m)}
            >
              {m}
            </button>
          ))}
        </div>

        {/* year + body row */}
        <div className="filter-extra">
          <label>Year</label>
          <input
            type="number"
            placeholder="From"
            value={yearMin}
            min="1980"
            max="2030"
            style={{ width: 80 }}
            onChange={e => { setYearMin(e.target.value); setPage(1) }}
          />
          <input
            type="number"
            placeholder="To"
            value={yearMax}
            min="1980"
            max="2030"
            style={{ width: 80 }}
            onChange={e => { setYearMax(e.target.value); setPage(1) }}
          />

          <label>Body</label>
          <select
            value={bodyClass}
            onChange={e => { setBodyClass(e.target.value); setPage(1) }}
          >
            <option value="">All</option>
            {bodyClasses.map(b => (
              <option key={b} value={b}>{b}</option>
            ))}
          </select>

          {(selectedMake || yearMin || yearMax || bodyClass) && (
            <button className="btn-clear" onClick={clearFilters}>
              Clear
            </button>
          )}
        </div>

        {/* vehicle grid */}
        {loading && (
          <div className="state-loading">
            <div className="spinner" />
            <span>Loading vehicles…</span>
          </div>
        )}

        {!loading && error && (
          <div className="state-error">
            <span>⚠ {error}</span>
          </div>
        )}

        {!loading && !error && vehicles.length === 0 && (
          <div className="state-empty">
            <span>No vehicles match your filters.</span>
            <button className="btn-clear" onClick={clearFilters}>Reset Filters</button>
          </div>
        )}

        {!loading && !error && vehicles.length > 0 && (
          <div className="vehicle-grid">
            {vehicles.map(v => (
              <VehicleCard
                key={v.Id ?? v.VehicleId ?? v.id ?? v.Vin}
                vehicle={v}
                onClick={() => navigate(`/vehicle/${v.Id ?? v.VehicleId ?? v.id}`)}
              />
            ))}
          </div>
        )}

        {/* pagination */}
        {!loading && totalPages > 1 && (
          <div className="pagination">
            <button
              className="btn-page"
              disabled={page === 1}
              onClick={() => setPage(p => p - 1)}
            >
              ← Prev
            </button>

            {Array.from({ length: Math.min(totalPages, 7) }, (_, i) => {
              let p
              if (totalPages <= 7) {
                p = i + 1
              } else if (page <= 4) {
                p = i + 1
              } else if (page >= totalPages - 3) {
                p = totalPages - 6 + i
              } else {
                p = page - 3 + i
              }
              return (
                <button
                  key={p}
                  className={`btn-page${p === page ? ' active' : ''}`}
                  onClick={() => setPage(p)}
                >
                  {p}
                </button>
              )
            })}

            <button
              className="btn-page"
              disabled={page === totalPages}
              onClick={() => setPage(p => p + 1)}
            >
              Next →
            </button>
          </div>
        )}
      </section>
    </>
  )
}
