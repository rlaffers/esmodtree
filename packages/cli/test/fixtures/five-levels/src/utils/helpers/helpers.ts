import { MAX_RETRIES } from './constants.js'
import { isAuthenticated } from '../../services/auth/auth.js'

export function retry<T>(fn: () => T): T | undefined {
  for (let i = 0; i < MAX_RETRIES; i++) {
    if (!isAuthenticated()) continue
    try {
      return fn()
    } catch {
      // retry
    }
  }
  return undefined
}
