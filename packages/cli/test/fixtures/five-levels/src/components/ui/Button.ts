import { formatLabel } from '../../utils/format.js'

export interface ButtonProps {
  label: string
  disabled?: boolean
}

export function renderButton(props: ButtonProps): string {
  const label = formatLabel(props.label)
  return props.disabled ? `<Button disabled>${label}</Button>` : `<Button>${label}</Button>`
}
