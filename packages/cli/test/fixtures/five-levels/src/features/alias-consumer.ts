import { formatDuration } from '@utils/format'
import { renderButton } from '@components/ui/Button'
import { warn } from '~/utils/logger'

export function aliasDemo(): string {
  return renderButton({ label: formatDuration(100) })
}
