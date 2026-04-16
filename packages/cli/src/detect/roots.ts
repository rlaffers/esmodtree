import { basename, dirname } from 'node:path'
import type { ModuleMarker } from '~/graph/types'
import { ProjectType } from './project'

const NEXT_INTERNAL_PAGES = new Set(['_app', '_document', '_error', '404', '500'])

const GENERIC_ENTRY_PATTERNS = [/\/index\.[tj]sx?$/, /\/main\.[tj]sx?$/]

function stripExtension(filePath: string): string {
  return filePath.replace(/\.[tj]sx?$/, '')
}

export function detectRootMarkers(
  projectType: ProjectType,
  modulePaths: string[],
): Map<string, ModuleMarker[]> {
  const markers = new Map<string, ModuleMarker[]>()

  for (const mod of modulePaths) {
    const detectedMarkers: ModuleMarker[] = []

    if (projectType === ProjectType.NextJs) {
      // Pages router: files in pages/ (excluding internal pages)
      if (mod.match(/^(.*\/)?pages\//)) {
        const name = stripExtension(basename(mod))
        if (!NEXT_INTERNAL_PAGES.has(name)) {
          detectedMarkers.push('page')
        }
      }

      // App router: page.tsx → [page], layout.tsx → [layout]
      if (mod.match(/^(.*\/)?app\//)) {
        const name = stripExtension(basename(mod))
        if (name === 'page') detectedMarkers.push('page')
        if (name === 'layout') detectedMarkers.push('layout')
      }
    }

    if (projectType === ProjectType.Generic) {
      // Generic TS: src/index.ts, src/main.ts
      if (GENERIC_ENTRY_PATTERNS.some(p => p.test(mod)) && mod.match(/^(.*\/)?src\//)) {
        const dir = dirname(mod)
        if (dir === 'src' || dir.endsWith('/src')) {
          detectedMarkers.push('entry')
        }
      }
    }

    if (detectedMarkers.length > 0) {
      markers.set(mod, detectedMarkers)
    }
  }

  return markers
}
