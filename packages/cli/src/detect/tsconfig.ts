import { join, dirname } from 'node:path'
import type { ProjectType } from './project'

export type DetectTsConfigOptions = {
  fileExists: (path: string) => boolean
}

export type TsConfigContent = {
  include?: string[]
}

export function detectTsConfig(
  startPath: string,
  options: DetectTsConfigOptions,
): string | undefined {
  let dir = startPath

  while (true) {
    const candidate = join(dir, 'tsconfig.json')
    if (options.fileExists(candidate)) return candidate

    // Stop at project root (directory with package.json)
    const pkgJson = join(dir, 'package.json')
    if (options.fileExists(pkgJson)) return undefined

    const parent = dirname(dir)
    if (dir === parent) return undefined
    dir = parent
  }
}

export function getSourceDirsFromTsConfig(
  tsConfig: TsConfigContent,
  dirExists: (dir: string) => boolean,
  projectType?: ProjectType,
): string[] {
  if (!tsConfig.include) return []

  const dirs: string[] = []
  for (const pattern of tsConfig.include) {
    const firstSegment = pattern.split('/')[0]
    // Skip bare globs (**, *.ts) and file entries (next-env.d.ts)
    if (firstSegment.includes('*') || firstSegment.includes('.')) continue
    dirs.push(firstSegment)
  }

  // For Next.js projects, ensure pages/ and app/ are scanned
  if (projectType === 'nextjs') {
    for (const dir of ['pages', 'app']) {
      if (!dirs.includes(dir)) dirs.push(dir)
    }
  }

  const unique = [...new Set(dirs)]
  return unique.filter(dir => dirExists(dir))
}
