import { DEFAULT_TIMEOUT } from './helpers/constants.js'

export function formatDuration(ms: number): string {
  return ms > DEFAULT_TIMEOUT ? `${ms}ms (slow)` : `${ms}ms`
}

export function formatLabel(name: string): string {
  return name.trim().toUpperCase()
}
