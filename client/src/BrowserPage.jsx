import { useState, useEffect } from 'react'
import { useNavigate }         from 'react-router-dom'
import { getVehicles, getFilters } from '../api/vehicles'
import VehicleCard from '../components/VehicleCard'

const PAGE_SIZE = 12

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
  const [total,       setTotal]       = useState(0)
  const [page,        setPage]        = useState(1)
  const [loading,     setLoading]     = useState(true)
  const [error,       setError]       = useState(null)

  /* ── load filter options once ── */
  useEffect(() => {
    getFilters()
      .then(f => setFilters(f))
      .catch(err => console.error('filters:', err))
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
        setVehicles(data.vehicles ?? data)
        setTotal(data.total ?? (data.vehicles ?? data).length)
        setLoading(false)
      })
      .catch(err => {
        setError(err.message)
        setLoading(false)
      })
  }, [selectedMake, yearMin, yearMax, bodyClass, page])

  /* ── derived ── */
  const totalPages  = Math.max(1, Math.ceil(total / PAGE_SIZE))
  const makes       = filters?.makes  ?? []
  const bodyClasses = filters?.bodyClasses ?? []
  const minYear     = filters?.yearRange?.MinYear  ?? '—'
  const maxYear     = filters?.yearRange?.MaxYear  ?? '—'

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
        <div className="hero-content">
          <div className="hero-eyebrow">
            <span className="line" />
            <span>KO Towing · Marietta, GA · Live Auction</span>
          </div>
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
            <button className="btn-outline">How It Works</button>
          </div>
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
            <div className="stat-num">{minYear}–{maxYear}</div>
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
        {/* section heading */}
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
            style={{ width: 80 }}
            onChange={e => { setYearMin(e.target.value); setPage(1) }}
          />
          <input
            type="number"
            placeholder="To"
            value={yearMax}
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
                key={v.Id ?? v.VehicleId ?? v.Vin}
                vehicle={v}
                onClick={() => navigate(`/vehicle/${v.Id ?? v.VehicleId}`)}
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
