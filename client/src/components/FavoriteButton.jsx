import useFavorites, { getVehicleId } from '../hooks/useFavorites'

/*
 * Heart toggle for saving a vehicle.
 *  variant="icon" — small round button (vehicle cards)
 *  variant="full" — labelled button (detail page)
 */
export default function FavoriteButton({ vehicle, fallbackId, variant = 'icon', className = '' }) {
  const { isFavorite, toggleFavorite } = useFavorites()
  const id = getVehicleId(vehicle) ?? fallbackId
  const saved = isFavorite(id)

  const handleClick = e => {
    e.stopPropagation()   // don't trigger the card's navigation
    toggleFavorite(vehicle, fallbackId)
  }

  return (
    <button
      type="button"
      className={`fav-btn fav-btn--${variant}${saved ? ' fav-btn--saved' : ''} ${className}`.trim()}
      onClick={handleClick}
      onKeyDown={e => e.stopPropagation()}
      aria-pressed={saved}
      aria-label={saved ? 'Remove from saved vehicles' : 'Save vehicle'}
      title={saved ? 'Remove from saved' : 'Save vehicle'}
    >
      <span className="fav-btn-icon" aria-hidden="true">{saved ? '♥' : '♡'}</span>
      {variant === 'full' && <span>{saved ? 'Saved' : 'Save'}</span>}
    </button>
  )
}
