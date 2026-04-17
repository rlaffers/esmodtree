import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'
import { buildGraph } from '~/graph/build'
import { transformGraph } from '~/graph/transform'

const FIXTURE_DIR = resolve(import.meta.dirname, '../../../test/fixtures/five-levels')
const TSCONFIG_PATH = resolve(FIXTURE_DIR, 'tsconfig.json')

describe('tsconfig path alias resolution', () => {
  it('resolves path aliases when tsconfig is provided to buildGraph', async () => {
    const originalCwd = process.cwd()
    try {
      process.chdir(FIXTURE_DIR)

      const target = 'src/features/alias-consumer.ts'
      const cruiseResult = await buildGraph([target], { tsConfigPath: TSCONFIG_PATH })
      const graphData = transformGraph(cruiseResult)
      const deps = graphData.adjacencyMaps.forward.get(target)

      expect(deps).toBeDefined()
      // The aliases @utils/format and @components/ui/Button should resolve to real paths
      expect(deps).toContain('src/utils/format.ts')
      expect(deps).toContain('src/components/ui/Button.ts')
    } finally {
      process.chdir(originalCwd)
    }
  })
})
