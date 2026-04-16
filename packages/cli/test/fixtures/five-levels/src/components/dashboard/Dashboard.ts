import { formatLabel } from '../../utils/format.js'

export interface DashboardProps {
  title: string
}

export function renderDashboard(props: DashboardProps): string {
  return `<Dashboard>${formatLabel(props.title)}</Dashboard>`
}
