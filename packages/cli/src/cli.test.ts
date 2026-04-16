import { describe, expect, it, vi } from 'vitest'
import { createProgram } from './cli'

// Mock heavy dependencies so the action can run without real filesystem/dep-cruiser
const mockBuildGraph = vi.fn().mockResolvedValue({ modules: [] })
vi.mock('~/graph/build', () => ({
  buildGraph: (...args: unknown[]) => mockBuildGraph(...args),
}))
vi.mock('~/graph/transform', () => ({
  transformGraph: vi.fn().mockReturnValue({
    adjacencyMaps: { forward: new Map(), reverse: new Map() },
    metadata: new Map(),
    dependencyMetadata: new Map(),
  }),
}))
vi.mock('~/output/tree', () => ({
  formatTree: vi.fn().mockReturnValue(''),
}))

// Mock readFileSync for tsconfig reading in --up mode
vi.mock('node:fs', async importOriginal => {
  const actual = await importOriginal<typeof import('node:fs')>()
  return {
    ...actual,
    existsSync: vi.fn().mockReturnValue(false),
    readFileSync: vi.fn().mockReturnValue(JSON.stringify({ include: ['src/**/*.ts'] })),
  }
})

describe('CLI --tsconfig flag', () => {
  it('accepts --tsconfig option', async () => {
    const program = createProgram()
    program.exitOverride()

    await program.parseAsync([
      'node',
      'esmodtree',
      '--down',
      'some/file.ts',
      '--tsconfig',
      'custom/tsconfig.json',
    ])

    expect(program.opts().tsconfig).toBe('custom/tsconfig.json')
  })

  it('passes --tsconfig to buildGraph for --down mode', async () => {
    mockBuildGraph.mockClear()
    const program = createProgram()
    program.exitOverride()

    await program.parseAsync([
      'node',
      'esmodtree',
      '--down',
      'some/file.ts',
      '--tsconfig',
      'my/tsconfig.json',
    ])

    expect(mockBuildGraph).toHaveBeenCalledWith(expect.any(Array), {
      tsConfigPath: expect.any(String),
      cwd: expect.any(String),
    })
  })

  it('derives source dirs from tsconfig include for --up mode', async () => {
    mockBuildGraph.mockClear()
    const program = createProgram()
    program.exitOverride()

    await program.parseAsync([
      'node',
      'esmodtree',
      '--up',
      'src/some/file.ts',
      '--tsconfig',
      'my/tsconfig.json',
    ])

    // buildGraph should receive source dirs derived from tsconfig include
    expect(mockBuildGraph).toHaveBeenCalledWith(['src'], {
      tsConfigPath: expect.any(String),
      cwd: expect.any(String),
    })
  })
})

describe('CLI --depth flag', () => {
  it('accepts --depth option and parses it as a number', async () => {
    const program = createProgram()
    program.exitOverride()

    await program.parseAsync(['node', 'esmodtree', '--down', 'some/file.ts', '--depth', '2'])

    expect(program.opts().depth).toBe(2)
  })
})

describe('CLI --exclude flag', () => {
  it('accepts --exclude option', async () => {
    const program = createProgram()
    program.exitOverride()

    await program.parseAsync([
      'node',
      'esmodtree',
      '--down',
      'some/file.ts',
      '--exclude',
      'node_modules',
    ])

    expect(program.opts().exclude).toBe('node_modules')
  })
})

describe('CLI --json flag', () => {
  it('accepts --json flag', async () => {
    const program = createProgram()
    program.exitOverride()

    await program.parseAsync(['node', 'esmodtree', '--down', 'some/file.ts', '--json'])

    expect(program.opts().json).toBe(true)
  })
})

describe('CLI --root flag', () => {
  it('accepts --root option', async () => {
    const program = createProgram()
    program.exitOverride()

    await program.parseAsync(['node', 'esmodtree', '--up', 'src/file.ts', '--root', 'src'])

    expect(program.opts().root).toBe('src')
  })
})
