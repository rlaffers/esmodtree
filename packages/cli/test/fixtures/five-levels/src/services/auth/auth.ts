import { retry } from '../../utils/helpers/helpers.js'

let token: string | null = null

export function isAuthenticated(): boolean {
  return token !== null
}

export function login(credentials: { user: string; pass: string }): boolean {
  const result = retry(() => {
    if (credentials.user && credentials.pass) {
      token = 'fake-token'
      return true
    }
    return false
  })
  return result ?? false
}
