import { useState, useEffect } from 'react'
import { fetchCarImage } from '../api/carImage'
import FavoriteButton from './FavoriteButton'

export default function VehicleCard({ vehicle: v, onClick }) {
  const [imgSrc, setImgSrc] = useState(null)
  const [imgErr, setImgErr] = useState(false)

  useEffect(() => {
    let cancelled = false
    fetchCarImage(v.Make, v.Model, v.ModelYear, v.Vin)
      .then(url => { if (!cancelled) setImgSrc(url) })
      .catch(() => { if (!cancelled) setImgErr(true) })
    return () => { cancelled = true }
  }, [v.Make, v.Model, v.ModelYear, v.Vin])

  const title = [v.Make, v.Model].filter(Boolean).join(' ') || 'Unknown Vehicle'

  return (
    <div
      className="vehicle-card"
      onClick={onClick}
      onKeyDown={e => e.key === 'Enter' && onClick?.()}
      tabIndex={0}
      role="button"
      aria-label={`View details for ${v.ModelYear ?? ''} ${title}`}
    >
      {/* save / favorite */}
      <FavoriteButton vehicle={v} className="card-fav" />

      {/* image */}
      <div className="card-image-wrap">
        {imgSrc && !imgErr ? (
          <img
            src={imgSrc}
            alt={`${v.ModelYear ?? ''} ${title}`}
            onError={() => setImgErr(true)}
            loading="lazy"
          />
        ) : (
          <span className="card-image-placeholder">🚗</span>
        )}
      </div>

      {/* year + badge */}
      <div className="card-header">
        <span className="card-year">{v.ModelYear ?? '—'}</span>
        {v.Vin ? (
          <span className="badge badge-verified">VIN ✓</span>
        ) : (
          <span className="badge badge-unverified">No VIN</span>
        )}
      </div>

      {/* make / model */}
      <h3 className="card-title">{title}</h3>

      {/* meta row */}
      <div className="card-meta">
        {v.BodyClass && <span>{v.BodyClass}</span>}
        {v.Color     && <span>{v.Color}</span>}
        {v.Cylinders && <span>{v.Cylinders} cyl</span>}
      </div>

      {/* VIN */}
      <div className="card-vin">
        VIN: {v.Vin ? v.Vin.toUpperCase() : 'N/A'}
      </div>

      {/* CTA */}
      <div className="card-footer">
        <button className="btn-view" tabIndex={-1}>
          View Details →
        </button>
      </div>
    </div>
  )
}
