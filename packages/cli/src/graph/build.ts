import { cruise } from 'dependency-cruiser'
import type { ICruiseResult } from './types'

export type BuildGraphOptions = {
  tsConfigPath?: string
  cwd?: string
}

export async function buildGraph(
  filePaths: string[],
  options: BuildGraphOptions = {},
): Promise<ICruiseResult> {
  const originalCwd = process.cwd()
  if (options.cwd) process.chdir(options.cwd)

  try {
    const result = await cruise(filePaths, {
      doNotFollow: { path: 'node_modules' },
      exclude: { path: '\\.(md|json|css|scss|less|svg|png|jpg|jpeg|gif|ico|woff2?|ttf|eot)$' },
      includeOnly: { path: '\\.[cm]?[jt]sx?$' },
      tsPreCompilationDeps: true,
      tsConfig: options.tsConfigPath ? { fileName: options.tsConfigPath } : undefined,
    })

    return result.output as ICruiseResult
  } finally {
    if (options.cwd) process.chdir(originalCwd)
  }
}
