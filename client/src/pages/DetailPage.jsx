import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { getVehicle } from '../api/client.js'
import { fetchCarImage } from '../api/carImage.js'

function Field({ label, value }) {
  if (!value && value !== 0) return null
  return (
    <div className="detail-field">
      <label>{label}</label>
      <p>{value}</p>
    </div>
  )
}

export default function DetailPage() {
  const { id }      = useParams()
  const navigate    = useNavigate()
  const [vehicle, setVehicle]   = useState(null)
  const [loading, setLoading]   = useState(true)
  const [error, setError]       = useState(null)
  const [imgSrc, setImgSrc]     = useState(null)
  const [imgLoaded, setImgLoaded] = useState(false)

  useEffect(() => {
    setLoading(true)
    setError(null)
    getVehicle(id)
      .then(v => {
        setVehicle(v)
        // Kick off image fetch once we have the vehicle data
        fetchCarImage(v.Make, v.Model, v.ModelYear, v.Vin).then(setImgSrc)
      })
      .catch(err => setError(err.message))
      .finally(() => setLoading(false))
  }, [id])

  if (loading) {
    return (
      <div className="state-loading">
        <div className="spinner" />
        <p>Loading vehicle…</p>
      </div>
    )
  }

  if (error) {
    return (
      <div className="state-error">
        <p>⚠️ {error}</p>
        <br />
        <button className="btn-back" onClick={() => navigate(-1)}>← Back</button>
      </div>
    )
  }

  if (!vehicle) return null

  const title = [vehicle.Make, vehicle.Model].filter(Boolean).join(' ') || 'Unknown Vehicle'

  const saleDate = vehicle.SaleDate
    ? new Date(vehicle.SaleDate).toLocaleDateString('en-US', {
        weekday: 'long', month: 'long', day: 'numeric', year: 'numeric'
      })
    : null

  const vin = vehicle.Vin || vehicle.VinAutoCorrected

  const carfaxUrl = vin
    ? `https://www.carfax.com/VehicleHistory/p/Report_.cfx?partner=DEA_0&vin=${vin}`
    : null
  const nhtsaUrl = vin
    ? `https://vpic.nhtsa.dot.gov/decoder/Decoder?VIN=${vin}`
    : null

  return (
    <div className="detail-page">
      <button className="btn-back" onClick={() => navigate(-1)}>
        ← Back to results
      </button>

      <div className="detail-card">
        {/* ---- Hero image ---- */}
        <div className="detail-image-wrap">
          {imgSrc ? (
            <>
              {!imgLoaded && <span className="detail-image-placeholder">🚗</span>}
              <img
                src={imgSrc}
                alt={`${vehicle.ModelYear || ''} ${title}`}
                onLoad={() => setImgLoaded(true)}
                style={{ display: imgLoaded ? 'block' : 'none' }}
              />
            </>
          ) : (
            <span className="detail-image-placeholder">🚗</span>
          )}
        </div>

        {/* ---- Header banner ---- */}
        <div className="detail-header">
          <div>
            <h1 className="detail-title">{title}</h1>
            {vehicle.ModelYear && (
              <p className="detail-year-label">Model year {vehicle.ModelYear}</p>
            )}
          </div>
          <span
            className={`badge ${vehicle.IsVerified ? 'badge-verified' : 'badge-unverified'}`}
            style={{ fontSize: '13px', padding: '4px 12px' }}
          >
            {vehicle.IsVerified ? '✓ NHTSA Verified' : 'Unverified'}
          </span>
        </div>

        <div className="detail-body">
          {/* ---- Vehicle info ---- */}
          <div className="detail-section">
            <h2 className="detail-section-title">Vehicle Details</h2>
            <div className="detail-grid">
              <Field label="Year"       value={vehicle.ModelYear} />
              <Field label="Make"       value={vehicle.Make} />
              <Field label="Model"      value={vehicle.Model} />
              <Field label="Body Class" value={vehicle.BodyClass} />
              <Field label="Color"      value={vehicle.Color} />
              {saleDate && <Field label="Sale Date" value={saleDate} />}
            </div>
          </div>

          {/* ---- VIN ---- */}
          {vin && (
            <div className="detail-section">
              <h2 className="detail-section-title">VIN</h2>
              <div className="vin-display">{vin}</div>

              <div className="external-links">
                {carfaxUrl && (
                  <a
                    href={carfaxUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="btn-external btn-carfax"
                  >
                    🔎 CARFAX Report
                  </a>
                )}
                {nhtsaUrl && (
                  <a
                    href={nhtsaUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="btn-external btn-nhtsa"
                  >
                    🏛️ NHTSA Decoder
                  </a>
                )}
              </div>
            </div>
          )}

          {/* ---- Additional NHTSA fields (if present) ---- */}
          {(vehicle.EngineModel || vehicle.FuelTypePrimary ||
            vehicle.DriveType || vehicle.TransmissionStyle ||
            vehicle.Doors || vehicle.PlantCountry) && (
            <div className="detail-section">
              <h2 className="detail-section-title">NHTSA Data</h2>
              <div className="detail-grid">
                <Field label="Engine"       value={vehicle.EngineModel} />
                <Field label="Fuel Type"    value={vehicle.FuelTypePrimary} />
                <Field label="Drive Type"   value={vehicle.DriveType} />
                <Field label="Transmission" value={vehicle.TransmissionStyle} />
                <Field label="Doors"        value={vehicle.Doors} />
                <Field label="Plant"        value={vehicle.PlantCountry} />
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
