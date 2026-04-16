const COMMON_SOURCE_DIRS = ['src', 'app', 'pages', 'lib', 'components']

const NEXT_CONFIG_FILES = ['next.config.js', 'next.config.mjs', 'next.config.ts', 'next.config.cjs']

export enum ProjectType {
  NextJs = 'nextjs',
  Generic = 'generic',
}

export function detectSourceDirs(dirExists: (dir: string) => boolean): string[] {
  return COMMON_SOURCE_DIRS.filter(dir => dirExists(dir))
}

export function detectProjectType(fileExists: (file: string) => boolean): ProjectType {
  if (NEXT_CONFIG_FILES.some(f => fileExists(f))) return ProjectType.NextJs
  return ProjectType.Generic
}
