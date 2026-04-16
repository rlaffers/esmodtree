import { renderDashboard, renderButton } from './components/index.js'
import { fetchData } from './services/api/client.js'

export async function startApp(): Promise<void> {
  const html = renderDashboard({ title: 'Main' })
  const button = renderButton({ label: 'Click me' })

  const response = fetchData<string>('/api/data', { user: 'admin', pass: 'secret' })

  console.log(html, button, response)

  // dynamic import
  const { lazyInit } = await import('./features/dynamic/lazy.js')
  console.log(lazyInit())
}
