import pc from 'picocolors'
import type { TreeNode } from '~/graph/types'

type ColorFn = (s: string) => string

export type FormatTreeOptions = {
  color?: boolean
}

const MARKER_COLORS: Record<string, ColorFn> = {
  page: pc.magenta,
  layout: pc.blue,
  entry: pc.green,
  barrel: pc.cyan,
  dynamic: pc.yellow,
  circular: pc.red,
}

function identity(s: string): string {
  return s
}

function colorizeFilename(filePath: string, color: boolean): string {
  if (!color) return filePath
  const lastSlash = filePath.lastIndexOf('/')
  if (lastSlash === -1) return pc.white(filePath)
  return filePath.slice(0, lastSlash + 1) + pc.white(filePath.slice(lastSlash + 1))
}

function getColorFn(tag: string, color: boolean): ColorFn {
  if (!color) return identity
  return MARKER_COLORS[tag] ?? identity
}

export function formatTree(node: TreeNode, options: FormatTreeOptions = {}): string {
  const { color = false } = options
  const lines: string[] = []

  function walk(n: TreeNode, prefix: string, isLast: boolean, isRoot: boolean) {
    const connector = isRoot ? '' : isLast ? '└── ' : '├── '
    const markerTags = n.markers.map(m => getColorFn(m, color)(`[${m}]`))
    if (n.circular) markerTags.push(getColorFn('circular', color)('[circular]'))
    const suffix = markerTags.length > 0 ? ` ${markerTags.join(' ')}` : ''
    lines.push(`${prefix}${connector}${colorizeFilename(n.path, color)}${suffix}`)

    const childPrefix = isRoot ? '' : prefix + (isLast ? '    ' : '│   ')
    n.children.forEach((child, i) => {
      walk(child, childPrefix, i === n.children.length - 1, false)
    })
  }

  walk(node, '', true, true)
  return lines.join('\n')
}
