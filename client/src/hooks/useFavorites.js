import { useSyncExternalStore, useCallback } from 'react'

/*
 * Saved / favorite vehicles, persisted in localStorage.
 *
 * Each favorite stores a small snapshot of the vehicle so the Saved page
 * can render without calling the API. All components using this hook stay
 * in sync, and changes made in another browser tab are picked up too.
 */

const STORAGE_KEY = 'auctionlab:favorites'
const EMPTY = []

export function getVehicleId(v) {
  return v?.Id ?? v?.VehicleId ?? v?.id ?? null
}

function snapshot(v, fallbackId) {
  return {
    id:        String(getVehicleId(v) ?? fallbackId),
    Make:      v.Make ?? null,
    Model:     v.Model ?? null,
    ModelYear: v.ModelYear ?? null,
    Vin:       v.Vin ?? v.VinAutoCorrected ?? null,
    BodyClass: v.BodyClass ?? null,
    Color:     v.Color ?? null,
    Cylinders: v.Cylinders ?? null,
    savedAt:   new Date().toISOString(),
  }
}

/* ── tiny external store ── */
let cache = null
const listeners = new Set()

function read() {
  if (cache) return cache
  try {
    const parsed = JSON.parse(localStorage.getItem(STORAGE_KEY))
    cache = Array.isArray(parsed) ? parsed : EMPTY
  } catch {
    cache = EMPTY
  }
  return cache
}

function write(next) {
  cache = next
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(next))
  } catch {
    // Storage full or blocked (private mode) — keep in memory for this session
  }
  listeners.forEach(l => l())
}

function subscribe(listener) {
  listeners.add(listener)
  const onStorage = e => {
    if (e.key === STORAGE_KEY) { cache = null; listener() }
  }
  window.addEventListener('storage', onStorage)
  return () => {
    listeners.delete(listener)
    window.removeEventListener('storage', onStorage)
  }
}

/* ── hook ── */
export default function useFavorites() {
  const favorites = useSyncExternalStore(subscribe, read, () => EMPTY)

  const isFavorite = useCallback(
    id => id != null && favorites.some(f => f.id === String(id)),
    [favorites]
  )

  const toggleFavorite = useCallback((vehicle, fallbackId) => {
    const id = String(getVehicleId(vehicle) ?? fallbackId)
    const current = read()
    if (current.some(f => f.id === id)) {
      write(current.filter(f => f.id !== id))
    } else {
      write([snapshot(vehicle, id), ...current])
    }
  }, [])

  const removeFavorite = useCallback(id => {
    write(read().filter(f => f.id !== String(id)))
  }, [])

  const clearFavorites = useCallback(() => write(EMPTY), [])

  return { favorites, isFavorite, toggleFavorite, removeFavorite, clearFavorites }
}
