type ApiErrorBody = { error?: string; errors?: string[] }

export async function responseError(response: Response): Promise<string> {
  const body: ApiErrorBody = await response.json().catch(() => ({}))
  return body.error || body.errors?.join(', ') || 'Request failed'
}

export async function api<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = localStorage.getItem('property_platform_token')
  const response = await fetch(`/api/v1${path}`, {
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
