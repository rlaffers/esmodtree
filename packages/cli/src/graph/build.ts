import { cruise } from 'dependency-cruiser'
import type { ICruiseResult } from './types'

export type BuildGraphOptions = {
  tsConfigPath?: string
}

export async function buildGraph(
  filePaths: string[],
  options: BuildGraphOptions = {},
): Promise<ICruiseResult> {
  const result = await cruise(filePaths, {
    doNotFollow: { path: 'node_modules' },
    tsPreCompilationDeps: true,
    tsConfig: options.tsConfigPath ? { fileName: options.tsConfigPath } : undefined,
  })

  return result.output as ICruiseResult
}
