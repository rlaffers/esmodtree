import { login } from '../auth/auth.js'
import { log } from '../../utils/logger.js'

export interface ApiResponse<T> {
  data: T
  status: number
}

export function fetchData<T>(
  url: string,
  credentials: { user: string; pass: string },
): ApiResponse<T | null> {
  log(`Fetching ${url}`)
  const ok = login(credentials)
  if (!ok) {
    return { data: null, status: 401 }
  }
  return { data: null as T, status: 200 }
}
