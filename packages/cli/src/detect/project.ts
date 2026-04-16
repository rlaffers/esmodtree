const COMMON_SOURCE_DIRS = ['src', 'app', 'pages', 'lib', 'components']

export function detectSourceDirs(dirExists: (dir: string) => boolean): string[] {
  return COMMON_SOURCE_DIRS.filter(dir => dirExists(dir))
}
