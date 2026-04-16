import { join, dirname } from 'node:path'

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

export function getSourceDirsFromTsConfig(tsConfig: TsConfigContent): string[] {
  if (!tsConfig.include) return []
  return [...new Set(tsConfig.include.map(pattern => pattern.split('/')[0]))]
}
