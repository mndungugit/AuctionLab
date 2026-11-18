import { useState, useEffect, useCallback } from 'react'
import VehicleCard from '../components/VehicleCard.jsx'
import { getFilters, getVehicles } from '../api/client.js'

const PAGE_SIZE = 24

export default function BrowsePage() {
  const [filters, setFilters]     = useState(null)
  const [make, setMake]           = useState('')
  const [yearMin, setYearMin]     = useState('')
  const [yearMax, setYearMax]     = useState('')
  const [bodyClass, setBodyClass] = useState('')
  const [vehicles, setVehicles]   = useState([])
  const [total, setTotal]         = useState(0)
  const [page, setPage]           = useState(1)
  const [loading, setLoading]     = useState(true)
  const [error, setError]         = useState(null)

  useEffect(() => { getFilters().then(setFilters).catch(() => {}) }, [])

  const fetchVehicles = useCallback(() => {
    setLoading(true); setError(null)
    getVehicles({ make, yearMin, yearMax, bodyClass, page, pageSize: PAGE_SIZE })
      .then(data => { setVehicles(data.data || data.vehicles || []); setTotal(data.totalCount || data.total || 0) })
      .catch(err => setError(err.message))
      .finally(() => setLoading(false))
  }, [make, yearMin, yearMax, bodyClass, page])

  useEffect(() => { fetchVehicles() }, [fetchVehicles])

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE))

  function applyFilter(setter) {
    return (e) => { setter(e.target.value); setPage(1) }
  }

  function clearFilters() { setMake(''); setYearMin(''); setYearMax(''); setBodyClass(''); setPage(1) }

  const hasFilters = make || yearMin || yearMax || bodyClass

  function pageButtons() {
    const buttons = []
    for (let p = 1; p <= totalPages; p++) {
      if (p === 1 || p === totalPages || Math.abs(p - page) <= 2) buttons.push(p)
      else if (buttons[buttons.length - 1] !== '') buttons.push('')
    }
    return buttons
  }

  return (
    <div className="browse-layout">
      <aside className="filter-sidebar">
        <h2>Filter</h2>
        <div className="filter-group">
          <label htmlFor="filter-make">Make</label>
          <select id="filter-make" value={make} onChange={applyFilter(setMake)}>
            <option value="">All Makes</option>
            {filters?.makes?.map(m => (
              <option key={m.Make} value={m.Make}>{m.Make} ({m.VehicleCount})</option>
            ))}
          </select>
        </div>
        <div className="filter-group">
          <label>Year Range</label>
          <div className="year-range-row">
            <input type="number" placeholder={filters?.yearRange?.MinYear ?? 'Min'} value={yearMin}
              onChange={applyFilter(setYearMin)} min={filters?.yearRange?.MinYear} max={filters?.yearRange?.MaxYear} />
            <span></span>
            <input type="number" placeholder={filters?.yearRange?.MaxYear ?? 'Max'} value={yearMax}
              onChange={applyFilter(setYearMax)} min={filters?.yearRange?.MinYear} max={filters?.yearRange?.MaxYear} />
          </div>
        </div>
        <div className="filter-group">
          <label htmlFor="filter-body">Body Class</label>
          <select id="filter-body" value={bodyClass} onChange={applyFilter(setBodyClass)}>
            <option value="">All Types</option>
            {filters?.bodyClasses?.map(b => (
              <option key={b.BodyClass} value={b.BodyClass}>{b.BodyClass} ({b.VehicleCount})</option>
            ))}
          </select>
        </div>
        {hasFilters && <button className="btn-clear-filters" onClick={clearFilters}>Clear filters</button>}
      </aside>

      <section className="results-panel">
        <div className="results-header">
          <p className="results-count">
            {loading ? 'Loading' : <><strong>{total.toLocaleString()}</strong> vehicle{total !== 1 ? 's' : ''}</>}
          </p>
        </div>
        {loading && <div className="state-loading"><div className="spinner" /><p>Loading vehicles</p></div>}
        {!loading && error && <div className="state-error"><p> {error}</p></div>}
        {!loading && !error && vehicles.length === 0 && <div className="state-empty"><p>No vehicles match your filters.</p></div>}
        {!loading && !error && vehicles.length > 0 && (
          <>
            <div className="vehicle-grid">
              {vehicles.map(v => <VehicleCard key={v.VehicleId} vehicle={v} />)}
            </div>
            {totalPages > 1 && (
              <nav className="pagination" aria-label="Pages">
                <button className="btn-page" onClick={() => setPage(p => p - 1)} disabled={page === 1}>&larr; Prev</button>
                {pageButtons().map((p, i) =>
                  p === ''
                    ? <span key={`e${i}`} className="page-info"></span>
                    : <button key={p} className={`btn-page${page === p ? ' active' : ''}`} onClick={() => setPage(p)}>{p}</button>
                )}
                <button className="btn-page" onClick={() => setPage(p => p + 1)} disabled={page === totalPages}>Next &rarr;</button>
              </nav>
            )}
          </>
        )}
      </section>
    </div>
  )
}
