type ApiErrorBody = { error?: string; errors?: string[] }

const API_BASE_URL = (import.meta.env.VITE_API_URL || '').replace(/\\/+$/, '')

export async function responseError(response: Response): Promise<string> {
  const body: ApiErrorBody = await response.json().catch(() => ({}))
  return body.error || body.errors?.join(', ') || 'Request failed'
}

export async function api<T>(path: string, options: RequestInit = {}): Promise<T> {
  if (import.meta.env.PROD && !API_BASE_URL) {
    throw new Error('The production API URL is not configured. Set VITE_API_URL in Vercel.')
  }

  const token = localStorage.getItem('property_platform_token')
  const response = await fetch(`${API_BASE_URL}/api/v1${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options.headers,
    },
  })

  if (!response.ok) throw new Error(await responseError(response))
  return response.status === 204 ? (undefined as T) : response.json()
}
