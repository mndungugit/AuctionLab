const BASE = import.meta.env.VITE_API_URL || 'http://localhost:3001'

async function request(path) {
  const res = await fetch(`${BASE}${path}`)
  if (!res.ok) {
    const body = await res.json().catch(() => ({}))
    throw new Error(body.error || `HTTP ${res.status}`)
  }
  return res.json()
}

export async function getFilters() {
  return request('/api/filters')
}

export async function getVehicles(params = {}) {
  const qs = new URLSearchParams()
  if (params.make)      qs.set('make', params.make)
  if (params.yearMin)   qs.set('yearMin', params.yearMin)
  if (params.yearMax)   qs.set('yearMax', params.yearMax)
  if (params.bodyClass) qs.set('bodyClass', params.bodyClass)
  if (params.page)      qs.set('page', params.page)
  if (params.pageSize)  qs.set('pageSize', params.pageSize)
  const query = qs.toString() ? `?${qs}` : ''
  return request(`/api/vehicles${query}`)
}

export async function getVehicle(id) {
  return request(`/api/vehicles/${id}`)
}

/* ── Admin (requires the admin key from api/.env → ADMIN_API_KEY) ── */

async function adminRequest(path, adminKey, options = {}) {
  const res = await fetch(`${BASE}${path}`, {
    ...options,
    headers: { ...options.headers, 'X-Admin-Key': adminKey },
  })
  if (!res.ok) {
    const body = await res.json().catch(() => ({}))
    const err = new Error(body.error || `HTTP ${res.status}`)
    err.status = res.status
    throw err
  }
  return res.json()
}

export async function getAdminVehicles(adminKey) {
  return adminRequest('/api/admin/vehicles', adminKey)
}

export async function toggleFeatured(id, adminKey) {
  return adminRequest(`/api/admin/vehicles/${id}/featured`, adminKey, { method: 'POST' })
}
